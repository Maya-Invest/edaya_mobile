require 'minitest/autorun'
require 'ostruct'
require 'yaml'
require 'xcodeproj'
require 'spaceship'
require_relative '../release'

class AppleReleaseTest < Minitest::Test
  def config
    AppleRelease::APPS.fetch('guardian')
  end

  def profile
    {
      'UUID' => '12345678-1234-1234-1234-123456789012',
      'TeamIdentifier' => [config.fetch('teamId')],
      'ApplicationIdentifierPrefix' => [config.fetch('teamId')],
      'ExpirationDate' => Time.now + 3600,
      'Entitlements' => { 'application-identifier' => "#{config.fetch('teamId')}.#{config.fetch('bundleId')}", 'get-task-allow' => false }
    }
  end

  def build(id: 'build-1', version: '1.0.0', number: '1.42.1', state: 'VALID', expired: false)
    OpenStruct.new(id: id, app_version: version, version: number, processing_state: state, expired: expired)
  end

  def test_build_number_limits_and_retry_ordering
    assert_equal '1.42.1', AppleRelease.build_number('GITHUB_RUN_NUMBER' => '42', 'GITHUB_RUN_ATTEMPT' => '1')
    assert_equal '1.42.2', AppleRelease.build_number('GITHUB_RUN_NUMBER' => '42', 'GITHUB_RUN_ATTEMPT' => '2')
    assert_equal '2.0.1', AppleRelease.build_number('GITHUB_RUN_NUMBER' => '100', 'GITHUB_RUN_ATTEMPT' => '1')
    [ ['0', '1'], ['42', '100'], ['999900', '1'] ].each do |run, attempt|
      assert_raises(RuntimeError) { AppleRelease.build_number('GITHUB_RUN_NUMBER' => run, 'GITHUB_RUN_ATTEMPT' => attempt) }
    end
  end

  def test_profiles_reject_wrong_apps_teams_expired_development_and_adhoc
    assert_equal profile['UUID'], AppleRelease.validate_profile(profile, config)['UUID']
    invalid = [profile.merge('TeamIdentifier' => ['OTHERTEAM']),
      profile.merge('ExpirationDate' => Time.now - 1),
      profile.merge('ProvisionedDevices' => ['device']), profile.merge('ProvisionsAllDevices' => true),
      profile.merge('Entitlements' => profile['Entitlements'].merge('get-task-allow' => true)),
      profile.merge('Entitlements' => profile['Entitlements'].merge('application-identifier' => 'TEAM.wrong.app'))]
    invalid.each { |value| assert_raises(RuntimeError) { AppleRelease.validate_profile(value, config) } }
  end

  def test_submission_requires_exact_processed_unexpired_build
    selected = build
    assert_equal selected, AppleRelease.validate_build([selected], '1.0.0', '1.42.1')
    [[], [build(version: '2.0.0')], [build(number: '1.43.1')], [build(state: 'PROCESSING')],
      [build(expired: true)], [selected, selected]].each do |builds|
      assert_raises(RuntimeError) { AppleRelease.validate_build(builds, '1.0.0', '1.42.1') }
    end
  end

  def test_submission_retries_skip_same_build_but_reject_replacement_and_downgrade
    selected = build
    existing = OpenStruct.new(app_version_state: 'WAITING_FOR_REVIEW', get_build: selected)
    assert_equal :already_submitted, AppleRelease.submission_decision('1.0.0', selected, live: nil, existing: existing)
    assert_raises(RuntimeError) { AppleRelease.submission_decision('1.0.0', build(id: 'other'), live: nil, existing: existing) }
    assert_raises(RuntimeError) { AppleRelease.submission_decision('1.0.0', selected, live: OpenStruct.new(version_string: '2.0.0'), existing: nil) }
    assert_equal :submit, AppleRelease.submission_decision('1.0.0', selected, live: nil, existing: nil)
  end

  def test_app_config_matches_v2_xcode_and_firebase_identities
    AppleRelease::APPS.each do |app, value|
      assert_equal "apps/#{app}", value.fetch('path')
      root = File.join(AppleRelease::ROOT, value.fetch('path'))
      project = Xcodeproj::Project.open(File.join(root, 'ios/Runner.xcodeproj'))
      runner = project.targets.find { |target| target.name == 'Runner' }
      settings = runner.build_configurations.find { |c| c.name == 'Release' }.build_settings
      assert_equal value.fetch('bundleId'), settings.fetch('PRODUCT_BUNDLE_IDENTIFIER')
      assert_equal value.fetch('teamId'), settings.fetch('DEVELOPMENT_TEAM')
      firebase = AppleRelease.plist(File.binread(File.join(root, 'ios/Runner/GoogleService-Info.plist')))
      assert_equal value.fetch('bundleId'), firebase.fetch('BUNDLE_ID')
      entitlements = AppleRelease.plist(File.binread(File.join(root, 'ios', settings.fetch('CODE_SIGN_ENTITLEMENTS'))))
      assert_equal 'development', entitlements.fetch('aps-environment')
    end
  end

  def test_apple_submission_is_manual_and_separate_from_testflight
    workflow = YAML.load_file(File.join(AppleRelease::ROOT, '.github/workflows/submit-app-store.yml'))
    triggers = workflow['on'] || workflow[true] # YAML 1.1 treats "on" as boolean.
    assert_equal ['workflow_dispatch'], triggers.keys
    job = workflow.fetch('jobs').fetch('submit')
    assert_equal "github.ref == 'refs/heads/main'", job.fetch('if')
    assert_equal 'app-store-production', job.fetch('environment')
    deploy = YAML.load_file(File.join(AppleRelease::ROOT, '.github/workflows/_deploy.yml'))['jobs']['apple']
    assert_equal "inputs.target == 'production'", deploy.fetch('if')
    assert_equal deploy.fetch('concurrency'), job.fetch('concurrency')
  end

  def test_both_remote_builds_are_validated_before_submission_and_exact_builds_are_used
    previous = ENV.to_h
    AppleRelease::APPS.each_key do |app|
      ENV["APPLE_#{app.upcase}_VERSION"] = '1.0.0'
      ENV["APPLE_#{app.upcase}_BUILD"] = '1.42.1'
    end
    uploads = []
    context = Object.new
    context.define_singleton_method(:upload_to_app_store) { |**options| uploads << options }
    fake_app = Class.new do
      attr_reader :id
      def initialize(id); @id = id; end
      def get_live_app_store_version(**); nil; end
      def get_app_store_versions(**); []; end
    end
    find_app = ->(id) { fake_app.new(id) }
    missing_teacher = lambda do |**options|
      assert_equal '1.0.0', options[:version]
      assert_equal '1.42.1', options[:build_number]
      options[:app_id] == AppleRelease::APPS['teacher']['bundleId'] ? [] : [build]
    end
    AppleRelease.stub(:api_key, {}) do
      AppleRelease.stub(:record, nil) do
        Spaceship::ConnectAPI::App.stub(:find, find_app) do
          Spaceship::ConnectAPI::Build.stub(:all, missing_teacher) do
            assert_raises(RuntimeError) { AppleRelease.submit(context) }
            assert_empty uploads
          end
          Spaceship::ConnectAPI::Build.stub(:all, [build]) do
            AppleRelease.submit(context)
          end
        end
      end
    end
    assert_equal 2, uploads.length
    uploads.each do |options|
      assert_equal '1.0.0', options[:app_version]
      assert_equal '1.42.1', options[:build_number]
      assert_equal true, options[:skip_binary_upload]
      assert_equal true, options[:submit_for_review]
      assert_equal false, options[:automatic_release]
    end
  ensure
    ENV.replace(previous) if previous
  end

  def test_malformed_secret_errors_do_not_echo_key_material
    ENV['APPLE_TEST_SECRET'] = '{"key":"private-material'
    error = assert_raises(RuntimeError) { AppleRelease.secret_json('APPLE_TEST_SECRET') }
    refute_includes error.message, 'private-material'
  ensure
    ENV.delete('APPLE_TEST_SECRET')
  end
end
