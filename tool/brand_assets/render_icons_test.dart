// Renders the Voluntree app icons from the same painter the app draws, so
// the launcher icon, PWA icon, favicon and in-app badge never drift apart.
//
//   flutter test tool/brand_assets/render_icons_test.dart
//   python tool/brand_assets/strip_ios_alpha.py   (iOS icons must be RGB)
//   (set BRAND_PREVIEW=1 to write previews to build/brand_preview only)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volunteer_mobile_app/widgets/voluntree_logo.dart';

Future<void> _write(
  String path,
  int size, {
  double inset = 0.07,
  bool rounded = true,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  VoluntreeBadgePainter(
    inset: inset,
    rounded: rounded,
  ).paint(canvas, Size.square(size.toDouble()));
  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path)..createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
}

Future<void> _writeMark(String path, int size) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const VoluntreeMarkPainter(
    palette: MarkPalette.onLight,
  ).paint(canvas, Size.square(size.toDouble()));
  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('render brand icons', (tester) async {
    await tester.runAsync(() async {
      if (Platform.environment['BRAND_PREVIEW'] == '1') {
        await _write('build/brand_preview/badge_512.png', 512);
        await _write('build/brand_preview/badge_96.png', 96);
        await _write('build/brand_preview/badge_48.png', 48);
        await _write(
          'build/brand_preview/maskable_512.png',
          512,
          inset: 0.19,
          rounded: false,
        );
        await _writeMark('build/brand_preview/mark_light_512.png', 512);
        return;
      }

      // Web / PWA.
      await _write('web/favicon.png', 32);
      await _write('web/icons/Icon-192.png', 192);
      await _write('web/icons/Icon-512.png', 512);
      // Maskable icons are cropped to a circle or squircle by the OS, so
      // they are full-bleed with the mark inside the 80% safe zone.
      await _write(
        'web/icons/Icon-maskable-192.png',
        192,
        inset: 0.19,
        rounded: false,
      );
      await _write(
        'web/icons/Icon-maskable-512.png',
        512,
        inset: 0.19,
        rounded: false,
      );

      // Android launcher (legacy mipmaps).
      const android = {
        'mdpi': 48,
        'hdpi': 72,
        'xhdpi': 96,
        'xxhdpi': 144,
        'xxxhdpi': 192,
      };
      for (final e in android.entries) {
        await _write(
          'android/app/src/main/res/mipmap-${e.key}/ic_launcher.png',
          e.value,
        );
      }

      // iOS: the system applies its own mask, so these are full-bleed and
      // must not contain transparency.
      const ios = {
        'Icon-App-20x20@1x.png': 20,
        'Icon-App-20x20@2x.png': 40,
        'Icon-App-20x20@3x.png': 60,
        'Icon-App-29x29@1x.png': 29,
        'Icon-App-29x29@2x.png': 58,
        'Icon-App-29x29@3x.png': 87,
        'Icon-App-40x40@1x.png': 40,
        'Icon-App-40x40@2x.png': 80,
        'Icon-App-40x40@3x.png': 120,
        'Icon-App-60x60@2x.png': 120,
        'Icon-App-60x60@3x.png': 180,
        'Icon-App-76x76@1x.png': 76,
        'Icon-App-76x76@2x.png': 152,
        'Icon-App-83.5x83.5@2x.png': 167,
        'Icon-App-1024x1024@1x.png': 1024,
      };
      for (final e in ios.entries) {
        await _write(
          'ios/Runner/Assets.xcassets/AppIcon.appiconset/${e.key}',
          e.value,
          inset: 0.12,
          rounded: false,
        );
      }
    });
  });
}
