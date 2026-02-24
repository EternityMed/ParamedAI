/// Static API endpoint path constants.
class ApiEndpoints {
  ApiEndpoints._();

  static const String basePrefix = '/api/v1';

  // Chat
  static const String chat = '$basePrefix/chat';
  static const String chatStream = '$basePrefix/chat/stream';

  // Audio
  static const String transcribe = '$basePrefix/transcribe';

  // Image analysis
  static const String analyzeImage = '$basePrefix/analyze/image';

  // Triage
  static const String triageClassify = '$basePrefix/triage/classify';
  static const String triageAiClassify = '$basePrefix/triage/ai-classify';


  // Patients
  static const String patientsDocument = '$basePrefix/patients/document';

  // Drug calculation
  static const String drugCalculate = '$basePrefix/drug/calculate';

  // Health check
  static const String health = '$basePrefix/health';
}
