import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

/// Application-wide constants for ParaMed AI.
class AppConstants {
  AppConstants._();

  // App info
  static const String appName = 'ParaMed AI';
  static const String appVersion = '1.0.0';
  static const String appDescription = '112 EMS AI Assistant';

  // API URLs — Remote backend
  // Local dev: localhost, Prod: Render.com deployed URLs
  static const bool _useLocalDev = false; // Set true for local development

  static String get remoteApiUrl {
    if (_useLocalDev) {
      if (kIsWeb) return 'http://localhost:8080';
      if (Platform.isAndroid) return 'http://10.0.2.2:8080';
      return 'http://localhost:8080';
    }
    return 'https://paramed-ai-backend.onrender.com';
  }

  // EMSGemmaApp — Dispatch platform for hospital routing & ambulance assignment
  static String get dispatchApiUrl {
    if (_useLocalDev) {
      if (kIsWeb) return 'http://localhost:8000';
      if (Platform.isAndroid) return 'http://10.0.2.2:8000';
      return 'http://localhost:8000';
    }
    return 'https://gemma112-dispatch.onrender.com';
  }

  // Timeouts (milliseconds)
  static const int connectionTimeout = 10000;
  static const int receiveTimeout = 60000;
  static const int sendTimeout = 30000;
  static const int healthCheckTimeout = 5000;

  // Connectivity
  static const int connectivityCheckIntervalSeconds = 30;

  // Model display names
  static const String onlineModelName = 'MedGemma 27B';
  static const String offlineModelName = 'MedGemma 4B (Device)';

  // On-device GGUF model settings
  static const String ggufModelFileName = 'medgemma-4b-it-Q4_K_M.gguf';
  static const String ggufModelSizeLabel = '2.64 GB';
  static const String ggufModelUrl =
      'https://huggingface.co/unsloth/medgemma-4b-it-GGUF/resolve/main/medgemma-4b-it-Q4_K_M.gguf';

  // LLM inference parameters
  static const int llamaThreads = 4;
  static const int llamaContextSize = 2048;
  // iOS: all layers on Metal GPU, Android: CPU-only (Vulkan crashes on Adreno)
  static int get llamaGpuLayers => (!kIsWeb && Platform.isIOS) ? 999 : 0;
  static const int llamaMaxTokens = 1024;

  // Audio
  static const int maxRecordingDurationSeconds = 120;
  static const int sampleRate = 16000;

  // MedASR on-device medical speech recognition
  static const String medAsrAssetDir = 'assets/medasr';
  static const String medAsrModelFile = 'model.int8.onnx';
  static const String medAsrTokensFile = 'tokens.txt';
  static const String medAsrVadFile = 'silero_vad.onnx';
  static const int medAsrSampleRate = 16000;
  static const int medAsrNumThreads = 2;

  // Chat
  static const int maxChatHistoryLength = 100;
  static const int maxMessageLength = 4096;

  // Triage
  static const List<String> triageCategories = [
    'RED',
    'YELLOW',
    'GREEN',
    'BLACK',
  ];
}
