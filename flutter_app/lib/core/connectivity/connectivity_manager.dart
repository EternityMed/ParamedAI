import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants.dart';

/// Represents the current connection state of the app.
class ConnectionState {
  final bool isOnline;
  final bool useLocalLlama;
  final String activeEndpoint;
  final String modelName;
  final DateTime lastCheck;

  const ConnectionState({
    required this.isOnline,
    required this.useLocalLlama,
    required this.activeEndpoint,
    required this.modelName,
    required this.lastCheck,
  });

  /// Fully offline — no remote API, on-device inference.
  bool get isOffline => !isOnline;

  factory ConnectionState.initial() => ConnectionState(
        isOnline: false,
        useLocalLlama: true,
        activeEndpoint: AppConstants.remoteApiUrl,
        modelName: AppConstants.offlineModelName,
        lastCheck: DateTime.now(),
      );

  ConnectionState copyWith({
    bool? isOnline,
    bool? useLocalLlama,
    String? activeEndpoint,
    String? modelName,
    DateTime? lastCheck,
  }) {
    return ConnectionState(
      isOnline: isOnline ?? this.isOnline,
      useLocalLlama: useLocalLlama ?? this.useLocalLlama,
      activeEndpoint: activeEndpoint ?? this.activeEndpoint,
      modelName: modelName ?? this.modelName,
      lastCheck: lastCheck ?? DateTime.now(),
    );
  }
}

/// Manages connectivity state and server health checks.
///
/// Two modes:
/// - Online: Remote backend API available → use 27B model via API
/// - Offline: No backend → use on-device 4B model via flutter_llama
class ConnectivityNotifier extends StateNotifier<ConnectionState> {
  Timer? _periodicTimer;
  final Dio _dio;

  ConnectivityNotifier()
      : _dio = Dio(BaseOptions(
          connectTimeout: Duration(
            milliseconds: AppConstants.healthCheckTimeout,
          ),
          receiveTimeout: Duration(
            milliseconds: AppConstants.healthCheckTimeout,
          ),
        )),
        super(ConnectionState.initial()) {
    // Initial check
    checkConnectivity();
    // Periodic check every 30 seconds
    _periodicTimer = Timer.periodic(
      Duration(seconds: AppConstants.connectivityCheckIntervalSeconds),
      (_) => checkConnectivity(),
    );
  }

  /// Check remote backend availability and set mode accordingly.
  Future<void> checkConnectivity() async {
    bool remoteAvailable = false;
    String remoteModelName = AppConstants.onlineModelName;

    // Check remote backend health
    try {
      final response = await _dio.get(
        '${AppConstants.remoteApiUrl}/api/v1/health',
      );
      remoteAvailable = response.statusCode == 200;
      if (remoteAvailable && response.data is Map) {
        final data = response.data as Map;
        final model = data['model'] as String? ?? '';
        if (model.isNotEmpty) {
          remoteModelName = _friendlyModelName(model);
        }
      }
    } catch (_) {
      remoteAvailable = false;
    }

    if (remoteAvailable) {
      // Online → use remote API
      state = state.copyWith(
        isOnline: true,
        useLocalLlama: false,
        activeEndpoint: AppConstants.remoteApiUrl,
        modelName: remoteModelName,
      );
    } else {
      // Offline → use on-device flutter_llama
      state = state.copyWith(
        isOnline: false,
        useLocalLlama: true,
        modelName: AppConstants.offlineModelName,
      );
    }
  }

  /// Extract a user-friendly model name from the full model ID.
  String _friendlyModelName(String model) {
    final name = model.split('/').last;
    if (name.contains('medgemma')) {
      return 'MedGemma ${_extractModelSize(model)}';
    }
    if (name.contains('gemma')) {
      final parts = name.replaceAll('-it', '').split('-');
      final version = parts.length > 1 ? parts[1] : '';
      final size = _extractModelSize(model);
      return 'Gemma $version $size'.trim();
    }
    return model;
  }

  /// Extract model size (e.g., "27B", "4B") from model ID.
  String _extractModelSize(String model) {
    final match = RegExp(r'(\d+)[bB]').firstMatch(model);
    return match != null ? '${match.group(1)}B' : '';
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    _dio.close();
    super.dispose();
  }
}

/// Riverpod provider for connectivity state.
final connectivityProvider =
    StateNotifierProvider<ConnectivityNotifier, ConnectionState>(
  (ref) => ConnectivityNotifier(),
);
