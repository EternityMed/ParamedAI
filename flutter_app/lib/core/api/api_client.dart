import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants.dart';
import '../connectivity/connectivity_manager.dart';
import 'api_endpoints.dart';

/// API client wrapping Dio for all backend communication.
class ApiClient {
  final Dio _dio;
  final Ref _ref;

  ApiClient(this._ref)
      : _dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(
              milliseconds: AppConstants.connectionTimeout,
            ),
            receiveTimeout: const Duration(
              milliseconds: AppConstants.receiveTimeout,
            ),
            sendTimeout: const Duration(
              milliseconds: AppConstants.sendTimeout,
            ),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );

  /// Get the current base URL from connectivity state.
  String get _baseUrl => _ref.read(connectivityProvider).activeEndpoint;

  /// Send a chat message and receive a response with GenUI widgets.
  Future<Map<String, dynamic>> chat({
    required String message,
    List<Map<String, dynamic>>? history,
    Map<String, dynamic>? context,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.chat}',
        data: {
          'message': message,
          if (history != null) 'history': history,
          if (context != null) 'context': context,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Send a chat message and receive a streamed SSE response.
  Stream<String> chatStream({
    required String message,
    List<Map<String, dynamic>>? history,
  }) async* {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.chatStream}',
        data: {
          'message': message,
          if (history != null) 'history': history,
        },
        options: Options(responseType: ResponseType.stream),
      );

      final stream = response.data.stream as Stream<Uint8List>;
      await for (final chunk in stream) {
        final text = String.fromCharCodes(chunk);
        yield text;
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Transcribe audio to text.
  Future<Map<String, dynamic>> transcribe({
    required Uint8List audioData,
    String format = 'wav',
    String language = 'tr',
  }) async {
    try {
      final formData = FormData.fromMap({
        'audio': MultipartFile.fromBytes(audioData, filename: 'audio.$format'),
        'format': format,
        'language': language,
      });

      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.transcribe}',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(milliseconds: 30000),
        ),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Analyze an image (EKG, wound, etc.).
  Future<Map<String, dynamic>> analyzeImage({
    required Uint8List imageData,
    required String filename,
    String? prompt,
  }) async {
    try {
      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(imageData, filename: filename),
        if (prompt != null) 'prompt': prompt,
      });

      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.analyzeImage}',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Classify patient using START triage.
  Future<Map<String, dynamic>> triageClassify({
    required Map<String, dynamic> patientData,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.triageClassify}',
        data: patientData,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }


  /// Generate AI medical documentation from voice transcription.
  Future<Map<String, dynamic>> generateDocumentation({
    required String transcription,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.patientsDocument}',
        data: {'transcription': transcription},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// AI-assisted START triage via MedGemma.
  Future<Map<String, dynamic>> triageAiClassify({
    required bool canWalk,
    required bool hasBreathing,
    required bool hasPulse,
    required bool followsCommands,
    String? notes,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.triageAiClassify}',
        data: {
          'can_walk': canWalk,
          'has_breathing': hasBreathing,
          'has_pulse': hasPulse,
          'follows_commands': followsCommands,
          if (notes != null) 'notes': notes,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Request dispatch from EMSGemmaApp — hospital routing & ambulance assignment.
  Future<Map<String, dynamic>> requestDispatch({
    required String complaint,
    int age = 50,
    String gender = 'Male',
    String district = 'FATIH',
    String? additional,
  }) async {
    try {
      final dispatchDio = Dio(BaseOptions(
        connectTimeout: const Duration(milliseconds: 15000),
        receiveTimeout: const Duration(milliseconds: 30000),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      ));
      final response = await dispatchDio.post(
        '${AppConstants.dispatchApiUrl}/api/dispatch',
        data: {
          'complaint': complaint,
          'age': age,
          'gender': gender,
          'district': district,
          if (additional != null) 'additional': additional,
        },
      );
      dispatchDio.close();
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Calculate drug dose (deterministic).
  Future<Map<String, dynamic>> calculateDrug({
    required String drugName,
    required double weightKg,
    String? indication,
    String? route,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.drugCalculate}',
        data: {
          'drug_name': drugName,
          'weight_kg': weightKg,
          if (indication != null) 'indication': indication,
          if (route != null) 'route': route,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Check server health.
  Future<Map<String, dynamic>> health() async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.health}',
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Handle Dio errors and convert to user-friendly exceptions.
  Exception _handleError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return Exception('Server not responding. Check your connection.');
      case DioExceptionType.connectionError:
        return Exception('Cannot connect to server. You may be in offline mode.');
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 429) {
          return Exception('Too many requests. Please wait.');
        }
        if (statusCode != null && statusCode >= 500) {
          return Exception('Server error ($statusCode). Please try again.');
        }
        return Exception('Request error: $statusCode');
      default:
        return Exception('Unexpected error: ${e.message}');
    }
  }

  void dispose() {
    _dio.close();
  }
}

/// Riverpod provider for the API client.
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(ref);
  ref.onDispose(() => client.dispose());
  return client;
});
