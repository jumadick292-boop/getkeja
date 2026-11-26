import 'package:dio/dio.dart';
import 'package:get_keja_mobile/core/api/api_client.dart' show ApiConfig;
import 'package:get_keja_mobile/core/errors/app_exceptions.dart';
import 'package:get_keja_mobile/features/rental_applications/domain/rental_application_models.dart';
import 'package:get_keja_mobile/features/rental_applications/domain/rental_application_repository.dart';

class RentalApplicationRemoteDataSource {
  RentalApplicationRemoteDataSource(this._dio);

  final Dio _dio;

  String get _basePath => '${ApiConfig.baseUrl}/api/v1/rental-applications';

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
    if (statusCode != null && statusCode >= 500) {
      return ServerException(message: message, statusCode: statusCode, originalError: error);
    }
    return ServerException(message: message, statusCode: statusCode ?? 500, originalError: error);
  }

  Future<RentalApplicationRecord> saveDraft(Map<String, dynamic> body) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '$_basePath/applications/draft',
        data: body,
      );
      return RentalApplicationRecord.fromJson(res.data ?? <String, dynamic>{});
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<RentalApplicationRecord> submitApplication(Map<String, dynamic> body) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '$_basePath/applications',
        data: body,
      );
      return RentalApplicationRecord.fromJson(res.data ?? <String, dynamic>{});
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<RentalApplicationRecord> submitDraft(String applicationId) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '$_basePath/applications/$applicationId/submit',
      );
      return RentalApplicationRecord.fromJson(res.data ?? <String, dynamic>{});
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<RentalApplicationRecord> resubmit(
    String applicationId,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '$_basePath/applications/$applicationId/resubmit',
        data: body,
      );
      return RentalApplicationRecord.fromJson(res.data ?? <String, dynamic>{});
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<RentalApplicationRecord> withdraw(String applicationId) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '$_basePath/applications/$applicationId/withdraw',
      );
      return RentalApplicationRecord.fromJson(res.data ?? <String, dynamic>{});
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<RentalApplicationDetailModel> getDetail(String applicationId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '$_basePath/applications/$applicationId',
      );
      return RentalApplicationDetailModel.fromJson(res.data ?? <String, dynamic>{});
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<ManagedApplicationListModel> listInbox({
    String? status,
    String? propertyId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '$_basePath/applications',
        queryParameters: <String, dynamic>{
          if (status != null && status.isNotEmpty) 'status': status,
          if (propertyId != null && propertyId.isNotEmpty) 'propertyId': propertyId,
          'limit': limit,
          'offset': offset,
        },
      );
      return ManagedApplicationListModel.fromJson(res.data ?? <String, dynamic>{});
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<RentalApplicationDetailModel> getManagedDetail(String applicationId) async {
    return getDetail(applicationId);
  }

  Future<RentalApplicationRecord> transition(
    String applicationId,
    String action, {
    String? reason,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '$_basePath/applications/$applicationId/transition',
        data: <String, dynamic>{
          'action': action,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
      );
      final body = res.data ?? <String, dynamic>{};
      final app = body['application'];
      if (app is Map<String, dynamic>) {
        return RentalApplicationRecord.fromJson(app);
      }
      return RentalApplicationRecord.fromJson(body);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<({RentalApplicationRecord application, OnboardingResultModel? onboarding})>
      approve(String applicationId, Map<String, dynamic> body) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '$_basePath/applications/$applicationId/approve',
        data: body,
      );
      final data = res.data ?? <String, dynamic>{};
      final app = data['application'];
      final onboardingRaw = data['onboarding'];
      return (
        application: app is Map<String, dynamic>
            ? RentalApplicationRecord.fromJson(app)
            : RentalApplicationRecord.fromJson(data),
        onboarding: onboardingRaw is Map<String, dynamic>
            ? OnboardingResultModel.fromJson(onboardingRaw)
            : null,
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<OnboardingResultModel> onboard(String applicationId) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '$_basePath/applications/$applicationId/onboard',
      );
      final data = res.data ?? <String, dynamic>{};
      final onboardingRaw = data['onboarding'];
      return onboardingRaw is Map<String, dynamic>
          ? OnboardingResultModel.fromJson(onboardingRaw)
          : OnboardingResultModel();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> addNote(String applicationId, String note) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '$_basePath/applications/$applicationId/notes',
        data: <String, dynamic>{'note': note},
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<ApplicationDocumentModel> uploadDocument(
    String applicationId,
    String filePath,
    String fileName,
    String mimeType, {
    String? category,
  }) async {
    try {
      final form = FormData.fromMap(<String, dynamic>{
        'file': await MultipartFile.fromFile(
          filePath,
          filename: fileName,
          contentType: DioMediaType.parse(mimeType),
        ),
        if (category != null) 'category': category,
      });
      final res = await _dio.post<Map<String, dynamic>>(
        '$_basePath/applications/$applicationId/documents',
        data: form,
      );
      return ApplicationDocumentModel.fromJson(res.data ?? <String, dynamic>{});
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<ApplicationDocumentModel>> listDocuments(String applicationId) async {
    try {
      final res = await _dio.get<List<dynamic>>(
        '$_basePath/applications/$applicationId/documents',
      );
      return (res.data ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(ApplicationDocumentModel.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<String> downloadDocumentUrl(String documentId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '$_basePath/documents/$documentId',
      );
      return (res.data?['url'] as String?) ?? '';
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }
}

class RentalApplicationRepositoryImpl implements RentalApplicationRepository {
  RentalApplicationRepositoryImpl(this._remote);

  final RentalApplicationRemoteDataSource _remote;

  @override
  Future<RentalApplicationRecord> saveDraft(Map<String, dynamic> body) =>
      _remote.saveDraft(body);

  @override
  Future<RentalApplicationRecord> submitApplication(Map<String, dynamic> body) =>
      _remote.submitApplication(body);

  @override
  Future<RentalApplicationRecord> submitDraft(String applicationId) =>
      _remote.submitDraft(applicationId);

  @override
  Future<RentalApplicationRecord> resubmit(
    String applicationId,
    Map<String, dynamic> body,
  ) =>
      _remote.resubmit(applicationId, body);

  @override
  Future<RentalApplicationRecord> withdraw(String applicationId) =>
      _remote.withdraw(applicationId);

  @override
  Future<RentalApplicationDetailModel> getDetail(String applicationId) =>
      _remote.getDetail(applicationId);

  @override
  Future<ManagedApplicationListModel> listInbox({
    String? status,
    String? propertyId,
    int limit = 20,
    int offset = 0,
  }) =>
      _remote.listInbox(status: status, propertyId: propertyId, limit: limit, offset: offset);

  @override
  Future<RentalApplicationDetailModel> getManagedDetail(String applicationId) =>
      _remote.getManagedDetail(applicationId);

  @override
  Future<RentalApplicationRecord> transition(
    String applicationId,
    String action, {
    String? reason,
  }) =>
      _remote.transition(applicationId, action, reason: reason);

  @override
  Future<({RentalApplicationRecord application, OnboardingResultModel? onboarding})>
      approve(String applicationId, Map<String, dynamic> body) =>
          _remote.approve(applicationId, body);

  @override
  Future<OnboardingResultModel> onboard(String applicationId) =>
      _remote.onboard(applicationId);

  @override
  Future<void> addNote(String applicationId, String note) =>
      _remote.addNote(applicationId, note);

  @override
  Future<ApplicationDocumentModel> uploadDocument(
    String applicationId,
    String filePath,
    String fileName,
    String mimeType, {
    String? category,
  }) =>
      _remote.uploadDocument(
        applicationId,
        filePath,
        fileName,
        mimeType,
        category: category,
      );

  @override
  Future<List<ApplicationDocumentModel>> listDocuments(String applicationId) =>
      _remote.listDocuments(applicationId);

  @override
  Future<String> downloadDocumentUrl(String documentId) =>
      _remote.downloadDocumentUrl(documentId);
}