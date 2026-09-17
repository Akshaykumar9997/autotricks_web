import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/core/constants/app_assets.dart';

void main() {
  group('AppAssets Physical Existence Verification', () {
    test('all registered asset files physically exist on disk', () {
      final assets = [
        AppAssets.logoOriginal,
        AppAssets.workshopGarage,
        AppAssets.loaderGarageDark,
        AppAssets.orangeLightTexture,
        AppAssets.carHero,
        AppAssets.loaderCar,
        AppAssets.mechanicRepairingCar,
        AppAssets.uiReferenceBoard,
      ];

      for (final assetPath in assets) {
        final file = File(assetPath);
        expect(
          file.existsSync(),
          isTrue,
          reason: 'Asset file $assetPath does not exist on disk!',
        );
        expect(
          file.lengthSync(),
          greaterThan(0),
          reason: 'Asset file $assetPath is empty (0 bytes)!',
        );
      }
    });
  });
}
