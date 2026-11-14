import 'package:flutter/material.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

/// One reason and one submit action. The calling form supplies the proposed values.
Future<String?> correctionReasonDialog(
  BuildContext context, {
  String? summary,
}) async {
  final reason = TextEditingController();
  try {
    return await showLevitDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.tr.marksRequestCorrection),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (summary != null) Text(summary),
              TextField(
                controller: reason,
                autofocus: true,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: context.tr.marksCorrectionReason,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: reason.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, reason.text.trim()),
              child: Text(context.tr.marksRequestCorrection),
            ),
          ],
        ),
      ),
    );
  } finally {
    reason.dispose();
  }
}
