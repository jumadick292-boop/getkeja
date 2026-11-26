// Provider dashboard entity (foundation).
class ProviderDashboard {
  const ProviderDashboard({
    required this.newEligibleRequests,
    required this.assignedRequests,
    required this.pendingResponses,
    required this.acceptedJobs,
    required this.upcomingJobs,
    required this.activeJobs,
    required this.completedJobs,
    required this.cancelledJobs,
    required this.pendingQuotations,
  });

  final int newEligibleRequests;
  final int assignedRequests;
  final int pendingResponses;
  final int acceptedJobs;
  final int upcomingJobs;
  final int activeJobs;
  final int completedJobs;
  final int cancelledJobs;
  final int pendingQuotations;

  factory ProviderDashboard.fromJson(Map<String, dynamic> json) {
    int read(String key) => (json[key] as num?)?.toInt() ?? 0;
    return ProviderDashboard(
      newEligibleRequests: read('newEligibleRequests'),
      assignedRequests: read('assignedRequests'),
      pendingResponses: read('pendingResponses'),
      acceptedJobs: read('acceptedJobs'),
      upcomingJobs: read('upcomingJobs'),
      activeJobs: read('activeJobs'),
      completedJobs: read('completedJobs'),
      cancelledJobs: read('cancelledJobs'),
      pendingQuotations: read('pendingQuotations'),
    );
  }
}