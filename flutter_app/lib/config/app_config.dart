import 'constants.dart';

/// Application configuration.
class AppConfig {
  AppConfig._();

  /// Primary remote server URL.
  static String remoteServerUrl = AppConstants.remoteApiUrl;

  /// Whether debug logging is enabled.
  static bool debugLogging = true;

  /// Maximum image size for EKG analysis (bytes).
  static const int maxImageSize = 10 * 1024 * 1024; // 10MB

  /// Supported image formats.
  static const List<String> supportedImageFormats = [
    'jpg',
    'jpeg',
    'png',
    'webp',
  ];

  /// Default language for UI.
  static const String defaultLanguage = 'tr';

  /// Default language for MedGemma prompts.
  static const String promptLanguage = 'en';
}
