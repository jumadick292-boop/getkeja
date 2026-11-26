// Tenancy repository interface.
// Defines the contract for fetching tenant tenancy data.
import 'package:get_keja_mobile/features/tenancies/domain/entities/tenancy_model.dart';

abstract class TenancyRepository {
  /// Fetch the tenant dashboard summary.
  Future<TenantDashboardModel> getDashboard();

  /// Fetch all tenancies for the authenticated tenant.
  Future<List<TenancyModel>> getTenancies({String? status});

  /// Fetch a single tenancy by ID.
  Future<TenancyDetailResponse?> getTenancyById(String tenancyId);
}
