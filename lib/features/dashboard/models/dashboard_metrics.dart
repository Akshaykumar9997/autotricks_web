/// Metrics model for AutoTricks Admin Dashboard.
///
/// Contains ONLY the 3 essential workshop metrics and overall progress.
class DashboardMetrics {
  final int openRequestsCount;
  final int inServiceJobsCount;
  final int readyJobsCount;
  final int progressPercentage;
  final String progressStatus;
  final String progressSubtitle;

  const DashboardMetrics({
    required this.openRequestsCount,
    required this.inServiceJobsCount,
    required this.readyJobsCount,
    required this.progressPercentage,
    this.progressStatus = 'On Track',
    this.progressSubtitle = 'Keep up the great work!',
  });

  /// Factory for empty/initial states
  factory DashboardMetrics.empty() {
    return const DashboardMetrics(
      openRequestsCount: 0,
      inServiceJobsCount: 0,
      readyJobsCount: 0,
      progressPercentage: 0,
      progressStatus: 'Idle',
      progressSubtitle: 'No active workshop jobs today',
    );
  }

  /// Default baseline metrics matching the approved reference board
  factory DashboardMetrics.referenceBaseline() {
    return const DashboardMetrics(
      openRequestsCount: 12,
      inServiceJobsCount: 9,
      readyJobsCount: 4,
      progressPercentage: 72,
      progressStatus: 'On Track',
      progressSubtitle: 'Keep up the great work!',
    );
  }

  int get activeJobsCount => inServiceJobsCount;
  int get totalTrackedJobs => inServiceJobsCount + readyJobsCount;
}
