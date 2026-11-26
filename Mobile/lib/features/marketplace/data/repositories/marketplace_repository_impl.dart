// Marketplace repository contract (Task 13.5).
import 'package:get_keja_mobile/features/marketplace/data/datasources/marketplace_remote_datasource.dart';

class MarketplaceRepository {
  MarketplaceRepository(this._remote);

  final MarketplaceRemoteDataSource _remote;

  Future<List<Map<String, dynamic>>> getCategories({String? domain}) =>
      _remote.getCategories(domain: domain);

  Future<Map<String, dynamic>> createRequest(Map<String, dynamic> body) =>
      _remote.createRequest(body);

  Future<Map<String, dynamic>> listRequests({String? status, int limit = 20, int offset = 0}) =>
      _remote.listRequests(status: status, limit: limit, offset: offset);

  Future<Map<String, dynamic>> getRequest(String requestId) => _remote.getRequest(requestId);

  Future<Map<String, dynamic>> cancelRequest(String requestId, {String? reason}) =>
      _remote.cancelRequest(requestId, reason: reason);

  Future<Map<String, dynamic>> acceptQuotation(String requestId, String quotationId, {int? expectedVersion}) =>
      _remote.acceptQuotation(requestId, quotationId, expectedVersion: expectedVersion);

  Future<Map<String, dynamic>> providerInbox({String? domain, int limit = 20, int offset = 0}) =>
      _remote.providerInbox(domain: domain, limit: limit, offset: offset);

  Future<Map<String, dynamic>> providerRequest(String requestId) => _remote.providerRequest(requestId);

  Future<Map<String, dynamic>> submitQuotation(String requestId, Map<String, dynamic> body) =>
      _remote.submitQuotation(requestId, body);

  Future<void> withdrawQuotation(String quotationId, {String? reason}) =>
      _remote.withdrawQuotation(quotationId, reason: reason);

  Future<Map<String, dynamic>> advanceJob(String requestId, String action) =>
      _remote.advanceJob(requestId, action);
}