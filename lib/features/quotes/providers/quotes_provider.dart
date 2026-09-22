import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/quotation_model.dart';
import '../../../data/repositories/quotations_repository.dart';

/// Provider for the QuotationsRepository instance.
final quotationsRepositoryProvider = Provider<QuotationsRepository>((ref) {
  return SupabaseQuotationsRepository();
});

/// Filter parameters for quotations listing.
class QuotationFilterParams {
  final String? statusFilter;
  final String? searchQuery;

  const QuotationFilterParams({
    this.statusFilter,
    this.searchQuery,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuotationFilterParams &&
          runtimeType == other.runtimeType &&
          statusFilter == other.statusFilter &&
          searchQuery == other.searchQuery;

  @override
  int get hashCode => Object.hash(statusFilter, searchQuery);
}

/// Provider for listing quotations with filtering and search support.
final quotationsListProvider = FutureProvider.autoDispose
    .family<List<QuotationModel>, QuotationFilterParams>((ref, params) async {
  final repo = ref.watch(quotationsRepositoryProvider);
  return repo.fetchQuotations(
    statusFilter: params.statusFilter,
    searchQuery: params.searchQuery,
  );
});

/// Provider for fetching a single quotation's full details by UUID.
final quotationDetailProvider = FutureProvider.autoDispose
    .family<QuotationModel, String>((ref, quotationId) async {
  final repo = ref.watch(quotationsRepositoryProvider);
  return repo.getQuotationById(quotationId);
});

/// Provider for fetching quotation associated with a service request.
final serviceRequestQuotationProvider = FutureProvider.autoDispose
    .family<QuotationModel?, String>((ref, serviceRequestId) async {
  final repo = ref.watch(quotationsRepositoryProvider);
  return repo.getQuotationByServiceRequestId(serviceRequestId);
});
