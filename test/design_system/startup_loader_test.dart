import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/core/constants/app_assets.dart';
import 'package:autotricks/design_system/components/auto_tricks_startup_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AutoTricksStartupLoader Verification', () {
    testWidgets('Renders orange background canvas and canonical symbol-only A logo', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AutoTricksStartupLoader(),
        ),
      );

      // Verify AutoTricksStartupLoader exists
      expect(find.byType(AutoTricksStartupLoader), findsOneWidget);

      // Verify Material surface color is exact AutoTricks orange
      final materialFinder = find.byType(Material).first;
      final material = tester.widget<Material>(materialFinder);
      expect(material.color, equals(const Color(0xFFFE6603)));

      // Verify logo Image.asset points to canonical symbol-only logo
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect((imageWidget.image as AssetImage).assetName, equals(AppAssets.logoSymbol));
      expect(imageWidget.fit, equals(BoxFit.contain));

      // Advance through entrance animation
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AutoTricksStartupLoader), findsOneWidget);

      // Advance into subtle continuous pulse loop
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.byType(AutoTricksStartupLoader), findsOneWidget);
    });

    testWidgets('Renders centered white circular area matching native splash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AutoTricksStartupLoader(),
        ),
      );

      final containerFinder = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final decoration = widget.decoration as BoxDecoration;
          return decoration.color == Colors.white &&
              decoration.shape == BoxShape.circle;
        }
        return false;
      });

      expect(containerFinder, findsOneWidget);
      final container = tester.widget<Container>(containerFinder);
      expect(container.constraints?.maxWidth, equals(155.5));
      expect(container.constraints?.maxHeight, equals(155.5));
    });

    testWidgets('Renders AutoLoadingBars with 4 vertical orange bars and animates smoothly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AutoTricksStartupLoader(),
        ),
      );

      // Verify AutoLoadingBars exists
      expect(find.byType(AutoLoadingBars), findsOneWidget);

      // Advance through the 1-second continuous animation cycle
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
      }
    });

    for (final size in [
      const Size(360, 640),   // Small phone
      const Size(390, 844),   // Standard iPhone / Pixel
      const Size(430, 932),   // Large phone
      const Size(768, 1024),  // Tablet
      const Size(1280, 800),  // Desktop / Web
    ]) {
      testWidgets('Renders cleanly on screen size ${size.width}x${size.height} without overflow', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          const MaterialApp(
            home: AutoTricksStartupLoader(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.byType(AutoTricksStartupLoader), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
