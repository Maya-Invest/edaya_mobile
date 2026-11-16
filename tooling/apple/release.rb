require 'base64'
require 'digest'
require 'fileutils'
require 'json'
require 'open3'
require 'openssl'
require 'securerandom'
require 'tmpdir'

module AppleRelease
  ROOT = File.expand_path('../..', __dir__)
  APPS = JSON.parse(File.read(File.join(__dir__, 'apps.json'))).freeze

  def self.selected_apps
    app = ENV['MOBILE_APP']
    app ? {app => APPS.fetch(app)} : APPS
  end

  def self.release_path(app, name)
    File.join(ROOT, '.release', app, name)
  end

  def self.build_number(env)
    if env.key?('EDAYA_STORE_BUILD')
      build = Integer(env.fetch('EDAYA_STORE_BUILD'), 10)
      raise 'Invalid Apple build number allocation' unless (1..99_989_999).cover?(build)
      return "#{1 + build / 10_000}.#{build / 100 % 100}.#{build % 100}"
    end
    run = Integer(env.fetch('EDAYA_RELEASE_SEQUENCE') { env.fetch('GITHUB_RUN_NUMBER') }, 10)
    attempt = Integer(env.fetch('GITHUB_RUN_ATTEMPT'), 10)
    raise 'Invalid Apple build number allocation' unless (1..999_899).cover?(run) && (1..99).cover?(attempt)
    "#{1 + run / 100}.#{run % 100}.#{attempt}"
  end

  def self.release_inputs
    evidence = prepared_inputs
    report = JSON.parse(File.read(File.join(ROOT, '.ci-evidence/qualification.json')))
    raise 'Qualified Apple artifacts required' unless evidence.all? { |k, v| report[k] == v } &&
      report.dig('checks', 'verification') == true && report.dig('checks', 'integration') == true &&
      selected_apps.keys.all? { |app| report.dig('artifacts', "ios_#{app}", ".release/#{app}/apple-build.json") == Digest::SHA256.file(release_path(app, 'apple-build.json')).hexdigest }
    evidence
  end

  def self.prepared_inputs
    evidence = JSON.parse(File.read(File.join(ROOT, '.ci-evidence/prepared.json')))
    target = ENV.fetch('TARGET')
    raise 'Expected qualified inputs for this branch and commit' unless %w[staging production].include?(target) &&
      ENV.fetch('GITHUB_REF') == (target == 'production' ? 'refs/heads/main' : 'refs/heads/staging') &&
      evidence.fetch('environment') == target && evidence.fetch('sourceCommit') == ENV.fetch('GITHUB_SHA') &&
      evidence['release'] == true && evidence['runId'] == ENV.fetch('GITHUB_RUN_ID') &&
      evidence['attempt'] == ENV.fetch('GITHUB_RUN_ATTEMPT')
    evidence
  end

  def self.validate_record(row, config, evidence, status)
    number = evidence.key?('storeBuild') ? build_number('EDAYA_STORE_BUILD' => evidence.fetch('storeBuild').to_s) : build_number(ENV)
    raise 'Apple build does not match this qualified release' unless row.fetch('status') == status &&
      row.fetch('environment') == evidence.fetch('environment') && row.fetch('apiUrl') == evidence.fetch('apiUrl') &&
      row.fetch('sourceCommit') == evidence.fetch('sourceCommit') && row.fetch('build') == number &&
      row.fetch('bundleId') == config.fetch('bundleId')
  end

  def self.validate_profile(profile, config, now: Time.now)
    entitlements = profile.fetch('Entitlements')
    prefix = profile.fetch('ApplicationIdentifierPrefix').first
    valid = profile.fetch('TeamIdentifier').include?(config.fetch('teamId')) &&
      entitlements['application-identifier'] == "#{prefix}.#{config.fetch('bundleId')}" &&
      entitlements['get-task-allow'] == false &&
      !profile.key?('ProvisionedDevices') && !profile['ProvisionsAllDevices'] &&
      profile.fetch('ExpirationDate') > now &&
      profile.fetch('UUID').match?(/\A[0-9A-Fa-f-]{36}\z/)
    raise 'Expected an unexpired App Store distribution profile for the configured app and team' unless valid
    profile
  end

  def self.validate_build(builds, version, number)
    matches = builds.select { |b| b.app_version == version && b.version == number }
    raise "Expected one processed TestFlight build #{version} (#{number})" unless matches.length == 1
    build = matches.first
    raise 'Selected TestFlight build is expired or not valid' unless build.processing_state == 'VALID' && build.expired == false
    build
  end

  def self.submission_decision(version, build, live:, existing:)
    submitted = %w[WAITING_FOR_REVIEW IN_REVIEW PENDING_DEVELOPER_RELEASE PENDING_APPLE_RELEASE PROCESSING_FOR_DISTRIBUTION READY_FOR_DISTRIBUTION]
    if existing && submitted.include?(existing.app_version_state)
      raise 'A different build of this version is already submitted' unless existing.get_build&.id == build.id
      return :already_submitted
    end
    if live && Gem::Version.new(version) <= Gem::Version.new(live.version_string)
      raise 'Selected version must be newer than the public App Store version'
    end
    :submit
  end

  def self.run!(*args, cwd: ROOT)
    output, _error, status = Open3.capture3(*args, chdir: cwd)
    raise "#{File.basename(args.first)} failed; inspect the build logs or signing configuration" unless status.success?
    output
  end

  def self.verify_signer(application, certificate_prefix, expected_der)
    # codesign treats a detached optional prefix as another object to inspect.
    run!('codesign', '-d', "--extract-certificates=#{certificate_prefix}", application)
    raise 'Exported IPA signing certificate mismatch' unless File.binread("#{certificate_prefix}0") == expected_der
  end

  def self.plist(data)
    require 'cfpropertylist'
    CFPropertyList.native_types(CFPropertyList::List.new(data: data).value)
  end

  def self.write_plist(path, value)
    require 'cfpropertylist'
    list = CFPropertyList::List.new
    list.value = CFPropertyList.guess(value)
    list.save(path, CFPropertyList::List::FORMAT_XML)
  end

  def self.record(mode, app, data)
    path = release_path(app, "apple-#{mode}.json")
    FileUtils.mkdir_p(File.dirname(path))
    current = File.exist?(path) ? JSON.parse(File.read(path)) : { 'apps' => {} }
    current['apps'][app] = data
    File.write(path, JSON.pretty_generate(current) + "\n")
    if ENV['GITHUB_STEP_SUMMARY']
      File.open(ENV['GITHUB_STEP_SUMMARY'], 'a') do |file|
        file.puts "- #{app}: #{data['version']} (#{data['build']}) — #{data['status']}"
      end
    end
  end

  def self.api_key(context)
    data = secret_json('APP_STORE_CONNECT_API_KEY_JSON')
    context.app_store_connect_api_key(
      key_id: data.fetch('key_id'), issuer_id: data.fetch('issuer_id'),
      key_content: data.fetch('key'), duration: 1200, in_house: false
    )
  end

  def self.secret_json(name)
    JSON.parse(ENV.fetch(name))
  rescue JSON::ParserError
    raise "Invalid #{name} JSON; contents omitted"
  end

  def self.build(context)
    raise 'Signed Apple builds run only on GitHub-hosted macOS runners' unless ENV['GITHUB_ACTIONS'] == 'true' && RUBY_PLATFORM.include?('darwin')
    require 'xcodeproj'
    evidence = prepared_inputs
    target = evidence.fetch('environment')
    number = build_number(ENV)
    bundle = secret_json('IOS_SIGNING_BUNDLE')
    certificate = OpenSSL::PKCS12.new(Base64.strict_decode64(bundle.fetch('certificate')), bundle.fetch('password'))
    raise 'An unexpired distribution certificate and private key are required' unless certificate.key &&
      certificate.certificate.not_after > Time.now && certificate.certificate.subject.to_s.include?('Distribution')

    private_dir = Dir.mktmpdir('edaya-apple-', ENV.fetch('RUNNER_TEMP'))
    keychain = File.join(private_dir, 'signing.keychain-db')
    keychain_password = SecureRandom.hex(32)
    original_keychains = run!('security', 'list-keychains', '-d', 'user').scan(/"([^"]+)"/).flatten
    installed_profiles = []
    projects = {}
    keychain_created = false
    begin
      cert_path = File.join(private_dir, 'distribution.p12')
      File.write(cert_path, Base64.strict_decode64(bundle.fetch('certificate')), mode: 'wb', perm: 0600)
      run!('security', 'create-keychain', '-p', keychain_password, keychain)
      keychain_created = true
      run!('security', 'set-keychain-settings', '-lut', '21600', keychain)
      run!('security', 'unlock-keychain', '-p', keychain_password, keychain)
      run!('security', 'import', cert_path, '-k', keychain, '-P', bundle.fetch('password'), '-T', '/usr/bin/codesign', '-T', '/usr/bin/security')
      run!('security', 'set-key-partition-list', '-S', 'apple-tool:,apple:', '-k', keychain_password, keychain)
      run!('security', 'list-keychains', '-d', 'user', '-s', keychain, *original_keychains)

      profiles = selected_apps.to_h do |app, config|
        raw = Base64.strict_decode64(bundle.fetch('profiles').fetch(app))
        input = File.join(private_dir, "#{app}.mobileprovision")
        File.write(input, raw, mode: 'wb', perm: 0600)
        profile = validate_profile(plist(run!('security', 'cms', '-D', '-i', input)), config)
        raise 'Profile does not contain the supplied signing certificate' unless profile.fetch('DeveloperCertificates').include?(certificate.certificate.to_der)
        destination = File.expand_path("~/Library/Developer/Xcode/UserData/Provisioning Profiles/#{profile.fetch('UUID')}.mobileprovision")
        raise 'Refusing to overwrite an existing provisioning profile' if File.exist?(destination)
        FileUtils.mkdir_p(File.dirname(destination))
        FileUtils.cp(input, destination)
        installed_profiles << destination
        [app, profile]
      end

      selected_apps.each do |app, config|
        app_root = File.join(ROOT, config.fetch('path'))
        project_path = File.join(app_root, 'ios/Runner.xcodeproj/project.pbxproj')
        projects[project_path] = File.binread(project_path)
        project = Xcodeproj::Project.open(File.dirname(project_path))
        runner = project.targets.find { |target| target.name == 'Runner' }
        raise 'Runner target is missing' unless runner
        runner.build_configurations.each do |configuration|
          next unless configuration.name == 'Release'
          settings = configuration.build_settings
          raise 'Unexpected iOS bundle ID' unless settings['PRODUCT_BUNDLE_IDENTIFIER'] == config.fetch('bundleId')
          settings['DEVELOPMENT_TEAM'] = config.fetch('teamId')
          settings['CODE_SIGN_STYLE'] = 'Manual'
          settings['CODE_SIGN_IDENTITY'] = 'Apple Distribution'
          settings['PROVISIONING_PROFILE_SPECIFIER'] = profiles.fetch(app).fetch('UUID')
        end
        project.save
        options = File.join(private_dir, "#{app}-export.plist")
        write_plist(options, {
          'method' => 'app-store-connect', 'teamID' => config.fetch('teamId'),
          'signingStyle' => 'manual', 'signingCertificate' => 'Apple Distribution',
          'manageAppVersionAndBuildNumber' => false,
          'provisioningProfiles' => { config.fetch('bundleId') => profiles.fetch(app).fetch('UUID') }
        })
        FileUtils.rm_rf(File.join(app_root, 'build/ios/ipa'))
        success = system('flutter', 'build', 'ipa', '--release', '--no-pub', "--build-number=#{number}",
          "--dart-define=API_URL=#{evidence.fetch('apiUrl')}", '--dart-define=TEST_OTP_ACCESS=false',
          "--export-options-plist=#{options}", chdir: app_root)
        raise "#{app} IPA build failed" unless success
        ipas = Dir.glob(File.join(app_root, 'build/ios/ipa/*.ipa'))
        raise "Expected one signed #{app} IPA" unless ipas.length == 1
        unpacked = File.join(private_dir, "#{app}-ipa")
        run!('unzip', '-q', ipas.first, '-d', unpacked)
        applications = Dir.glob(File.join(unpacked, 'Payload/*.app'))
        raise 'Expected one application in IPA' unless applications.length == 1
        application = applications.first
        run!('codesign', '--verify', '--deep', '--strict', application)
        certificate_prefix = File.join(private_dir, "#{app}-signer-")
        verify_signer(application, certificate_prefix, certificate.certificate.to_der)
        info = plist(File.binread(File.join(application, 'Info.plist')))
        raise 'Exported IPA identity/build mismatch' unless info['CFBundleIdentifier'] == config.fetch('bundleId') && info['CFBundleVersion'] == number
        validate_profile(plist(run!('security', 'cms', '-D', '-i', File.join(application, 'embedded.mobileprovision'))), config)
        entitlements = plist(run!('codesign', '-d', '--entitlements', ':-', application))
        raise 'Development-signed IPA is forbidden' if entitlements['get-task-allow'] == true
        raise 'IPA is signed by the wrong team' unless entitlements['com.apple.developer.team-identifier'] == config.fetch('teamId')
        raise 'IPA application entitlement mismatch' unless entitlements['application-identifier'] == profiles.fetch(app).fetch('Entitlements').fetch('application-identifier')
        raise 'Distribution push entitlement missing' unless entitlements['aps-environment'] == 'production'
        output = release_path(app, "ios/edaya-#{app}-#{target}.ipa")
        FileUtils.mkdir_p(File.dirname(output))
        FileUtils.cp(ipas.first, output)
        record('build', app, {
          'environment' => target, 'apiUrl' => evidence.fetch('apiUrl'),
          'bundleId' => config.fetch('bundleId'), 'teamId' => config.fetch('teamId'),
          'version' => info.fetch('CFBundleShortVersionString'), 'build' => number,
          'sha256' => Digest::SHA256.file(output).hexdigest, 'sourceCommit' => evidence.fetch('sourceCommit'),
          'certificateSha256' => Digest::SHA256.hexdigest(certificate.certificate.to_der),
          'status' => 'signed', 'xcode' => run!('xcodebuild', '-version').strip
        })
      end
    ensure
      projects.each { |path, content| File.binwrite(path, content) }
      installed_profiles.each { |path| FileUtils.rm_f(path) }
      begin
        if keychain_created
          begin
            run!('security', 'list-keychains', '-d', 'user', '-s', *original_keychains)
          ensure
            run!('security', 'delete-keychain', keychain)
          end
        end
      ensure
        FileUtils.rm_rf(private_dir)
      end
    end
  end

  def self.signed_ipas(evidence)
    target = evidence.fetch('environment')
    selected_apps.map do |app, config|
      manifest = JSON.parse(File.read(release_path(app, 'apple-build.json')))
      row = manifest.fetch('apps').fetch(app)
      file = release_path(app, "ios/edaya-#{app}-#{target}.ipa")
      validate_record(row, config, evidence, 'signed')
      raise 'IPA changed after signing verification' unless row.fetch('sha256') == Digest::SHA256.file(file).hexdigest
      [app, config, row, file]
    end
  end

  def self.testflight(context)
    signed_ipas(release_inputs).each do |app, config, row, file|
      # Refresh the short-lived API JWT for each upload.
      context.upload_to_testflight(api_key: api_key(context), app_identifier: config.fetch('bundleId'),
        ipa: file, skip_waiting_for_build_processing: false, distribute_external: false, skip_submission: true)
      record('testflight', app, row.merge('status' => 'processed'))
    end
  end

  def self.upload_records
    selected_apps.keys.to_h do |app|
      signed = JSON.parse(File.read(release_path(app, 'apple-build.json'))).fetch('apps').fetch(app)
      processed = JSON.parse(File.read(release_path(app, 'apple-testflight.json'))).fetch('apps').fetch(app)
      raise 'Upload receipt differs from the qualified signed build' unless signed.fetch('status') == 'signed' &&
        processed == signed.merge('status' => 'processed')
      [app, processed]
    end
  end

  def self.submit(context, check_only: false)
    evidence = release_inputs
    raise 'Production qualification required for App Review' unless evidence.fetch('environment') == 'production'
    uploads = upload_records
    api_key(context)
    candidates = selected_apps.map do |app, config|
      row = uploads.fetch(app)
      validate_record(row, config, evidence, 'processed')
      version = row.fetch('version')
      number = row.fetch('build')
      asc_app = Spaceship::ConnectAPI::App.find(config.fetch('bundleId'))
      raise "App Store Connect app missing: #{app}" unless asc_app
      builds = Spaceship::ConnectAPI::Build.all(app_id: asc_app.id, version: version, build_number: number,
        platform: 'IOS', includes: 'preReleaseVersion', limit: 200)
      build = validate_build(builds, version, number)
      live = asc_app.get_live_app_store_version(platform: 'IOS')
      existing = asc_app.get_app_store_versions(filter: { versionString: version, platform: 'IOS' }).first
      decision = submission_decision(version, build, live: live, existing: existing)
      [app, config, version, number, decision, asc_app, existing]
    end
    return if check_only
    candidates.each do |app, config, version, number, decision, asc_app, existing|
      if decision == :already_submitted
        record('submission', app, { 'bundleId' => config.fetch('bundleId'), 'version' => version,
          'build' => number, 'status' => 'already-submitted' })
        next
      end
      # Deliver skips release-type updates when metadata uploads are disabled.
      if existing
        existing.update(attributes: { releaseType: 'MANUAL' }) unless existing.release_type == 'MANUAL'
      else
        Spaceship::ConnectAPI.post_app_store_version(app_id: asc_app.id,
          attributes: { platform: 'IOS', versionString: version, releaseType: 'MANUAL' })
      end
      context.upload_to_app_store(api_key: api_key(context), app_identifier: config.fetch('bundleId'),
        app_version: version, build_number: number, skip_binary_upload: true,
        skip_metadata: true, skip_screenshots: true, skip_app_version_update: true, submit_for_review: true,
        automatic_release: false,
        run_precheck_before_submit: false, force: true)
      record('submission', app, { 'bundleId' => config.fetch('bundleId'), 'version' => version,
        'build' => number, 'status' => 'submitted-for-app-review' })
    end
  end
end
