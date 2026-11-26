// Laundry operations repository (Task 13.8).
import 'package:get_keja_mobile/features/laundry/data/datasources/laundry_remote_datasource.dart';

class LaundryRepository {
  LaundryRepository(this._remote);

  final LaundryRemoteDataSource _remote;

  Future<List<Map<String, dynamic>>> listCustomerOrders({String? status}) => _remote.listCustomerOrders(status: status);
  Future<Map<String, dynamic>> getCustomerOrder(String orderId) => _remote.getCustomerOrder(orderId);
  Future<Map<String, dynamic>> confirmCompletion(String orderId, {required bool confirm, String? notes}) =>
      _remote.confirmCompletion(orderId, confirm: confirm, notes: notes);
  Future<Map<String, dynamic>> cancelOrder(String orderId, String reason) => _remote.cancelOrder(orderId, reason);

  Future<List<Map<String, dynamic>>> listProviderOrders({String? status}) => _remote.listProviderOrders(status: status);
  Future<Map<String, dynamic>> getProviderOrder(String orderId) => _remote.getProviderOrder(orderId);
  Future<Map<String, dynamic>> updateProgress(String orderId, String toStatus, {Map<String, bool>? checklist}) =>
      _remote.updateProgress(orderId, toStatus, checklist: checklist);
  Future<Map<String, dynamic>> submitCompletion(String orderId, {String? notes, bool outstandingIssue = false, List<String> evidence = const []}) =>
      _remote.submitCompletion(orderId, notes: notes, outstandingIssue: outstandingIssue, evidence: evidence);
}