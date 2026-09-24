import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:autotricks/data/models/client_model.dart';
import 'package:autotricks/data/models/quotation_model.dart';
import 'package:autotricks/data/models/service_job_model.dart';
import 'package:autotricks/data/models/service_request_model.dart';
import 'package:autotricks/data/models/vehicle_model.dart';
import 'package:autotricks/data/repositories/client_portal_repository.dart';
import '../utils/client_status_helper.dart';

final clientPortalRepositoryProvider = Provider<ClientPortalRepository>((ref) {
  return SupabaseClientPortalRepository();
});

/// Profile of the authenticated client
final clientProfileProvider = FutureProvider<ClientModel?>((ref) async {
  final repo = ref.watch(clientPortalRepositoryProvider);
  return repo.fetchClientProfile();
});

/// Vehicles owned by the authenticated client
final clientVehiclesProvider = FutureProvider<List<VehicleModel>>((ref) async {
  final repo = ref.watch(clientPortalRepositoryProvider);
  return repo.fetchClientVehicles();
});

/// Detail of a specific vehicle
final clientVehicleDetailProvider =
    FutureProvider.family<VehicleModel, String>((ref, vehicleId) async {
  final repo = ref.watch(clientPortalRepositoryProvider);
  return repo.getVehicleById(vehicleId);
});

/// All service requests belonging to a specific vehicle
final vehicleServiceRequestsProvider =
    FutureProvider.family<List<ServiceRequestModel>, String>((ref, vehicleId) async {
  final repo = ref.watch(clientPortalRepositoryProvider);
  return repo.fetchServiceRequestsForVehicle(vehicleId);
});

/// All service requests belonging to the authenticated client
final clientServiceRequestsProvider =
    FutureProvider<List<ServiceRequestModel>>((ref) async {
  final repo = ref.watch(clientPortalRepositoryProvider);
  return repo.fetchClientServiceRequests();
});

class ClientServiceFilterNotifier extends Notifier<String> {
  @override
  String build() => 'all';

  void setFilter(String filter) {
    state = filter;
  }
}

/// Filter selection for C05 ('all', 'active', 'completed', 'cancelled')
final clientServiceFilterProvider =
    NotifierProvider<ClientServiceFilterNotifier, String>(
  ClientServiceFilterNotifier.new,
);

/// Service requests filtered by customer status
final filteredClientServiceRequestsProvider =
    Provider<AsyncValue<List<ServiceRequestModel>>>((ref) {
  final requestsAsync = ref.watch(clientServiceRequestsProvider);
  final filter = ref.watch(clientServiceFilterProvider).toLowerCase();

  return requestsAsync.whenData((List<ServiceRequestModel> list) {
    if (filter == 'active') {
      return list.where((ServiceRequestModel sr) => ClientStatusHelper.isActive(
            requestStatus: sr.status,
            jobStatus: sr.jobStatus,
          )).toList();
    } else if (filter == 'completed') {
      return list.where((ServiceRequestModel sr) => ClientStatusHelper.isCompleted(
            requestStatus: sr.status,
            jobStatus: sr.jobStatus,
          )).toList();
    } else if (filter == 'cancelled') {
      return list.where((ServiceRequestModel sr) => ClientStatusHelper.isCancelled(
            requestStatus: sr.status,
            jobStatus: sr.jobStatus,
          )).toList();
    }
    return list;
  });
});

/// Detail of a specific service request
final clientServiceRequestDetailProvider =
    FutureProvider.family<ServiceRequestModel, String>((ref, requestId) async {
  final repo = ref.watch(clientPortalRepositoryProvider);
  return repo.getServiceRequestById(requestId);
});

/// Current active service request for C02 (most recent active request)
final clientActiveRequestProvider =
    Provider<AsyncValue<ServiceRequestModel?>>((ref) {
  final requestsAsync = ref.watch(clientServiceRequestsProvider);
  return requestsAsync.whenData((List<ServiceRequestModel> list) {
    final activeList = list.where((ServiceRequestModel sr) => ClientStatusHelper.isActive(
          requestStatus: sr.status,
          jobStatus: sr.jobStatus,
        )).toList();
    return activeList.isNotEmpty ? activeList.first : null;
  });
});

/// All non-draft quotations belonging to the authenticated client
final clientQuotationsProvider =
    FutureProvider.autoDispose<List<QuotationModel>>((ref) async {
  final repo = ref.watch(clientPortalRepositoryProvider);
  return repo.fetchClientQuotations();
});

class ClientQuoteFilterNotifier extends Notifier<String> {
  @override
  String build() => 'all';

  void setFilter(String filter) {
    state = filter;
  }
}

/// Filter selection for C07 ('all', 'active', 'past')
final clientQuoteFilterProvider =
    NotifierProvider.autoDispose<ClientQuoteFilterNotifier, String>(
  ClientQuoteFilterNotifier.new,
);

/// Quotations filtered per approved Day 10 workflow:
/// - 'all': all visible client quotes
/// - 'active': SENT, VIEWED, CHANGE_REQUESTED, ACCEPTED (pending digital signature)
/// - 'past': REJECTED, SUPERSEDED, CANCELLED, EXPIRED
final clientFilteredQuotationsProvider =
    Provider.autoDispose<AsyncValue<List<QuotationModel>>>((ref) {
  final quotesAsync = ref.watch(clientQuotationsProvider);
  final filter = ref.watch(clientQuoteFilterProvider).toLowerCase();

  return quotesAsync.whenData((List<QuotationModel> list) {
    if (filter == 'active') {
      return list.where((QuotationModel q) {
        final status = q.currentStatus.toUpperCase();
        return status == 'SENT' ||
            status == 'VIEWED' ||
            status == 'CHANGE_REQUESTED' ||
            status == 'ACCEPTED';
      }).toList();
    } else if (filter == 'past') {
      return list.where((QuotationModel q) {
        final status = q.currentStatus.toUpperCase();
        return status == 'REJECTED' ||
            status == 'SUPERSEDED' ||
            status == 'CANCELLED' ||
            status == 'EXPIRED';
      }).toList();
    }
    return list;
  });
});

/// Count of quotations awaiting client action (status == 'SENT' or 'VIEWED')
final clientPendingQuotesCountProvider = Provider.autoDispose<int>((ref) {
  final quotesAsync = ref.watch(clientQuotationsProvider);
  return quotesAsync.maybeWhen(
    data: (quotes) => quotes.where((q) {
      final s = q.currentStatus.toUpperCase();
      return s == 'SENT' || s == 'VIEWED';
    }).length,
    orElse: () => 0,
  );
});

/// Detail of a specific quotation
final clientQuotationDetailProvider =
    FutureProvider.autoDispose.family<QuotationModel, String>((ref, quotationId) async {
  final repo = ref.watch(clientPortalRepositoryProvider);
  return repo.getQuotationById(quotationId);
});

/// Quotation linked to a specific service request (if any)
final clientQuotationForServiceRequestProvider =
    FutureProvider.autoDispose.family<QuotationModel?, String>((ref, serviceRequestId) async {
  final repo = ref.watch(clientPortalRepositoryProvider);
  return repo.getQuotationByServiceRequestId(serviceRequestId);
});

// ============================================================
// DAY 12: SERVICE JOB PROVIDERS
// ============================================================

/// Current active service job for the authenticated client (if any)
final clientActiveJobProvider =
    FutureProvider.autoDispose<ServiceJobModel?>((ref) async {
  final repo = ref.watch(clientPortalRepositoryProvider);
  return repo.fetchActiveServiceJob();
});

/// Detail of a specific service job for client
final clientJobDetailProvider =
    FutureProvider.autoDispose.family<ServiceJobModel, String>((ref, jobId) async {
  final repo = ref.watch(clientPortalRepositoryProvider);
  return repo.getServiceJobById(jobId);
});

/// Service job linked to a specific service request (if any)
final clientJobForRequestProvider =
    FutureProvider.autoDispose.family<ServiceJobModel?, String>((ref, requestId) async {
  final repo = ref.watch(clientPortalRepositoryProvider);
  return repo.getServiceJobByRequestId(requestId);
});

/// Status history for a specific service job
final clientJobHistoryProvider =
    FutureProvider.autoDispose.family<List<ServiceJobStatusHistoryModel>, String>((ref, jobId) async {
  final repo = ref.watch(clientPortalRepositoryProvider);
  return repo.fetchJobStatusHistory(jobId);
});

/// Subscription to realtime service job changes for client live updates.
/// Auto-disposes channel on unmount, and auto-invalidates client job & request providers.
final clientRealtimeJobsProvider = Provider.autoDispose<void>((ref) {
  final repo = ref.watch(clientPortalRepositoryProvider);
  final channel = repo.subscribeToClientJobs(() {
    ref.invalidate(clientActiveJobProvider);
    ref.invalidate(clientServiceRequestsProvider);
    ref.invalidate(clientQuotationsProvider);
  });

  ref.onDispose(() {
    channel.unsubscribe();
  });
});


