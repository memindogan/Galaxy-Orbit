import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

void main() {
  final srcFile = File('assets/icons/appstore_icon.png');
  if (!srcFile.existsSync()) {
    print('Error: Source icon not found');
    return;
  }

  final rawImage = img.decodeImage(srcFile.readAsBytesSync())!;
  print('Loaded source image: ${rawImage.width}x${rawImage.height}');

  // Density definitions
  // (densityName, legacySize, adaptiveSize)
  final densities = [
    ('mipmap-mdpi', 48, 108),
    ('mipmap-hdpi', 72, 162),
    ('mipmap-xhdpi', 96, 216),
    ('mipmap-xxhdpi', 144, 324),
    ('mipmap-xxxhdpi', 192, 432),
  ];

  // 1. Prepare master square icon (1024x1024 full bleed)
  // 2. Prepare master round icon (1024x1024 circle mask, no white borders!)
  final roundMaster = img.Image(width: 1024, height: 1024, numChannels: 4);
  final center = 512.0;
  final radius = 510.0; // Fill to edge

  for (int y = 0; y < 1024; y++) {
    for (int x = 0; x < 1024; x++) {
      final dx = x - center;
      final dy = y - center;
      final dist = sqrt(dx * dx + dy * dy);
      final srcPixel = rawImage.getPixel(x, y);

      if (dist <= radius - 1.5) {
        roundMaster.setPixel(x, y, srcPixel);
      } else if (dist <= radius) {
        // Antialiasing edge
        final alphaFactor = (radius - dist) / 1.5;
        final a = (srcPixel.a * alphaFactor).round().clamp(0, 255);
        roundMaster.setPixelRgba(x, y, srcPixel.r, srcPixel.g, srcPixel.b, a);
      } else {
        roundMaster.setPixelRgba(x, y, 0, 0, 0, 0); // transparent outside circle
      }
    }
  }

  // 3. Prepare adaptive foreground (scaled so content sits comfortably inside 66% safe zone)
  // In 108dp adaptive canvas, 72dp is visible (66.6%).
  // Let's scale rawImage by 0.82 and center it on a 1024x1024 transparent canvas.
  final fgMaster = img.Image(width: 1024, height: 1024, numChannels: 4);
  final scaledWidth = (1024 * 0.84).round();
  final scaledHeight = (1024 * 0.84).round();
  final scaledContent = img.copyResize(
    rawImage,
    width: scaledWidth,
    height: scaledHeight,
    interpolation: img.Interpolation.linear,
  );

  final offsetX = (1024 - scaledWidth) ~/ 2;
  final offsetY = (1024 - scaledHeight) ~/ 2;
  img.compositeImage(fgMaster, scaledContent, dstX: offsetX, dstY: offsetY);

  final baseDir = 'android/app/src/main/res';

  for (final (density, legacySize, adaptiveSize) in densities) {
    final targetDir = Directory('$baseDir/$density');
    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    // A. ic_launcher.png (legacy square full bleed)
    final legacyImg = img.copyResize(
      rawImage,
      width: legacySize,
      height: legacySize,
      interpolation: img.Interpolation.linear,
    );
    File('${targetDir.path}/ic_launcher.png').writeAsBytesSync(img.encodePng(legacyImg));

    // B. ic_launcher_round.png (legacy round - NO WHITE RING)
    final roundImg = img.copyResize(
      roundMaster,
      width: legacySize,
      height: legacySize,
      interpolation: img.Interpolation.linear,
    );
    File('${targetDir.path}/ic_launcher_round.png').writeAsBytesSync(img.encodePng(roundImg));

    // C. ic_launcher_foreground.png (for Android adaptive icons)
    final fgImg = img.copyResize(
      fgMaster,
      width: adaptiveSize,
      height: adaptiveSize,
      interpolation: img.Interpolation.linear,
    );
    File('${targetDir.path}/ic_launcher_foreground.png').writeAsBytesSync(img.encodePng(fgImg));

    print('Generated icons for $density (legacy: ${legacySize}px, fg: ${adaptiveSize}px)');
  }

  // 4. Create res/values/colors.xml for adaptive icon background
  final valuesDir = Directory('$baseDir/values');
  if (!valuesDir.existsSync()) valuesDir.createSync(recursive: true);
  
  final colorsXml = '''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#040618</color>
</resources>
''';
  File('$baseDir/values/colors.xml').writeAsStringSync(colorsXml);
  print('Created values/colors.xml with #040618 background');

  // 5. Create res/mipmap-anydpi-v26/ic_launcher.xml
  final anydpiDir = Directory('$baseDir/mipmap-anydpi-v26');
  if (!anydpiDir.existsSync()) anydpiDir.createSync(recursive: true);

  final adaptiveXml = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
''';
  File('$baseDir/mipmap-anydpi-v26/ic_launcher.xml').writeAsStringSync(adaptiveXml);

  // 6. Create res/mipmap-anydpi-v26/ic_launcher_round.xml
  final adaptiveRoundXml = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
''';
  File('$baseDir/mipmap-anydpi-v26/ic_launcher_round.xml').writeAsStringSync(adaptiveRoundXml);
  print('Created mipmap-anydpi-v26 adaptive icon XML definitions');

  print('ALL ANDROID ADAPTIVE & ROUND ICONS GENERATED SUCCESSFULLY!');
}
