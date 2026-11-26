import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/features/rental_applications/data/rental_application_remote_datasource.dart';
import 'package:get_keja_mobile/features/rental_applications/domain/rental_application_models.dart';
import 'package:get_keja_mobile/features/rental_applications/domain/rental_application_repository.dart';

final rentalApplicationRemoteDataSourceProvider =
    Provider<RentalApplicationRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return RentalApplicationRemoteDataSource(apiClient.dio);
});

final rentalApplicationRepositoryProvider =
    Provider<RentalApplicationRepository>((ref) {
  return RentalApplicationRepositoryImpl(
    ref.watch(rentalApplicationRemoteDataSourceProvider),
  );
});

/// Applicant's own application detail.
final applicationDetailProvider = FutureProvider.family<
    RentalApplicationDetailModel, String>((ref, applicationId) {
  return ref.watch(rentalApplicationRepositoryProvider).getDetail(applicationId);
});

/// Manager inbox with an optional status filter.
final managedInboxProvider = FutureProvider.family<ManagedApplicationListModel, String?>(
  (ref, status) {
    return ref.watch(rentalApplicationRepositoryProvider).listInbox(status: status);
  },
);