import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/constants.dart';

class ApiClient {
  ApiClient._();

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConstants.backendBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 45),
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
          debugPrint('✗ [ApiClient] ${error.type}: ${error.message}');

          // Intercept connection-level failures (DNS lookup, tunnel down,
          // timeout) and resolve them as a synthetic 503 response.
          // This prevents NativeSocket.lookup from pausing the debugger
          // and keeps all error handling in one place (statusCode checks).
          final isConnectionFailure =
              error.type == DioExceptionType.connectionError ||
              error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.sendTimeout ||
              error.error is SocketException;

          if (isConnectionFailure) {
            debugPrint('⚠ [ApiClient] Engine unreachable — returning synthetic 503');
            return handler.resolve(
              Response(
                requestOptions: error.requestOptions,
                statusCode: 503,
                data: {
                  'error': 'Niramaya Engine is currently offline.',
                  'hint': 'Check ngrok tunnel and restart .\\dev.ps1',
                },
              ),
            );
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

  /// GET /v1/health — lightweight tunnel liveness check
  /// Returns true if the engine responds, false on any network failure.
  static Future<bool> isEngineOnline() async {
    try {
      final response = await _dio.get(
        AppConstants.healthEndpoint,
        options: Options(sendTimeout: const Duration(seconds: 5)),
      );
      return response.statusCode != null && response.statusCode! < 500;
    } on SocketException {
      return false;
    } on DioException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
