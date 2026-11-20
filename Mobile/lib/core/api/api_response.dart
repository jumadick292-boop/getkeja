// API response models.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'api_response.freezed.dart';

@freezed
abstract class ApiResponse<T> with _$ApiResponse<T> {
  const factory ApiResponse.success({
    required T data,
    String? message,
  }) = ApiSuccess<T>;

  const factory ApiResponse.error({
    required String message,
    String? code,
    Map<String, List<String>>? errors,
  }) = ApiError<T>;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object?) fromJsonT,
  ) {
    if (json['success'] == true) {
      return ApiResponse.success(
        data: fromJsonT(json['data']),
        message: json['message'] as String?,
      );
    } else {
      return ApiResponse.error(
        message: json['message'] as String? ?? 'Unknown error',
        code: json['code'] as String?,
        errors: (json['errors'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(
            key,
            (value as List<dynamic>).cast<String>(),
          ),
        ),
      );
    }
  }
}

@freezed
abstract class PaginatedResponse<T> with _$PaginatedResponse<T> {
  const factory PaginatedResponse({
    required List<T> items,
    required int total,
    required int page,
    required int pageSize,
    required bool hasMore,
  }) = _PaginatedResponse<T>;

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object?) fromJsonT,
  ) {
    return PaginatedResponse<T>(
      items: (json['items'] as List<dynamic>? ?? [])
          .map(fromJsonT)
          .toList(),
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? 20,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}

extension ApiResponseX<T> on ApiResponse<T> {
  bool get isSuccess => this is ApiSuccess<T>;
  bool get isError => this is ApiError<T>;

  T? get dataOrNull => this is ApiSuccess<T> ? (this as ApiSuccess<T>).data : null;

  String? get errorMessage => this is ApiError<T> ? (this as ApiError<T>).message : null;

  String? get errorCode => this is ApiError<T> ? (this as ApiError<T>).code : null;
}