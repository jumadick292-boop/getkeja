// Provider platform remote datasource (Task 13.16).
// Talks to /api/v1/provider/dashboard, /provider/reports, /reviews, /complaints.
import 'package:dio/dio.dart';
import 'package:get_keja_mobile/core/api/api_client.dart' show ApiConfig;
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';

class ProviderPlatformRemoteDataSource {
  ProviderPlatformRemoteDataSource(this._dio);

  final Dio _dio;

  String get _base => '${ApiConfig.baseUrl}/api/v1';

  AppException _mapError(DioException error) {
    final statusCode = error.response?.statusCode;
    String message = 'Something went wrong. Please try again.';
    final body = error.response?.data;
    if (body is Map && body['message'] is String) message = body['message'] as String;
    if (statusCode == 401) return UnauthorizedException(message, statusCode: statusCode, originalError: error);
    if (statusCode == 403) return ForbiddenException(message, statusCode: statusCode, originalError: error);
    if (statusCode == 404) return ServerException(message: message, code: 'NOT_FOUND', statusCode: 404, originalError: error);
    if (statusCode == 409) return ServerException(message: message, code: 'CONFLICT', statusCode: 409, originalError: error);
    return ServerException(message: message, statusCode: statusCode ?? 500, originalError: error);
  }

  // ---- Dashboard ----
  Future<Map<String, dynamic>> getDashboard({String? domain, String? categoryId, String? status, String? from, String? to, String? organizationId}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '$_base/provider/dashboard',
        options: Options(headers: <String, dynamic>{if (organizationId != null) 'x-organization-id': organizationId}),
        queryParameters: <String, dynamic>{
          if (domain != null) 'domain': domain,
          if (categoryId != null) 'categoryId': categoryId,
          if (status != null) 'status': status,
          if (from != null) 'from': from,
          if (to != null) 'to': to,
        },
      );
      return (res.data?['data'] as Map<String, dynamic>).cast<String, dynamic>();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getStaffWorkload({String? organizationId}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '$_base/provider/dashboard/staff-workload',
        options: Options(headers: <String, dynamic>{if (organizationId != null) 'x-organization-id': organizationId}),
      );
      return (res.data?['data'] as List<dynamic>? ?? <dynamic>[]).whereType<Map<String, dynamic>>().toList(growable: false);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ---- Reports ----
  Future<List<Map<String, dynamic>>> getOperationalReport({String? domain, String? categoryId, String? from, String? to, String? organizationId}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '$_base/provider/reports/operational',
        options: Options(headers: <String, dynamic>{if (organizationId != null) 'x-organization-id': organizationId}),
        queryParameters: <String, dynamic>{if (domain != null) 'domain': domain, if (categoryId != null) 'categoryId': categoryId, if (from != null) 'from': from, if (to != null) 'to': to},
      );
      return (res.data?['data'] as List<dynamic>? ?? <dynamic>[]).whereType<Map<String, dynamic>>().toList(growable: false);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getServicePerformance({String? organizationId}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '$_base/provider/reports/service-performance',
        options: Options(headers: <String, dynamic>{if (organizationId != null) 'x-organization-id': organizationId}),
      );
      return (res.data?['data'] as List<dynamic>? ?? <dynamic>[]).whereType<Map<String, dynamic>>().toList(growable: false);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ---- Reviews ----
  Future<Map<String, dynamic>> submitReview(String domain, String resourceId, Map<String, dynamic> body) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('$_base/reviews/resources/$domain/$resourceId', data: body);
      return (res.data?['data'] as Map<String, dynamic>).cast<String, dynamic>();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<Map<String, dynamic>>> listProviderReviews({String? organizationId}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '$_base/reviews/provider',
        options: Options(headers: <String, dynamic>{if (organizationId != null) 'x-organization-id': organizationId}),
        queryParameters: <String, dynamic>{'limit': 50},
      );
      return (res.data?['data'] as List<dynamic>? ?? <dynamic>[]).whereType<Map<String, dynamic>>().toList(growable: false);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<Map<String, dynamic>>> listMyReviews() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('$_base/reviews/mine', queryParameters: <String, dynamic>{'limit': 50});
      return (res.data?['data'] as List<dynamic>? ?? <dynamic>[]).whereType<Map<String, dynamic>>().toList(growable: false);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> respondReview(String reviewId, String response, {String? organizationId}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '$_base/reviews/$reviewId/respond',
        options: Options(headers: <String, dynamic>{if (organizationId != null) 'x-organization-id': organizationId}),
        data: <String, dynamic>{'response': response},
      );
      return (res.data?['data'] as Map<String, dynamic>).cast<String, dynamic>();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> getRating(String providerProfileId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('$_base/reviews/profiles/$providerProfileId/rating');
      return (res.data?['data'] as Map<String, dynamic>).cast<String, dynamic>();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ---- Complaints ----
  Future<List<Map<String, dynamic>>> getComplaintReasons() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('$_base/complaints/reasons');
      return (res.data?['data'] as List<dynamic>? ?? <dynamic>[]).whereType<Map<String, dynamic>>().toList(growable: false);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> submitComplaint(String domain, String resourceId, Map<String, dynamic> body) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('$_base/complaints/resources/$domain/$resourceId', data: body);
      return (res.data?['data'] as Map<String, dynamic>).cast<String, dynamic>();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<Map<String, dynamic>>> listMyComplaints() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('$_base/complaints/mine', queryParameters: <String, dynamic>{'limit': 50});
      return (res.data?['data'] as List<dynamic>? ?? <dynamic>[]).whereType<Map<String, dynamic>>().toList(growable: false);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<Map<String, dynamic>>> listProviderComplaints({String? organizationId}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '$_base/complaints/provider',
        options: Options(headers: <String, dynamic>{if (organizationId != null) 'x-organization-id': organizationId}),
        queryParameters: <String, dynamic>{'limit': 50},
      );
      return (res.data?['data'] as List<dynamic>? ?? <dynamic>[]).whereType<Map<String, dynamic>>().toList(growable: false);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<Map<String, dynamic>>> listAdminComplaints() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('$_base/complaints/admin/queue', queryParameters: <String, dynamic>{'limit': 50});
      return (res.data?['data'] as List<dynamic>? ?? <dynamic>[]).whereType<Map<String, dynamic>>().toList(growable: false);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> getComplaint(String complaintId, {String? organizationId}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '$_base/complaints/$complaintId',
        options: Options(headers: <String, dynamic>{if (organizationId != null) 'x-organization-id': organizationId}),
      );
      return (res.data?['data'] as Map<String, dynamic>).cast<String, dynamic>();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> postComplaintMessage(String complaintId, String body, {String? organizationId}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '$_base/complaints/$complaintId/messages',
        options: Options(headers: <String, dynamic>{if (organizationId != null) 'x-organization-id': organizationId}),
        data: <String, dynamic>{'body': body},
      );
      return (res.data?['data'] as Map<String, dynamic>).cast<String, dynamic>();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> recordCorrectiveAction(String complaintId, String action, {String? organizationId}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '$_base/complaints/$complaintId/corrective-actions',
        options: Options(headers: <String, dynamic>{if (organizationId != null) 'x-organization-id': organizationId}),
        data: <String, dynamic>{'action': action},
      );
      return (res.data?['data'] as Map<String, dynamic>).cast<String, dynamic>();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> changeComplaintStatus(String complaintId, String to, {String? reason, String? resolutionSummary, String? organizationId}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '$_base/complaints/$complaintId/status',
        options: Options(headers: <String, dynamic>{if (organizationId != null) 'x-organization-id': organizationId}),
        data: <String, dynamic>{'to': to, if (reason != null) 'reason': reason, if (resolutionSummary != null) 'resolutionSummary': resolutionSummary},
      );
      return (res.data?['data'] as Map<String, dynamic>).cast<String, dynamic>();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }
}