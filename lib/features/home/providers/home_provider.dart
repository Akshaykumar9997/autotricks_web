import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:autotricks/data/repositories/home_repository.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return SupabaseHomeRepository();
});

final homeDataProvider = FutureProvider.autoDispose<HomeDashboardData>((ref) async {
  final repo = ref.watch(homeRepositoryProvider);
  return repo.fetchHomeData();
});
