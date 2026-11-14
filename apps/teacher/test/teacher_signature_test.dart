import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_teacher_v2/features/signature/signature_editor_page.dart';
import 'package:edaya_teacher_v2/features/signature/signature_encode.dart';
import 'package:edaya_teacher_v2/features/signature/teacher_signature_controller.dart';
import 'package:edaya_teacher_v2/features/signature/teacher_signature_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:signature/signature.dart';

api.EffectiveGrantsResponse grants(String id, String school) =>
    api.EffectiveGrantsResponse(
      kind: 'teacher',
      actorId: id,
      schoolId: school,
      assuranceLevel: 'standard',
      grants: const [],
    );

class SignatureSession implements AppSessionController {
  @override
  final grants = LxVar<api.EffectiveGrantsResponse?>(grantsForTeacher());
  @override
  final user = LxVar<AuthUser?>(
    const AuthUser(id: 'account', email: 'teacher@example.test'),
  );
  static api.EffectiveGrantsResponse grantsForTeacher() =>
      api.EffectiveGrantsResponse(
        kind: 'teacher',
        actorId: 'teacher',
        schoolId: 'school',
        assuranceLevel: 'standard',
        grants: const [],
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SignatureTransport implements api.Transport {
  final commands = <Map<String, dynamic>>[];
  String? currentId = 'old';
  bool failComplete = false, failRemove = false;
  Completer<Map<String, dynamic>>? pendingIntent;
  Completer<Map<String, dynamic>>? pendingCompletion;
  @override
  Future<T> request<T>(
    String method,
    String path, {
    api.TransportRequestOptions? options,
  }) async {
    if (path.contains('/teachers/')) {
      return <String, dynamic>{
            'id': 'teacher',
            'signatureAttachmentId': currentId,
          }
          as T;
    }
    if (path.endsWith('download-url')) {
      return <String, dynamic>{
            'downloadUrl': 'https://storage.test/signature.png',
          }
          as T;
    }
    final body = Map<String, dynamic>.from(options!.body as Map);
    commands.add({'path': path, ...body});
    if (path.endsWith('create-teacher-signature-upload')) {
      return (pendingIntent == null
              ? <String, dynamic>{
                  'attachmentId': body['attachmentId'],
                  'uploadUrl': 'https://storage.test/upload',
                  'headers': <String, String>{},
                  'expiresAt': DateTime.now()
                      .add(const Duration(minutes: 15))
                      .toIso8601String(),
                }
              : await pendingIntent!.future)
          as T;
    }
    if (path.endsWith('complete-teacher-signature-upload')) {
      if (failComplete) throw api.ApiError(503, {});
      if (pendingCompletion != null) {
        return await pendingCompletion!.future as T;
      }
      currentId = body['attachmentId'] as String;
      return <String, dynamic>{'signatureAttachmentId': currentId} as T;
    }
    if (path.endsWith('clear-teacher-signature')) {
      if (failRemove) throw api.ApiError(503, {});
      currentId = null;
      return <String, dynamic>{} as T;
    }
    throw StateError('Unexpected request $path');
  }
}

class SignatureImagePicker extends ImagePickerPlatform {
  SignatureImagePicker(this.path);
  final String path;
  bool cancelled = false;
  final sources = <ImageSource>[];
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    sources.add(source);
    return cancelled ? null : XFile(path);
  }
}

Future<void> flush() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = img.Image(width: 240, height: 80, numChannels: 4);
  img.drawLine(
    fixture,
    x1: 10,
    y1: 10,
    x2: 220,
    y2: 60,
    color: img.ColorRgba8(30, 41, 59, 255),
    thickness: 3,
  );
  final ink = encodeSignatureImage(fixture);

  testWidgets(
    'signature package exports bounded transparent PNG preserving proportions',
    (tester) async {
      final controller = SignatureController(
        penStrokeWidth: 3,
        points: [
          Point(const Offset(20, 20), PointType.tap, 1),
          Point(const Offset(240, 60), PointType.move, 1),
          Point(const Offset(320, 30), PointType.move, 1),
        ],
      );
      addTearDown(controller.dispose);
      final exported = await tester.runAsync(controller.toPngBytes);
      final bytes = encodeSignatureImage(decodeSignatureImage(exported!));
      final decoded = img.decodePng(bytes)!;
      expect(decoded.width, greaterThan(decoded.height));
      expect(decoded.width, lessThanOrEqualTo(1024));
      expect(decoded.getPixel(0, 0).a, 0);
      expect(decoded.data!.toUint8List().any((value) => value > 0), isTrue);
      expect(bytes.length, lessThanOrEqualTo(teacherSignatureMaxBytes));
      controller.clear();
      expect(await tester.runAsync(controller.toPngBytes), isNull);
    },
  );

  test(
    'rectangular image crop retains alpha, proportions, and rejects invalid images',
    () {
      final source = img.Image(width: 1800, height: 600, numChannels: 4);
      img.drawLine(
        source,
        x1: 100,
        y1: 100,
        x2: 1700,
        y2: 400,
        color: img.ColorRgba8(0, 0, 0, 255),
      );
      final result = img.decodePng(
        encodeSignatureImage(
          source,
          crop: const Rect.fromLTWH(100, 100, 1200, 300),
        ),
      )!;
      expect(result.width, 1024);
      expect(result.height, 256);
      expect(result.getPixel(result.width - 1, result.height - 1).a, 0);
      expect(
        () => decodeSignatureImage(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
    },
  );

  test(
    'failed completion preserves the old signature and draft; retry reuses the upload without another PUT',
    () async {
      final session = SignatureSession(),
          transport = SignatureTransport()..failComplete = true;
      var puts = 0;
      final controller = TeacherSignatureController(
        session: session,
        schoolClient: () => api.createSchoolClient(transport),
        httpClient: MockClient((request) async {
          if (request.method == 'PUT') puts++;
          return http.Response.bytes(ink, 200);
        }),
      );
      controller.onInit();
      addTearDown(controller.onClose);
      await flush();
      controller.setDraft(ink);
      expect(await controller.save(), isFalse);
      expect(controller.currentAttachmentId.value, 'old');
      expect(controller.draft.value, ink);
      transport.failComplete = false;
      expect(await controller.save(), isTrue);
      expect(puts, 1);
      expect(
        transport.commands.where(
          (command) => (command['path'] as String).endsWith(
            'create-teacher-signature-upload',
          ),
        ),
        hasLength(1),
      );
      expect(controller.draft.value, isNull);
      expect(controller.currentAttachmentId.value, isNot('old'));
    },
  );

  test(
    'interrupted PUT is retried with the same attachment identity',
    () async {
      final session = SignatureSession(), transport = SignatureTransport();
      var puts = 0;
      final controller = TeacherSignatureController(
        session: session,
        schoolClient: () => api.createSchoolClient(transport),
        httpClient: MockClient((request) async {
          if (request.method == 'PUT') {
            return http.Response('', ++puts == 1 ? 503 : 200);
          }
          return http.Response.bytes(ink, 200);
        }),
      );
      controller.onInit();
      addTearDown(controller.onClose);
      await flush();
      controller.setDraft(ink);
      expect(await controller.save(), isFalse);
      expect(await controller.save(), isTrue);
      expect(puts, 2);
      expect(
        transport.commands.where(
          (command) => (command['path'] as String).endsWith(
            'create-teacher-signature-upload',
          ),
        ),
        hasLength(1),
      );
    },
  );

  test(
    'failed removal keeps the signature; retry uses the same request identity',
    () async {
      final session = SignatureSession(),
          transport = SignatureTransport()..failRemove = true;
      final controller = TeacherSignatureController(
        session: session,
        schoolClient: () => api.createSchoolClient(transport),
        httpClient: MockClient((_) async => http.Response.bytes(ink, 200)),
      );
      controller.onInit();
      addTearDown(controller.onClose);
      await flush();
      expect(await controller.remove(), isFalse);
      expect(controller.currentAttachmentId.value, 'old');
      transport.failRemove = false;
      expect(await controller.remove(), isTrue);
      expect(controller.currentAttachmentId.value, isNull);
      expect(
        transport.commands[0]['requestId'],
        transport.commands[1]['requestId'],
      );
    },
  );

  test(
    'profile change discards drafts and late upload intent responses',
    () async {
      final session = SignatureSession(),
          transport = SignatureTransport()..pendingIntent = Completer();
      final controller = TeacherSignatureController(
        session: session,
        schoolClient: () => api.createSchoolClient(transport),
        httpClient: MockClient((_) async => http.Response.bytes(ink, 200)),
      );
      controller.onInit();
      addTearDown(controller.onClose);
      await flush();
      controller.setDraft(ink);
      final save = controller.save();
      await flush();
      session.grants(grants('other', 'other-school'));
      await flush();
      transport.pendingIntent!.complete({
        'attachmentId': 'stale',
        'uploadUrl': 'https://storage.test/stale',
      });
      expect(await save, isFalse);
      expect(controller.draft.value, isNull);
      expect(controller.saving.value, isFalse);
      transport.pendingIntent = null;
      controller.setDraft(ink);
      expect(await controller.save(), isTrue);
      final completed = transport.commands
          .where(
            (command) => (command['path'] as String).endsWith(
              'complete-teacher-signature-upload',
            ),
          )
          .single;
      expect(completed['attachmentId'], isNot('stale'));
    },
  );

  test(
    'sign-out during completion discards late responses and signature bytes',
    () async {
      final session = SignatureSession(),
          transport = SignatureTransport()..pendingCompletion = Completer();
      final controller = TeacherSignatureController(
        session: session,
        schoolClient: () => api.createSchoolClient(transport),
        httpClient: MockClient((_) async => http.Response.bytes(ink, 200)),
      );
      controller.onInit();
      addTearDown(controller.onClose);
      await flush();
      controller.setDraft(ink);
      final save = controller.save();
      await flush();
      session.grants(null);
      session.user(null);
      await flush();
      transport.pendingCompletion!.complete({'signatureAttachmentId': 'stale'});
      expect(await save, isFalse);
      expect(controller.currentAttachmentId.value, isNull);
      expect(controller.currentImage.value, isNull);
      expect(controller.draft.value, isNull);
    },
  );

  for (final source in ['Choose image', 'Take photo']) {
    testWidgets(
      '$source imports a signature and cancellation preserves the draft',
      (tester) async {
        final session = SignatureSession();
        final transport = SignatureTransport()..currentId = null;
        final directory = Directory.systemTemp.createTempSync(
          'signature-picker-',
        );
        final file = File('${directory.path}/signature.png')
          ..writeAsBytesSync(ink);
        addTearDown(() => directory.deleteSync(recursive: true));
        final previousPicker = ImagePickerPlatform.instance;
        final picker = SignatureImagePicker(file.path);
        ImagePickerPlatform.instance = picker;
        addTearDown(() => ImagePickerPlatform.instance = previousPicker);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TeacherSignaturePage(
              session: session,
              schoolClient: () => api.createSchoolClient(transport),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(find.text(source));
        });
        for (
          var attempt = 0;
          attempt < 50 && find.byType(SignatureEditorPage).evaluate().isEmpty;
          attempt++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pumpAndSettle();
        }
        expect(picker.sources, hasLength(1));
        expect(find.byType(SignatureEditorPage), findsOneWidget);
        await tester.tap(find.text('Use signature'));
        await tester.pumpAndSettle();
        await tester.runAsync(flush);
        await tester.pumpAndSettle();
        final controller = tester
            .element(find.byType(ListView))
            .levit
            .find<TeacherSignatureController>();
        final draft = controller.draft.value;
        expect(draft, isNotNull);
        expect(controller.currentAttachmentId.value, isNull);
        picker.cancelled = true;
        await tester.tap(find.text(source));
        await tester.pumpAndSettle();
        expect(find.byType(SignatureEditorPage), findsNothing);
        expect(controller.draft.value, same(draft));
        expect(picker.sources, [
          source == 'Take photo' ? ImageSource.camera : ImageSource.gallery,
          source == 'Take photo' ? ImageSource.camera : ImageSource.gallery,
        ]);
        expect(transport.commands, isEmpty);
      },
    );
  }

  testWidgets('draw editor supports undo and clear', (tester) async {
    final session = SignatureSession();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SignatureEditorPage(
          session: session,
          identity: signatureSessionKey(session),
        ),
      ),
    );
    final surface = find.byKey(const ValueKey('signature-editor-surface'));
    await tester.drag(surface, const Offset(100, 30));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Use signature'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Use signature'),
          )
          .onPressed,
      isNull,
    );
    await tester.drag(surface, const Offset(80, 30));
    await tester.pump();
    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Use signature'),
          )
          .onPressed,
      isNull,
    );
  });
  testWidgets(
    'import editor rotates, crops, previews, and cancels on a school switch',
    (tester) async {
      final session = SignatureSession();
      Uint8List? result;
      final source = img.Image(width: 400, height: 120, numChannels: 4);
      img.drawLine(
        source,
        x1: 20,
        y1: 20,
        x2: 380,
        y2: 100,
        color: img.ColorRgba8(20, 20, 20, 255),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<Uint8List>(
                    MaterialPageRoute(
                      builder: (_) => SignatureEditorPage(
                        session: session,
                        identity: signatureSessionKey(session),
                        source: source,
                      ),
                    ),
                  );
                },
                child: const Text('Import'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.rotate_right));
      await tester.pump();
      final surface = find.byKey(const ValueKey('signature-editor-surface'));
      await tester.drag(surface, const Offset(20, 60));
      await tester.pump();
      await tester.tap(find.text('Use signature'));
      await tester.pumpAndSettle();
      final cropped = img.decodePng(result!)!;
      expect(cropped.height, greaterThan(cropped.width));
      expect(cropped.height, lessThan(400));
      result = null;
      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();
      session.grants(grants('teacher-b', 'school-b'));
      await tester.pumpAndSettle();
      expect(find.byType(SignatureEditorPage), findsNothing);
      expect(result, isNull);
    },
  );
}
