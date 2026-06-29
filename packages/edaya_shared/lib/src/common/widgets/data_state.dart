import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';

enum DataStatus { loading, empty, error, ready }

class DataState extends StatelessWidget {
  const DataState({
    super.key,
    required this.status,
    this.errorMessage,
    this.emptyMessage,
    this.onRetry,
    required this.child,
  });

  final DataStatus status;
  final String? errorMessage;
  final String? emptyMessage;
  final VoidCallback? onRetry;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case DataStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case DataStatus.empty:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              emptyMessage ?? context.tr.nothingToShowYet,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        );
      case DataStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  errorMessage ?? context.tr.somethingWentWrong,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: onRetry,
                    child: Text(context.tr.retry),
                  ),
                ],
              ],
            ),
          ),
        );
      case DataStatus.ready:
        return child;
    }
  }
}
