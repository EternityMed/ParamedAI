import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/api_client.dart';
import '../../core/connectivity/connectivity_manager.dart';
import '../../core/inference/local_llama_service.dart';
import '../../core/inference/model_manager.dart';

/// Represents a triaged patient.
class TriagedPatient {
  final String id;
  final String patientId;
  final String category; // RED, YELLOW, GREEN, BLACK
  final String? notes;
  final Map<String, dynamic>? vitals;
  final int? gcs;
  final DateTime timestamp;

  TriagedPatient({
    String? id,
    required this.patientId,
    required this.category,
    this.notes,
    this.vitals,
    this.gcs,
    DateTime? timestamp,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();
}

/// State for the triage system.
class TriageState {
  final List<TriagedPatient> patients;
  final bool isClassifying;
  final String? error;

  const TriageState({
    this.patients = const [],
    this.isClassifying = false,
    this.error,
  });

  TriageState copyWith({
    List<TriagedPatient>? patients,
    bool? isClassifying,
    String? error,
  }) {
    return TriageState(
      patients: patients ?? this.patients,
      isClassifying: isClassifying ?? this.isClassifying,
      error: error,
    );
  }

  // Category counts
  int get redCount => patients.where((p) => p.category == 'RED').length;
  int get yellowCount => patients.where((p) => p.category == 'YELLOW').length;
  int get greenCount => patients.where((p) => p.category == 'GREEN').length;
  int get blackCount => patients.where((p) => p.category == 'BLACK').length;
  int get totalCount => patients.length;

  /// Returns patients sorted by priority (RED first, then YELLOW, GREEN, BLACK).
  List<TriagedPatient> get sortedPatients {
    final order = {'RED': 0, 'YELLOW': 1, 'GREEN': 2, 'BLACK': 3};
    return List.from(patients)
      ..sort((a, b) {
        final oa = order[a.category] ?? 4;
        final ob = order[b.category] ?? 4;
        if (oa != ob) return oa.compareTo(ob);
        return b.timestamp.compareTo(a.timestamp);
      });
  }
}

/// Triage state controller.
class TriageController extends StateNotifier<TriageState> {
  final ApiClient _apiClient;
  final Ref _ref;
  int _patientCounter = 0;

  TriageController(this._apiClient, this._ref) : super(const TriageState());

  /// Quick triage: assign category directly without AI classification.
  void quickTriage(String category, {String? notes}) {
    _patientCounter++;
    final patient = TriagedPatient(
      patientId: 'H-${_patientCounter.toString().padLeft(3, '0')}',
      category: category,
      notes: notes,
    );

    state = state.copyWith(
      patients: [...state.patients, patient],
    );
  }

  /// AI-assisted triage using the backend.
  Future<void> classifyPatient(Map<String, dynamic> patientData) async {
    state = state.copyWith(isClassifying: true, error: null);

    try {
      final response = await _apiClient.triageClassify(
        patientData: patientData,
      );

      _patientCounter++;
      final patient = TriagedPatient(
        patientId: 'H-${_patientCounter.toString().padLeft(3, '0')}',
        category: (response['category'] as String? ?? 'GREEN').toUpperCase(),
        notes: response['notes'] as String?,
        vitals: response['vitals'] as Map<String, dynamic>?,
        gcs: response['gcs'] as int?,
      );

      state = state.copyWith(
        patients: [...state.patients, patient],
        isClassifying: false,
      );
    } catch (e) {
      state = state.copyWith(
        isClassifying: false,
        error: e.toString(),
      );
    }
  }

  /// AI-assisted START triage: sends structured assessment to MedGemma.
  /// Works both online (27B) and offline (4B on-device).
  /// Offline uses chatRaw() — no GenUI system prompt, maxTokens=128 for speed.
  /// Falls back to deterministic START if AI fails.
  /// AI-assisted START triage.
  /// [selectedCategory] — if user pre-selected a color, use it; otherwise AI decides.
  Future<void> aiTriage({
    required bool canWalk,
    required bool hasBreathing,
    required bool hasPulse,
    required bool followsCommands,
    String? notes,
  }) async {
    state = state.copyWith(isClassifying: true, error: null);

    // Deterministic START result as fallback
    final startCategory = _startClassify(
      canWalk: canWalk,
      hasBreathing: hasBreathing,
      hasPulse: hasPulse,
      followsCommands: followsCommands,
    );

    // Build prompt — concise, Turkish, no example data
    final notesLineEn = (notes != null && notes.isNotEmpty) ? '\nAdditional notes: $notes' : '';
    final prompt = 'You are an emergency medicine physician performing START field triage.\n'
        'Classify the patient into one category based on their assessment.\n\n'
        'Categories:\n'
        '- GREEN: Minor injuries, can walk (walking wounded)\n'
        '- YELLOW: Delayed, serious but stable\n'
        '- RED: Immediate, life-threatening, needs urgent care\n'
        '- BLACK: Deceased or expectant, no signs of life\n\n'
        'Return ONLY JSON: {"category":"COLOR","reasoning":"short reason"}\n\n'
        'Patient:\n'
        'Can walk: ${canWalk ? "Yes" : "No"}\n'
        'Breathing: ${hasBreathing ? "Yes" : "No"}\n'
        'Radial pulse: ${hasPulse ? "Yes" : "No"}\n'
        'Follows commands: ${followsCommands ? "Yes" : "No"}'
        '$notesLineEn';

    dev.log('=== TRIAGE PROMPT ===\n$prompt\n=== END PROMPT ===', name: 'ParaMed.Triage');

    try {
      final connState = _ref.read(connectivityProvider);
      String aiResponse;

      if (connState.useLocalLlama) {
        // Offline → on-device MedGemma 4B (no system prompt, 128 max tokens)
        final llama = _ref.read(localLlamaProvider);
        if (!llama.isLoaded) {
          final manager = _ref.read(modelManagerProvider.notifier);
          final downloaded = await manager.isModelDownloaded();
          if (!downloaded) throw Exception('Model not downloaded');
          final modelPath = await manager.getModelPath();
          await llama.loadModel(modelPath);
        }
        aiResponse = await llama.chatRaw(prompt: prompt, maxTokens: 128);
      } else {
        // Online → remote backend AI triage (MedGemma 27B, no GenUI prompt)
        final result = await _apiClient.triageAiClassify(
          canWalk: canWalk,
          hasBreathing: hasBreathing,
          hasPulse: hasPulse,
          followsCommands: followsCommands,
          notes: notes,
        );
        aiResponse = '{"category":"${result['category']}","reasoning":"${result['reasoning']}"}';
      }

      dev.log('=== TRIAGE RAW RESPONSE ===\n$aiResponse\n=== END RAW ===', name: 'ParaMed.Triage');

      // Parse AI response
      final parsed = _parseAiTriageResponse(aiResponse, startCategory);

      final finalCategory = parsed['category']!;

      dev.log('=== TRIAGE PARSED ===\ncategory: $finalCategory (ai: ${parsed['category']}, start: $startCategory)\nreasoning: ${parsed['reasoning']}\n=== END PARSED ===', name: 'ParaMed.Triage');

      _patientCounter++;
      final patient = TriagedPatient(
        patientId: 'H-${_patientCounter.toString().padLeft(3, '0')}',
        category: finalCategory,
        notes: parsed['reasoning'],
      );

      state = state.copyWith(
        patients: [...state.patients, patient],
        isClassifying: false,
      );
    } catch (e) {
      dev.log('=== TRIAGE ERROR ===\n$e\n=== END ERROR ===', name: 'ParaMed.Triage');
      // Fallback: deterministic START
      _patientCounter++;
      final patient = TriagedPatient(
        patientId: 'H-${_patientCounter.toString().padLeft(3, '0')}',
        category: startCategory,
        notes: notes != null && notes.isNotEmpty
            ? '$notes (START algorithm)'
            : 'Classified by START algorithm',
      );

      state = state.copyWith(
        patients: [...state.patients, patient],
        isClassifying: false,
        error: null,
      );
    }
  }

  /// Deterministic START triage classification.
  String _startClassify({
    required bool canWalk,
    required bool hasBreathing,
    required bool hasPulse,
    required bool followsCommands,
  }) {
    if (canWalk) return 'GREEN';
    if (!hasBreathing) return 'BLACK';
    if (!hasPulse || !followsCommands) return 'RED';
    return 'YELLOW';
  }

  /// Parse AI JSON response, fallback to START category if parsing fails.
  Map<String, String> _parseAiTriageResponse(
    String response,
    String fallbackCategory,
  ) {
    try {
      // Try to extract JSON from response
      final jsonMatch = RegExp(r'\{[^}]*"category"[^}]*\}').firstMatch(response);
      if (jsonMatch != null) {
        final parsed = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
        final category = (parsed['category'] as String?)?.toUpperCase() ?? fallbackCategory;
        final reasoning = parsed['reasoning'] as String? ?? '';
        // Validate category
        if (['RED', 'YELLOW', 'GREEN', 'BLACK'].contains(category)) {
          return {'category': category, 'reasoning': reasoning};
        }
      }
    } catch (_) {
      // parsing failed, use fallback
    }
    return {'category': fallbackCategory, 'reasoning': response};
  }

  /// Remove a patient from the triage list.
  void removePatient(String id) {
    state = state.copyWith(
      patients: state.patients.where((p) => p.id != id).toList(),
    );
  }

  /// Clear all patients.
  void clearAll() {
    _patientCounter = 0;
    state = const TriageState();
  }
}

/// Provider for triage controller.
final triageControllerProvider =
    StateNotifierProvider<TriageController, TriageState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TriageController(apiClient, ref);
});
