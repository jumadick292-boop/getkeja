// Recurring billing state (Task 14.1) — Riverpod providers.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/features/billing/data/datasources/billing_remote_datasource.dart';
import 'package:get_keja_mobile/features/billing/data/models/billing_models.dart';

final billingRemoteDataSourceProvider = Provider<BillingRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return BillingRemoteDataSource(apiClient.dio);
});

/// All billing schedules visible to the caller.
final billingSchedulesProvider = FutureProvider<List<BillingScheduleModel>>((ref) async {
  final repo = ref.watch(billingRemoteDataSourceProvider);
  return repo.listSchedules();
});

/// A single billing schedule (auto-refreshes after mutations via invalidate).
final billingScheduleProvider =
    FutureProvider.family<BillingScheduleModel, String>((ref, scheduleId) async {
  final repo = ref.watch(billingRemoteDataSourceProvider);
  return repo.getSchedule(scheduleId);
});

/// Rent-term history for a schedule's tenancy.
final rentTermsProvider = FutureProvider.family<List<RentTermModel>, String>((ref, scheduleId) async {
  final repo = ref.watch(billingRemoteDataSourceProvider);
  return repo.listRentTerms(scheduleId);
});

/// Next-invoice preview for a schedule.
final invoicePreviewProvider =
    FutureProvider.family<InvoicePreviewModel, String>((ref, scheduleId) async {
  final repo = ref.watch(billingRemoteDataSourceProvider);
  return repo.preview(scheduleId);
});

/// Invoices for a schedule.
final scheduleInvoicesProvider =
    FutureProvider.family<List<BillingInvoiceModel>, String>((ref, scheduleId) async {
  final repo = ref.watch(billingRemoteDataSourceProvider);
  return repo.listInvoices(billingScheduleId: scheduleId);
});

/// All invoices visible to the landlord (optionally filtered by property).
final landlordInvoicesProvider =
    FutureProvider.family<List<BillingInvoiceModel>, String?>((ref, propertyId) async {
  final repo = ref.watch(billingRemoteDataSourceProvider);
  return repo.listInvoices(propertyId: propertyId);
});