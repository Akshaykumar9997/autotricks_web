import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/service_job_model.dart';
import '../../../data/repositories/service_jobs_repository.dart';

final serviceJobsRepositoryProvider = Provider<ServiceJobsRepository>((ref) {
  return SupabaseServiceJobsRepository();
});

class ServiceJobFilterNotifier extends Notifier<String> {
  @override
  String build() => 'ALL';

  void setFilter(String filter) {
    state = filter;
  }
}

final serviceJobFilterProvider =
    NotifierProvider<ServiceJobFilterNotifier, String>(
  ServiceJobFilterNotifier.new,
);

class ServiceJobSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setSearch(String query) {
    state = query;
  }
}

final serviceJobSearchProvider =
    NotifierProvider<ServiceJobSearchNotifier, String>(
  ServiceJobSearchNotifier.new,
);

/// List of service jobs based on current filter & search
final serviceJobsListProvider =
    FutureProvider.autoDispose<List<ServiceJobModel>>((ref) async {
  final repo = ref.watch(serviceJobsRepositoryProvider);
  final filter = ref.watch(serviceJobFilterProvider);
  final search = ref.watch(serviceJobSearchProvider);

  return repo.fetchServiceJobs(
    statusFilter: filter,
    searchQuery: search,
  );
});

/// Detail of a specific service job
final serviceJobDetailProvider =
    FutureProvider.autoDispose.family<ServiceJobModel, String>((ref, jobId) async {
  final repo = ref.watch(serviceJobsRepositoryProvider);
  return repo.getServiceJobById(jobId);
});

/// Service job linked to a specific service request
final serviceJobForRequestProvider =
    FutureProvider.autoDispose.family<ServiceJobModel?, String>((ref, requestId) async {
  final repo = ref.watch(serviceJobsRepositoryProvider);
  return repo.getServiceJobByRequestId(requestId);
});

/// Service job linked to a specific quotation revision
final serviceJobForRevisionProvider =
    FutureProvider.autoDispose.family<ServiceJobModel?, String>((ref, revisionId) async {
  final repo = ref.watch(serviceJobsRepositoryProvider);
  return repo.getServiceJobByRevisionId(revisionId);
});
