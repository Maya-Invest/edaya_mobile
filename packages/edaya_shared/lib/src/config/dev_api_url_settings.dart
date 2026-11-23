import 'package:flutter/material.dart';

import '../l10n/l10n_extension.dart';
import 'api_base_url_config.dart';
import 'developer_settings_config.dart';

/// UI for configuring the API base URL at runtime.
class DevApiUrlSettings extends StatefulWidget {
  const DevApiUrlSettings({
    super.key,
    this.onUrlChanged,
    this.compact = false,
    this.enabled = true,
    this.applyOverride = ApiBaseUrlConfig.saveOverride,
  });

  /// The login controller locks the picker while authentication is in flight.
  final bool enabled;
  final Future<bool> Function(String?) applyOverride;

  /// Called after the URL changes so the app can clear stale auth/session state.
  final Future<void> Function()? onUrlChanged;

  /// When `true`, renders as a compact expansion tile instead of a full card.
  final bool compact;

  @override
  State<DevApiUrlSettings> createState() => _DevApiUrlSettingsState();
}

class _DevApiUrlSettingsState extends State<DevApiUrlSettings> {
  late final TextEditingController _controller;
  String? _errorMessage;
  bool _isSaving = false;

  List<({String label, String value})> _presets(BuildContext context) => [
    (label: context.tr.presetLocalhost, value: ApiBaseUrlConfig.localUrl),
    (
      label: context.tr.presetAndroidEmulator,
      value: ApiBaseUrlConfig.androidEmulatorUrl,
    ),
    (label: context.tr.presetStaging, value: ApiBaseUrlConfig.stagingUrl),
    (label: context.tr.presetProduction, value: ApiBaseUrlConfig.productionUrl),
    (label: context.tr.presetLanEditIp, value: 'http://192.168.1.1:9999'),
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ApiBaseUrlConfig.baseUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _enabled => widget.enabled && !_isSaving;

  Future<void> _applyUrl(String? url) async {
    if (!_enabled) return;
    setState(() {
      _errorMessage = null;
      _isSaving = true;
    });

    try {
      final changed = await widget.applyOverride(url);
      if (!mounted) {
        return;
      }

      _controller.text = ApiBaseUrlConfig.baseUrl;
      if (changed) {
        await widget.onUrlChanged?.call();
        if (!mounted) {
          return;
        }
        _showUpdatedMessage();
      }
    } on FormatException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack),
      );
      if (mounted) {
        setState(() => _errorMessage = context.tr.couldNotSaveChanges);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showUpdatedMessage() {
    final url = ApiBaseUrlConfig.baseUrl;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.tr.currentApiUrl(url))));
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr.currentApiUrl(ApiBaseUrlConfig.baseUrl),
          style: theme.textTheme.bodySmall,
        ),
        if (ApiBaseUrlConfig.hasOverride) ...[
          const SizedBox(height: 4),
          Text(
            context.tr.usingSavedDevOverride,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextFormField(
          controller: _controller,
          keyboardType: TextInputType.url,
          autofillHints: const [AutofillHints.url],
          decoration: InputDecoration(
            labelText: context.tr.apiBaseUrlLabel,
            hintText: ApiBaseUrlConfig.stagingUrl,
          ),
          enabled: _enabled,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in _presets(context))
              ActionChip(
                label: Text(preset.label),
                onPressed: !_enabled
                    ? null
                    : () => _controller.text = preset.value,
              ),
          ],
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _enabled ? () => _applyUrl(null) : null,
                child: Text(context.tr.resetDefault),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _enabled ? () => _applyUrl(_controller.text) : null,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.tr.save),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (DeveloperSettingsConfig.production) {
      return const SizedBox.shrink();
    }

    if (widget.compact) {
      return ExpansionTile(
        leading: const Icon(Icons.settings_outlined),
        title: Text(context.tr.developerSettings),
        subtitle: Text(ApiBaseUrlConfig.baseUrl),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildBody(context),
          ),
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr.developerSettings,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildBody(context),
          ],
        ),
      ),
    );
  }
}
