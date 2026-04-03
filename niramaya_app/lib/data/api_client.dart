import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/constants.dart';

class ApiClient {
  ApiClient._();

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConstants.backendBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    },
    // Do not throw on 4xx/5xx — let callers inspect the response
    validateStatus: (status) => status != null && status < 600,
  ))
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (kDebugMode) {
            debugPrint('→ ${options.method} ${options.uri}');
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint('← ${response.statusCode} ${response.requestOptions.uri}');
          }
          return handler.next(response);
        },
        onError: (error, handler) {
          if (kDebugMode) {
            debugPrint('✗ ${error.message}');
          }
          return handler.next(error);
        },
      ),
    );

  static Dio get instance => _dio;

  /// POST /v1/dispatch
  static Future<Response> dispatch({
    required String patientId,
    required double latitude,
    required double longitude,
    String requiredDept = 'emergency',
  }) {
    return _dio.post(AppConstants.dispatchEndpoint, data: {
      'patient_id': patientId,
      'latitude': latitude,
      'longitude': longitude,
      'required_dept': requiredDept,
    });
  }

  /// GET /v1/dispatch/status?id=...
  static Future<Response> dispatchStatus(String dispatchId) {
    return _dio.get(
      AppConstants.dispatchStatusEndpoint,
      queryParameters: {'id': dispatchId},
    );
  }

  /// PUT /v1/consent/hospital-access
  static Future<Response> updateConsent({
    required String patientHash,
    required bool allowHospitalAccess,
    required bool govDataShare,
  }) {
    return _dio.put(AppConstants.consentEndpoint, data: {
      'patient_hash': patientHash,
      'allow_hospital_access': allowHospitalAccess,
      'gov_data_share': govDataShare,
    });
  }

  /// GET /v1/audit/trail
  static Future<Response> auditTrail() {
    return _dio.get(AppConstants.auditTrailEndpoint);
  }
}
