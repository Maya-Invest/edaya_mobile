import 'package:flutter/material.dart';

enum DataStatus { loading, empty, error, ready }

class DataState extends StatelessWidget {
  const DataState({
    super.key,
    required this.status,
    this.errorMessage,
    this.emptyMessage = 'Nothing to show yet.',
    this.onRetry,
    required this.child,
  });

  final DataStatus status;
  final String? errorMessage;
  final String emptyMessage;
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
              emptyMessage,
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
                  errorMessage ?? 'Something went wrong.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 16),
                  OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
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
