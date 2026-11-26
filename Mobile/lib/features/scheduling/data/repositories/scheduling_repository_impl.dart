// Shared scheduling repository (Task 13.9).
import 'package:get_keja_mobile/features/scheduling/data/datasources/scheduling_remote_datasource.dart';

class SchedulingRepository {
  SchedulingRepository(this._remote);

  final SchedulingRemoteDataSource _remote;

  Future<List<Map<String, dynamic>>> providerCalendar({required String from, required String to, List<String>? domains, String? status, String? staffUserId}) =>
      _remote.providerCalendar(from: from, to: to, domains: domains, status: status, staffUserId: staffUserId);

  Future<List<Map<String, dynamic>>> customerCalendar({required String from, required String to}) =>
      _remote.customerCalendar(from: from, to: to);

  Future<Map<String, dynamic>> getActivity(String activityId) => _remote.getActivity(activityId);

  Future<Map<String, dynamic>> requestReschedule(String activityId, {required String requestedStartAt, required String requestedEndAt, String? reason}) =>
      _remote.requestReschedule(activityId, requestedStartAt: requestedStartAt, requestedEndAt: requestedEndAt, reason: reason);

  Future<Map<String, dynamic>> decideReschedule(String activityId, String requestId, bool accept) =>
      _remote.decideReschedule(activityId, requestId, accept);
}