// Provider platform state (Task 13.16) — Riverpod providers.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/features/provider_platform/data/datasources/provider_platform_remote_datasource.dart';

final providerPlatformRemoteDataSourceProvider = Provider<ProviderPlatformRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ProviderPlatformRemoteDataSource(apiClient.dio);
});

final providerDashboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(providerPlatformRemoteDataSourceProvider).getDashboard();
});

final providerStaffWorkloadProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(providerPlatformRemoteDataSourceProvider).getStaffWorkload();
});

final providerOperationalReportProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(providerPlatformRemoteDataSourceProvider).getOperationalReport();
});

final providerServicePerformanceProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(providerPlatformRemoteDataSourceProvider).getServicePerformance();
});

final providerReviewsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(providerPlatformRemoteDataSourceProvider).listProviderReviews();
});

final myReviewsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(providerPlatformRemoteDataSourceProvider).listMyReviews();
});

final complaintReasonsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(providerPlatformRemoteDataSourceProvider).getComplaintReasons();
});

final myComplaintsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(providerPlatformRemoteDataSourceProvider).listMyComplaints();
});

final providerComplaintsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(providerPlatformRemoteDataSourceProvider).listProviderComplaints();
});

final adminComplaintsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(providerPlatformRemoteDataSourceProvider).listAdminComplaints();
});

final complaintDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, complaintId) async {
  return ref.watch(providerPlatformRemoteDataSourceProvider).getComplaint(complaintId);
});