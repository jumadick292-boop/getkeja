// Tenancy repository implementation.
// Delegates to the remote datasource and maps errors to domain exceptions.
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';
import 'package:get_keja_mobile/features/tenancies/data/datasources/tenancy_remote_datasource.dart';
import 'package:get_keja_mobile/features/tenancies/domain/entities/tenancy_model.dart';
import 'package:get_keja_mobile/features/tenancies/domain/repositories/tenancy_repository.dart';

class TenancyRepositoryImpl implements TenancyRepository {
  TenancyRepositoryImpl(this._remote);

  final TenancyRemoteDataSource _remote;

  @override
  Future<TenantDashboardModel> getDashboard() async {
    try {
      return await _remote.getDashboard();
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load dashboard.',
        originalError: error,
      );
    }
  }

  @override
  Future<List<TenancyModel>> getTenancies({String? status}) async {
    try {
      return await _remote.getTenancies(status: status);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load tenancies.',
        originalError: error,
      );
    }
  }

  @override
  Future<TenancyDetailResponse?> getTenancyById(String tenancyId) async {
    try {
      return await _remote.getTenancyById(tenancyId);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServerException(
        message: 'Failed to load tenancy details.',
        originalError: error,
      );
    }
  }
}
