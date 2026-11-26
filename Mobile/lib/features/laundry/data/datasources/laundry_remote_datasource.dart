// Laundry operations remote datasource (Task 13.8).
import 'package:dio/dio.dart';
import 'package:get_keja_mobile/core/api/api_client.dart' show ApiConfig;
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';

class LaundryRemoteDataSource {
  LaundryRemoteDataSource(this._dio);

  final Dio _dio;

  String get _basePath => '${ApiConfig.baseUrl}/api/v1/laundry';

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
    return ServerException(message: message, statusCode: statusCode ?? 500, originalError: error);
  }

  Map<String, dynamic> _unwrap(Response<Map<String, dynamic>> response) {
    final data = response.data?['data'];
    if (data is! Map<String, dynamic>) {
      throw ServerException(message: 'Invalid response from server.', statusCode: 500, originalError: null);
    }
    return data;
  }

  Future<List<Map<String, dynamic>>> _list(String path, {String? status}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: <String, dynamic>{if (status != null) 'status': status},
      );
      final data = response.data?['data'];
      if (data is! List) return <Map<String, dynamic>>[];
      return data.whereType<Map<String, dynamic>>().toList();
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  // ---- Customer ----
  Future<List<Map<String, dynamic>>> listCustomerOrders({String? status}) => _list('$_basePath/orders', status: status);

  Future<Map<String, dynamic>> getCustomerOrder(String orderId) async {
    try {
      return _unwrap(await _dio.get<Map<String, dynamic>>('$_basePath/orders/$orderId'));
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> confirmCompletion(String orderId, {required bool confirm, String? notes}) async {
    try {
      return _unwrap(await _dio.post<Map<String, dynamic>>(
        '$_basePath/orders/$orderId/confirm-completion',
        data: <String, dynamic>{'confirm': confirm, if (notes != null) 'notes': notes},
      ));
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> cancelOrder(String orderId, String reason) async {
    try {
      return _unwrap(await _dio.post<Map<String, dynamic>>(
        '$_basePath/orders/$orderId/cancel',
        data: <String, dynamic>{'reason': reason},
      ));
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  // ---- Provider ----
  Future<List<Map<String, dynamic>>> listProviderOrders({String? status}) => _list('$_basePath/provider/orders', status: status);

  Future<Map<String, dynamic>> getProviderOrder(String orderId) async {
    try {
      return _unwrap(await _dio.get<Map<String, dynamic>>('$_basePath/provider/orders/$orderId'));
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> updateProgress(String orderId, String toStatus, {Map<String, bool>? checklist}) async {
    try {
      return _unwrap(await _dio.post<Map<String, dynamic>>(
        '$_basePath/provider/orders/$orderId/progress',
        data: <String, dynamic>{'toStatus': toStatus, if (checklist != null) 'checklist': checklist},
      ));
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> submitCompletion(String orderId, {String? notes, bool outstandingIssue = false, List<String> evidence = const []}) async {
    try {
      return _unwrap(await _dio.post<Map<String, dynamic>>(
        '$_basePath/provider/orders/$orderId/completion',
        data: <String, dynamic>{
          if (notes != null) 'notes': notes,
          'outstandingIssue': outstandingIssue,
          'evidenceDocumentIds': evidence,
        },
      ));
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }
}