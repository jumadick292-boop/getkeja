// API client configuration and interceptors.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../config/api_config.dart';
import '../errors/app_exceptions.dart';
import '../storage/secure_storage.dart';

export '../config/api_config.dart' show ApiConfig;

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenStorage);

  final AuthTokenStorage _tokenStorage;
  bool _isRefreshing = false;
  Future<void>? _refreshFuture;
  final List<Completer<void>> _pendingRequests = [];

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final accessToken = await _tokenStorage.getAccessToken();
    if (accessToken != null &&
        accessToken.isNotEmpty &&
        !options.headers.containsKey('Authorization')) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    options.headers['X-Client-Platform'] = 'mobile';
    options.headers['Accept'] = 'application/json';
    handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    // Handle token refresh from response headers or body
    final accessToken = response.headers.value('x-access-token');
    final data = response.data;
    final payload = data is Map<String, dynamic> ? data['data'] : null;
    final bodyAccessToken = payload is Map<String, dynamic>
        ? payload['accessToken'] as String?
        : null;
    final refreshToken = payload is Map<String, dynamic>
        ? payload['refreshToken'] as String?
        : null;
    final enrollmentToken = payload is Map<String, dynamic>
        ? payload['enrollmentToken'] as String?
        : null;

    final access = accessToken ?? bodyAccessToken;
    if (access is String && access.isNotEmpty) {
      await _tokenStorage.saveTokens(
        accessToken: access,
        refreshToken: refreshToken ?? '',
      );
    }
    if (refreshToken is String && refreshToken.isNotEmpty) {
      final currentAccess = await _tokenStorage.getAccessToken();
      if (currentAccess != null) {
        await _tokenStorage.saveTokens(
          accessToken: currentAccess,
          refreshToken: refreshToken,
        );
      }
    }
    if (enrollmentToken is String && enrollmentToken.isNotEmpty) {
      await _tokenStorage.saveEnrollmentToken(enrollmentToken);
    }
    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    // Handle 401 - token expired or revoked
    if (error.response?.statusCode == 401) {
      final code = error.response?.data is Map<String, dynamic>
          ? error.response?.data['code'] as String?
          : null;

      // If it's a token expired/revoked error, try to refresh
      if (code == 'TOKEN_EXPIRED' ||
          code == 'TOKEN_REVOKED' ||
          code == 'UNAUTHORIZED') {
        final requestOptions = error.requestOptions;
        if (_shouldRetry(requestOptions)) {
          try {
            final refreshFuture = _refreshFuture ??= _refreshToken();
            await refreshFuture;
            if (identical(_refreshFuture, refreshFuture)) _refreshFuture = null;
            // Retry the original request with new token
            final newAccessToken = await _tokenStorage.getAccessToken();
            if (newAccessToken != null) {
              requestOptions.extra['retried'] = true;
              requestOptions.headers['Authorization'] =
                  'Bearer $newAccessToken';
              final response = await Dio().fetch(requestOptions);
              handler.resolve(response);
              return;
            }
          } catch (_) {
            _refreshFuture = null;
            await _tokenStorage.clearAllTokens();
          }
        } else {
          await _tokenStorage.clearAllTokens();
        }
      }
    }

    // Handle 429 - rate limited
    if (error.response?.statusCode == 429) {
      final retryAfter = error.response?.headers.value('retry-after');
      throw RateLimitException(
        retryAfter: retryAfter != null ? int.tryParse(retryAfter) : null,
        originalError: error,
      );
    }

    handler.next(error);
  }

  bool _shouldRetry(RequestOptions options) {
    // Don't retry auth endpoints or already retried requests
    final path = options.path;
    if (path.contains('/refresh') ||
        path.contains('/logout') ||
        path.contains('/mfa/') ||
        path.contains('/login') ||
        path.contains('/register') ||
        path.contains('/forgot-password') ||
        path.contains('/reset-password') ||
        path.contains('/verify-email') ||
        path.contains('/verify-phone') ||
        options.extra['retried'] == true) {
      return false;
    }
    return true;
  }

  Future<void> _refreshToken() async {
    // Wait if already refreshing
    if (_isRefreshing) {
      final completer = Completer<void>();
      _pendingRequests.add(completer);
      await completer.future;
      return;
    }

    _isRefreshing = true;

    try {
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        throw const TokenRevokedException();
      }

      final dio = Dio(
        BaseOptions(
          baseUrl: ApiConfig.authBaseUrl,
          connectTimeout: AppConstants.connectTimeout,
          receiveTimeout: AppConstants.receiveTimeout,
        ),
      );

      final response = await dio.post<Map<String, dynamic>>(
        '/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(headers: {'content-type': 'application/json'}),
      );

      final data = response.data;
      final payload = data is Map<String, dynamic> ? data['data'] : null;
      final accessToken = payload is Map<String, dynamic>
          ? payload['accessToken'] as String?
          : null;
      final newRefreshToken = payload is Map<String, dynamic>
          ? payload['refreshToken'] as String?
          : null;

      if (accessToken is String && accessToken.isNotEmpty) {
        await _tokenStorage.saveTokens(
          accessToken: accessToken,
          refreshToken: newRefreshToken ?? refreshToken,
        );
      }
    } finally {
      _isRefreshing = false;
      // Resolve all pending requests
      for (final completer in _pendingRequests) {
        completer.complete();
      }
      _pendingRequests.clear();
    }
  }
}

class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('🌐 REQUEST[${options.method}] ${options.uri}');
      debugPrint('   Headers: ${_sanitizeHeaders(options.headers)}');
      if (options.data != null) {
        debugPrint('   Body: ${_sanitizeBody(options.data)}');
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint(
        '✅ RESPONSE[${response.statusCode}] ${response.requestOptions.uri}',
      );
      debugPrint('   Data: ${_sanitizeBody(response.data)}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException error, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint(
        '❌ ERROR[${error.response?.statusCode ?? 'N/A'}] ${error.requestOptions.uri}',
      );
      debugPrint('   Message: ${error.message}');
      if (error.response?.data != null) {
        debugPrint('   Data: ${_sanitizeBody(error.response?.data)}');
      }
    }
    handler.next(error);
  }

  Map<String, dynamic> _sanitizeHeaders(Map<String, dynamic> headers) {
    final sanitized = <String, dynamic>{};
    headers.forEach((key, value) {
      if (key.toLowerCase().contains('authorization') ||
          key.toLowerCase().contains('token') ||
          key.toLowerCase().contains('cookie')) {
        sanitized[key] = '***REDACTED***';
      } else {
        sanitized[key] = value;
      }
    });
    return sanitized;
  }

  dynamic _sanitizeBody(dynamic body) {
    if (body is Map<String, dynamic>) {
      final sanitized = <String, dynamic>{};
      body.forEach((key, value) {
        final lowerKey = key.toLowerCase();
        if (lowerKey.contains('password') ||
            lowerKey.contains('token') ||
            lowerKey.contains('secret') ||
            lowerKey.contains('code') ||
            lowerKey.contains('otp')) {
          sanitized[key] = '***REDACTED***';
        } else {
          sanitized[key] = value;
        }
      });
      return sanitized;
    }
    return body;
  }
}

class ApiClient {
  ApiClient({Dio? dio, required AuthTokenStorage tokenStorage})
    : _dio = dio ?? _createDio(tokenStorage);

  final Dio _dio;

  String _resolvePath(String path) {
    if (path.startsWith('/api/v1/profile/')) {
      return Uri.parse(ApiConfig.baseUrl).resolve(path).toString();
    }
    return path;
  }

  static Dio _createDio(AuthTokenStorage tokenStorage) {
    return Dio(
        BaseOptions(
          baseUrl: ApiConfig.authBaseUrl,
          connectTimeout: AppConstants.connectTimeout,
          receiveTimeout: AppConstants.receiveTimeout,
          sendTimeout: AppConstants.sendTimeout,
          headers: {'content-type': 'application/json'},
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
      )
      ..interceptors.addAll([
        AuthInterceptor(tokenStorage),
        if (kDebugMode) LoggingInterceptor(),
      ]);
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.get<T>(
      _resolvePath(path),
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.post<T>(
      _resolvePath(path),
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<String> uploadProfileImage({
    required final String filePath,
    required final String fileName,
    required final String kind,
    final String? profileId,
    final String? organizationId,
  }) async {
    FormData form = FormData.fromMap(<String, dynamic>{
      'kind': kind,
      if (profileId != null) 'profileId': profileId,
      if (organizationId != null) 'organizationId': organizationId,
      'file': await MultipartFile.fromFile(
        filePath,
        filename: fileName,
        contentType: DioMediaType.parse(_profileImageMimeType(fileName)),
      ),
    });
    Response<Map<String, dynamic>> response = await post<Map<String, dynamic>>(
      '/api/v1/profile/profile/uploads/image',
      data: form,
    );
    dynamic payload = response.data?['data'];
    if (payload is! Map || payload['secureUrl'] is! String) {
      throw const FormatException(
        'Image upload response did not contain a URL.',
      );
    }
    return payload['secureUrl'] as String;
  }

  Future<Map<String, Object?>> uploadVerificationDocument({
    required String filePath,
    required String fileName,
    required String path,
    String documentType = 'supporting_document',
  }) async {
    final form = FormData.fromMap(<String, dynamic>{
      'documentType': documentType,
      'file': await MultipartFile.fromFile(
        filePath,
        filename: fileName,
        contentType: DioMediaType.parse(
          _verificationDocumentMimeType(fileName),
        ),
      ),
    });
    final response = await post<Map<String, dynamic>>(path, data: form);
    final payload = response.data?['data'];
    if (payload is! Map) {
      throw const FormatException('Document upload response was invalid.');
    }
    return payload.map((key, value) => MapEntry(key.toString(), value));
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.put<T>(
      _resolvePath(path),
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.patch<T>(
      _resolvePath(path),
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.delete<T>(
      _resolvePath(path),
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Dio get dio => _dio;
}

String _profileImageMimeType(String fileName) {
  final extension = fileName.split('.').last.toLowerCase();
  return switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'application/octet-stream',
  };
}

String _verificationDocumentMimeType(String fileName) {
  final extension = fileName.split('.').last.toLowerCase();
  return switch (extension) {
    'pdf' => 'application/pdf',
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'application/octet-stream',
  };
}

final apiClientProvider = Provider<ApiClient>((ref) {
  ApiConfig.validateReleaseConfig();
  return ApiClient(tokenStorage: ref.watch(authTokenStorageProvider));
});
