import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connectivity_manager.dart';

/// Provides the active API base URL based on the current connection state.
class ModelRouter {
  final ConnectionState connectionState;

  ModelRouter(this.connectionState);

  /// Returns the active API base URL.
  String get baseUrl => connectionState.activeEndpoint;

  /// Returns true if any backend is available (online or on-device).
  bool get isAvailable =>
      connectionState.isOnline || connectionState.useLocalLlama;

  /// Returns the current model display name.
  String get modelDisplayName => connectionState.modelName;

  /// Returns a short status label for the UI.
  String get statusLabel {
    if (connectionState.isOnline) return 'Online (27B)';
    if (connectionState.useLocalLlama) return 'Device (4B)';
    return 'Offline';
  }
}

/// Riverpod provider for model router.
final modelRouterProvider = Provider<ModelRouter>((ref) {
  final state = ref.watch(connectivityProvider);
  return ModelRouter(state);
});
