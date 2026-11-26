// Garbage collection operations repository (Task 13.7).
import 'package:get_keja_mobile/features/garbage/data/datasources/garbage_ops_remote_datasource.dart';

class GarbageOpsRepository {
  GarbageOpsRepository(this._remote);

  final GarbageOpsRemoteDataSource _remote;

  Future<List<Map<String, dynamic>>> listCustomerJobs({String? status}) => _remote.listCustomerJobs(status: status);
  Future<Map<String, dynamic>> getCustomerJob(String jobId) => _remote.getCustomerJob(jobId);
  Future<Map<String, dynamic>> confirmCompletion(String jobId, {required bool confirm, String? notes}) =>
      _remote.confirmCompletion(jobId, confirm: confirm, notes: notes);
  Future<Map<String, dynamic>> cancelJob(String jobId, String reason) => _remote.cancelJob(jobId, reason);
  Future<List<Map<String, dynamic>>> listCustomerAgreements() => _remote.listCustomerAgreements();
  Future<Map<String, dynamic>> decideAgreement(String agreementId, bool accept) => _remote.decideAgreement(agreementId, accept);

  Future<List<Map<String, dynamic>>> listProviderJobs({String? status}) => _remote.listProviderJobs(status: status);
  Future<Map<String, dynamic>> getProviderJob(String jobId) => _remote.getProviderJob(jobId);
  Future<Map<String, dynamic>> updateProgress(String jobId, String toStatus, {Map<String, bool>? checklist}) =>
      _remote.updateProgress(jobId, toStatus, checklist: checklist);
  Future<Map<String, dynamic>> submitCompletion(String jobId, {String? notes, bool outstandingIssue = false, List<String> evidence = const []}) =>
      _remote.submitCompletion(jobId, notes: notes, outstandingIssue: outstandingIssue, evidence: evidence);
  Future<List<Map<String, dynamic>>> listProviderAgreements() => _remote.listProviderAgreements();
}