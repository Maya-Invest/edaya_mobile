import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../app/edaya_root_scope.dart';
import '../l10n/l10n_extension.dart';

Future<void> showDemoDocument(String asset, String title) async {
  final navigator =
      EdayaRootScope.find<GoRouter>().routerDelegate.navigatorKey.currentState!;
  final path = 'packages/edaya_shared/assets/demo/$asset';
  await navigator.push<void>(
    MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            IconButton(
              icon: const Icon(Icons.save_alt),
              tooltip: MaterialLocalizations.of(context).saveButtonLabel,
              onPressed: () async {
                try {
                  final data = await rootBundle.load('$path.pdf');
                  await FilePicker.platform.saveFile(
                    fileName: '$asset.pdf',
                    type: FileType.custom,
                    allowedExtensions: ['pdf'],
                    bytes: data.buffer.asUint8List(
                      data.offsetInBytes,
                      data.lengthInBytes,
                    ),
                  );
                } on Object {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr.documentsFailed('PDF')),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: InteractiveViewer(
              maxScale: 4,
              child: Image.asset(
                '$path.png',
                semanticLabel: '${context.tr.demoLabel} · $title',
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
