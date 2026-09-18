class ServiceJobSummaryModel {
  final String id;
  final String jobNumber;
  final String vehicleTitle;
  final String status;
  final String clientName;
  final int workItemsCompleted;
  final int workItemsTotal;

  const ServiceJobSummaryModel({
    required this.id,
    required this.jobNumber,
    required this.vehicleTitle,
    required this.status,
    required this.clientName,
    this.workItemsCompleted = 0,
    this.workItemsTotal = 0,
  });

  factory ServiceJobSummaryModel.fromJson(Map<String, dynamic> json) {
    final vehicle = json['vehicles'] as Map<String, dynamic>?;
    final client = json['clients'] as Map<String, dynamic>?;

    String vehicleTitle = 'Vehicle';
    if (vehicle != null) {
      final make = vehicle['make'] ?? '';
      final model = vehicle['model'] ?? '';
      final year = vehicle['manufacturing_year']?.toString();
      vehicleTitle = '$make $model${year != null ? " · $year" : ""}';
    }

    return ServiceJobSummaryModel(
      id: json['id'] as String,
      jobNumber: json['job_number'] as String? ?? 'JOB-0000',
      vehicleTitle: vehicleTitle,
      status: json['status'] as String? ?? 'SCHEDULED',
      clientName: client?['full_name'] as String? ?? 'Customer',
    );
  }
}
