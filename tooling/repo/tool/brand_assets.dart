import 'dart:io';
import 'package:edaya_repo/src/runtime.dart' show applicationPaths;
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as raster;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('render supplied brand outlines', () async {
    final root = p.normalize(p.join(Directory.current.path, '../..'));
    final logos = p.join(root, 'packages/edaya_shared/design-system/logos');
    Future<void> render(
      String file,
      String symbol,
      int width, {
      int? height,
      int background = 0,
      double ratio = 1,
    }) async {
      final info = await vg.loadPicture(
        SvgStringLoader(File(p.join(logos, symbol)).readAsStringSync()),
        null,
      );
      final h = height ?? (width * info.size.height / info.size.width).round();
      final recorder = ui.PictureRecorder();
      // A fresh recorder owns each bitmap and is disposed after encoding.
      final drawing = ui.Canvas(recorder);
      drawing.drawColor(ui.Color(background), ui.BlendMode.src);
      final scale = min(
        width * ratio / info.size.width,
        h * ratio / info.size.height,
      );
      drawing.translate(
        (width - info.size.width * scale) / 2,
        (h - info.size.height * scale) / 2,
      );
      drawing.scale(scale);
      drawing.drawPicture(info.picture);
      final picture = recorder.endRecording(),
          image = await recorderImage(picture, width, h);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final pixels = raster.Image.fromBytes(
        width: width,
        height: h,
        bytes: bytes!.buffer,
        numChannels: 4,
      );
      final encoded = raster.encodePng(
        background == 0 ? pixels : pixels.convert(numChannels: 3),
      );
      final outputRoot = Platform.environment['EDAYA_BRAND_OUTPUT_ROOT'];
      final output = File(
        outputRoot == null
            ? file
            : p.join(outputRoot, p.relative(file, from: root)),
      );
      output.parent.createSync(recursive: true);
      output.writeAsBytesSync(encoded);
      expect(raster.decodePng(encoded)!.width, width);
      expect(raster.decodePng(encoded)!.height, h);
      if (background != 0) expect(raster.decodePng(encoded)!.numChannels, 3);
      image.dispose();
      picture.dispose();
      info.picture.dispose();
    }

    for (final name in [
      'vertical-couleur',
      'horizontal-couleur',
      'symbole-couleur',
      'vertical-blanc',
      'horizontal-blanc',
      'symbole-blanc',
    ]) {
      await render(
        p.join(root, 'packages/edaya_shared/assets/brand/edaya-$name.png'),
        'edaya-$name.svg',
        name.startsWith('horizontal') ? 1024 : 512,
      );
    }
    for (final entry in applicationPaths.entries) {
      final app = entry.key, path = entry.value;
      final symbol =
              'edaya-symbole-${app == 'guardian' ? 'couleur' : 'blanc'}.svg',
          background = app == 'guardian' ? 0xffffffff : 0xff2563eb;
      await render(
        p.join(root, 'branding/icons/$app.png'),
        symbol,
        1024,
        height: 1024,
        background: background,
        ratio: .60,
      );
      await render(
        p.join(root, 'branding/icons/$app-foreground.png'),
        symbol,
        1024,
        height: 1024,
        ratio: .43,
      );
      for (final file in Directory(
        p.join(root, path),
      ).listSync(recursive: true, followLinks: false).whereType<File>()) {
        final path = file.path;
        if (path.contains('/build/') || path.contains('/.dart_tool/')) continue;
        final icon = RegExp(
          r'/(mipmap-[^/]+/ic_launcher|AppIcon.appiconset/Icon-App[^/]*|web/(?:icons/Icon[^/]*|favicon))\.png$',
        ).hasMatch(path);
        final foreground = RegExp(
          r'drawable-[^/]+/ic_launcher_foreground\.png$',
        ).hasMatch(path);
        if (icon || foreground) {
          final codec = await ui.instantiateImageCodec(file.readAsBytesSync());
          final frame = await codec.getNextFrame();
          final size = frame.image.width;
          frame.image.dispose();
          codec.dispose();
          await render(
            path,
            symbol,
            size,
            height: size,
            background: foreground ? 0 : background,
            ratio: foreground
                ? .43
                : path.contains('maskable')
                ? .56
                : .60,
          );
        }
      }
      for (final scale in [1, 2, 3]) {
        await render(
          p.join(
            root,
            '$path/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage${scale == 1 ? '' : '@${scale}x'}.png',
          ),
          symbol,
          144 * scale,
          height: 144 * scale,
          ratio: 2 / 3,
        );
      }
      await render(
        p.join(
          root,
          '$path/android/app/src/main/res/drawable-mdpi/edaya_launch.png',
        ),
        symbol,
        144,
        height: 144,
        ratio: .43,
      );
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}

Future<ui.Image> recorderImage(ui.Picture picture, int width, int height) =>
    picture.toImage(width, height);
