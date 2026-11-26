// Marketplace remote datasource (Task 13.5).
import 'package:dio/dio.dart';
import 'package:get_keja_mobile/core/api/api_client.dart' show ApiConfig;
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';

class MarketplaceRemoteDataSource {
  MarketplaceRemoteDataSource(this._dio);

  final Dio _dio;

  String get _basePath => '${ApiConfig.baseUrl}/api/v1/marketplace';

  AppException _mapError(DioException error) {
    final response = error.response;
    final statusCode = response?.statusCode;
    String message = 'Something went wrong. Please try again.';
    final data = response?.data;
    if (data is Map && data['message'] is String) {
      message = data['message'] as String;
    } else if (error.message != null) {
      message = error.message!;
    }
    if (statusCode == 401) {
      return UnauthorizedException(message, statusCode: statusCode, originalError: error);
    }
    if (statusCode == 403) {
      return ForbiddenException(message, statusCode: statusCode, originalError: error);
    }
    return ServerException(
      message: message,
      statusCode: statusCode ?? 500,
      originalError: error,
    );
  }

  Future<List<Map<String, dynamic>>> getCategories({String? domain}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/categories',
        queryParameters: <String, dynamic>{if (domain != null) 'domain': domain},
      );
      final data = response.data?['data'];
      if (data is Map && data['categories'] is List) {
        return (data['categories'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
      }
      return <Map<String, dynamic>>[];
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> createRequest(Map<String, dynamic> body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>('$_basePath/requests', data: body);
      return _unwrapMap(response);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> listRequests({String? status, int limit = 20, int offset = 0}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/requests',
        queryParameters: <String, dynamic>{
          if (status != null) 'status': status,
          'limit': limit,
          'offset': offset,
        },
      );
      final data = response.data;
      final rows = data?['data'];
      final pagination = data?['pagination'];
      return <String, dynamic>{
        'rows': rows is List ? rows.whereType<Map<String, dynamic>>().toList() : <Map<String, dynamic>>[],
        'total': (pagination is Map && pagination['total'] is int) ? pagination['total'] as int : 0,
      };
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> getRequest(String requestId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('$_basePath/requests/$requestId');
      return _unwrapMap(response);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> cancelRequest(String requestId, {String? reason}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath/requests/$requestId/cancel',
        data: <String, dynamic>{if (reason != null) 'reason': reason},
      );
      return _unwrapMap(response);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> acceptQuotation(String requestId, String quotationId, {int? expectedVersion}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath/requests/$requestId/quotations/$quotationId/accept',
        data: <String, dynamic>{if (expectedVersion != null) 'expectedVersion': expectedVersion},
      );
      return _unwrapMap(response);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  // ---- Provider ----
  Future<Map<String, dynamic>> providerInbox({String? domain, int limit = 20, int offset = 0}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/provider/inbox',
        queryParameters: <String, dynamic>{
          if (domain != null) 'domain': domain,
          'limit': limit,
          'offset': offset,
        },
      );
      final data = response.data;
      final rows = data?['data'];
      final pagination = data?['pagination'];
      return <String, dynamic>{
        'rows': rows is List ? rows.whereType<Map<String, dynamic>>().toList() : <Map<String, dynamic>>[],
        'total': (pagination is Map && pagination['total'] is int) ? pagination['total'] as int : 0,
      };
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> providerRequest(String requestId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('$_basePath/provider/requests/$requestId');
      return _unwrapMap(response);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> submitQuotation(String requestId, Map<String, dynamic> body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath/provider/requests/$requestId/quotations',
        data: body,
      );
      return _unwrapMap(response);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> withdrawQuotation(String quotationId, {String? reason}) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '$_basePath/provider/quotations/$quotationId/withdraw',
        data: <String, dynamic>{if (reason != null) 'reason': reason},
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> advanceJob(String requestId, String action) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>('$_basePath/provider/requests/$requestId/advance/$action');
      return _unwrapMap(response);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Map<String, dynamic> _unwrapMap(Response<Map<String, dynamic>> response) {
    final data = response.data?['data'];
    if (data is! Map<String, dynamic>) {
      throw ServerException(
        message: 'Invalid response from server.',
        statusCode: 500,
        originalError: null,
      );
    }
    return data;
  }
}