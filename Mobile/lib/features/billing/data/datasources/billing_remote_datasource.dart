// Recurring billing remote data source (Task 14.1).
// Calls /api/v1/rms/billing via the shared Dio client.
import 'package:dio/dio.dart';
import 'package:get_keja_mobile/core/api/api_client.dart' show ApiConfig;
import 'package:get_keja_mobile/features/billing/data/models/billing_models.dart';

class BillingRemoteDataSource {
  BillingRemoteDataSource(this._dio);

  final Dio _dio;

  String get _basePath => '${ApiConfig.baseUrl}/api/v1/rms/billing';

  List<T> _mapList<T>(dynamic data, T Function(Map<String, dynamic>) fromJson) {
    if (data is! List) return <T>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map(fromJson)
        .toList(growable: false);
  }

  Map<String, dynamic> _unwrap(dynamic data) {
    if (data is Map<String, dynamic>) {
      final inner = data['data'];
      if (inner is Map<String, dynamic>) return inner;
      return data;
    }
    return <String, dynamic>{};
  }

  Future<List<BillingScheduleModel>> listSchedules({String? status, String? propertyId}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_basePath/schedules',
      queryParameters: <String, dynamic>{
        if (status != null) 'status': status,
        if (propertyId != null) 'propertyId': propertyId,
      },
    );
    return _mapList(response.data?['data'], BillingScheduleModel.fromJson);
  }

  Future<BillingScheduleModel> getSchedule(String scheduleId) async {
    final response = await _dio.get<Map<String, dynamic>>('$_basePath/schedules/$scheduleId');
    return BillingScheduleModel.fromJson(_unwrap(response.data));
  }

  Future<BillingScheduleModel> createSchedule(Map<String, dynamic> body) async {
    final response = await _dio.post<Map<String, dynamic>>('$_basePath/schedules', data: body);
    return BillingScheduleModel.fromJson(_unwrap(response.data));
  }

  Future<BillingScheduleModel> changeRent(String scheduleId, Map<String, dynamic> body) async {
    final response = await _dio.patch<Map<String, dynamic>>('$_basePath/schedules/$scheduleId', data: body);
    return BillingScheduleModel.fromJson(_unwrap(response.data));
  }

  Future<BillingScheduleModel> setStatus(String scheduleId, String action, {String? reason}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_basePath/schedules/$scheduleId/$action',
      data: reason != null ? <String, dynamic>{'reason': reason} : <String, dynamic>{},
    );
    return BillingScheduleModel.fromJson(_unwrap(response.data));
  }

  Future<InvoicePreviewModel> preview(String scheduleId) async {
    final response = await _dio.get<Map<String, dynamic>>('$_basePath/schedules/$scheduleId/preview');
    return InvoicePreviewModel.fromJson(_unwrap(response.data));
  }

  Future<List<RentTermModel>> listRentTerms(String scheduleId) async {
    final response = await _dio.get<Map<String, dynamic>>('$_basePath/schedules/$scheduleId/rent-terms');
    return _mapList(response.data?['data'], RentTermModel.fromJson);
  }

  Future<List<BillingInvoiceModel>> listInvoices({String? propertyId, String? billingScheduleId, String? status}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_basePath/invoices',
      queryParameters: <String, dynamic>{
        if (propertyId != null) 'propertyId': propertyId,
        if (billingScheduleId != null) 'billingScheduleId': billingScheduleId,
        if (status != null) 'status': status,
      },
    );
    return _mapList(response.data?['data'], BillingInvoiceModel.fromJson);
  }

  Future<BillingInvoiceModel> voidInvoice(String invoiceId, String reason) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_basePath/invoices/$invoiceId/void',
      data: <String, dynamic>{'reason': reason},
    );
    return BillingInvoiceModel.fromJson(_unwrap(response.data));
  }
}