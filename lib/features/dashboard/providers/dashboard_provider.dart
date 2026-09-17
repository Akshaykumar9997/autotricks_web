import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:autotricks/features/dashboard/models/dashboard_metrics.dart';
import 'package:autotricks/features/dashboard/repositories/dashboard_repository.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return SupabaseDashboardRepository();
});

class DashboardNotifier extends AsyncNotifier<DashboardMetrics> {
  @override
  Future<DashboardMetrics> build() async {
    final repo = ref.watch(dashboardRepositoryProvider);
    return repo.getDashboardMetrics();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(dashboardRepositoryProvider);
      return repo.getDashboardMetrics();
    });
  }
}

final dashboardMetricsProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardMetrics>(
  DashboardNotifier.new,
);
