import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:autotricks/app/app.dart';
import 'package:autotricks/features/dashboard/providers/dashboard_provider.dart';
import 'package:autotricks/features/dashboard/repositories/dashboard_repository.dart';

void main() {
  testWidgets('AutoTricks root app launches with provider scope',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardRepositoryProvider.overrideWithValue(
            const MockDashboardRepository(),
          ),
        ],
        child: const AutoTricksApp(),
      ),
    );

    // Initial frame pumps SplashScreen
    expect(find.byType(AutoTricksApp), findsOneWidget);
  });
}
