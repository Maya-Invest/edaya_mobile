import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'api_base_url_config.dart';
import 'restart_stub.dart' if (dart.library.io) 'restart_io.dart';

/// Debug-only UI for configuring the API base URL at runtime.
class DevApiUrlSettings extends StatefulWidget {
  const DevApiUrlSettings({
    super.key,
    this.onUrlChanged,
    this.compact = false,
  });

  /// Called after the URL changes so the app can clear auth state.
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

  static const _presets = <String, String>{
    'Localhost': 'http://localhost:9999',
    'Android emulator': 'http://10.0.2.2:9999',
    'LAN (edit IP)': 'http://192.168.1.1:9999',
  };

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

  Future<void> _applyUrl(Future<bool> Function() action) async {
    setState(() {
      _errorMessage = null;
      _isSaving = true;
    });

    try {
      final changed = await action();
      if (!mounted) {
        return;
      }

      if (changed) {
        await widget.onUrlChanged?.call();
        if (!mounted) {
          return;
        }
        await _showRestartDialog();
      }
    } on FormatException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _showRestartDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart required'),
        content: Text(
          kIsWeb
              ? 'API URL updated to ${ApiBaseUrlConfig.baseUrl}. Reload the page to connect to the new server.'
              : 'API URL updated to ${ApiBaseUrlConfig.baseUrl}. Restart the app to connect to the new server.',
        ),
        actions: [
          if (!kIsWeb)
            FilledButton(
              onPressed: restartApp,
              child: const Text('Restart app'),
            )
          else
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Current: ${ApiBaseUrlConfig.baseUrl}',
          style: theme.textTheme.bodySmall,
        ),
        if (ApiBaseUrlConfig.hasOverride) ...[
          const SizedBox(height: 4),
          Text(
            'Using saved dev override',
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
          decoration: const InputDecoration(
            labelText: 'API base URL',
            border: OutlineInputBorder(),
            hintText: 'http://localhost:9999',
          ),
          enabled: !_isSaving,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in _presets.entries)
              ActionChip(
                label: Text(entry.key),
                onPressed: _isSaving
                    ? null
                    : () => _controller.text = entry.value,
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
                onPressed: _isSaving
                    ? null
                    : () => _applyUrl(ApiBaseUrlConfig.clearOverride),
                child: const Text('Reset default'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _isSaving
                    ? null
                    : () => _applyUrl(
                        () => ApiBaseUrlConfig.saveOverride(_controller.text),
                      ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    if (widget.compact) {
      return ExpansionTile(
        leading: const Icon(Icons.settings_outlined),
        title: const Text('Developer settings'),
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
              'Developer settings',
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
