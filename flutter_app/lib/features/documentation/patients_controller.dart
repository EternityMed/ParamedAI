import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/api_client.dart';
import '../../core/connectivity/connectivity_manager.dart';
import '../../core/inference/local_llama_service.dart';
import '../../core/inference/model_manager.dart';

const _prefsKey = 'paramed_patients';

/// Dispatch result from EMSGemmaApp.
class DispatchResult {
  final String triageLevel;
  final int urgencyScore;
  final String clinicalReasoning;
  final String primaryHospital;
  final String hospitalReasoning;
  final String primaryTeam;
  final double etaMin;
  final String resourceReasoning;
  final double pipelineTimeSec;

  const DispatchResult({
    required this.triageLevel,
    required this.urgencyScore,
    required this.clinicalReasoning,
    required this.primaryHospital,
    required this.hospitalReasoning,
    required this.primaryTeam,
    required this.etaMin,
    required this.resourceReasoning,
    required this.pipelineTimeSec,
  });

  factory DispatchResult.fromJson(Map<String, dynamic> json) {
    final triage = json['triage'] as Map<String, dynamic>? ?? {};
    final hospital = json['hospital'] as Map<String, dynamic>? ?? {};
    final resource = json['resource'] as Map<String, dynamic>? ?? {};
    return DispatchResult(
      triageLevel: triage['triage_level'] as String? ?? 'UNKNOWN',
      urgencyScore: triage['urgency_score'] as int? ?? 0,
      clinicalReasoning: triage['clinical_reasoning'] as String? ?? '',
      primaryHospital: hospital['primary_hospital'] as String? ?? 'N/A',
      hospitalReasoning: hospital['reasoning'] as String? ?? '',
      primaryTeam: resource['primary_team'] as String? ?? 'N/A',
      etaMin: (resource['primary_eta_min'] as num?)?.toDouble() ?? 0,
      resourceReasoning: resource['reasoning'] as String? ?? '',
      pipelineTimeSec: (json['pipeline_time_sec'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// A saved patient record with voice transcription and AI documentation.
class PatientRecord {
  final String id;
  final String transcription;
  final String documentation;
  final DateTime createdAt;
  final DispatchResult? dispatch;

  PatientRecord({
    String? id,
    required this.transcription,
    required this.documentation,
    DateTime? createdAt,
    this.dispatch,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'transcription': transcription,
        'documentation': documentation,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PatientRecord.fromJson(Map<String, dynamic> json) => PatientRecord(
        id: json['id'] as String,
        transcription: json['transcription'] as String,
        documentation: json['documentation'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  PatientRecord copyWith({DispatchResult? dispatch}) => PatientRecord(
        id: id,
        transcription: transcription,
        documentation: documentation,
        createdAt: createdAt,
        dispatch: dispatch ?? this.dispatch,
      );
}

/// State for the Patients screen.
class PatientsState {
  final List<PatientRecord> patients;
  final String currentTranscription;
  final String? currentDocumentation;
  final bool isGenerating;
  final bool isDispatching;
  final DispatchResult? currentDispatch;
  final String? error;

  const PatientsState({
    this.patients = const [],
    this.currentTranscription = '',
    this.currentDocumentation,
    this.isGenerating = false,
    this.isDispatching = false,
    this.currentDispatch,
    this.error,
  });

  PatientsState copyWith({
    List<PatientRecord>? patients,
    String? currentTranscription,
    String? currentDocumentation,
    bool clearDocumentation = false,
    bool? isGenerating,
    bool? isDispatching,
    DispatchResult? currentDispatch,
    bool clearDispatch = false,
    String? error,
    bool clearError = false,
  }) {
    return PatientsState(
      patients: patients ?? this.patients,
      currentTranscription: currentTranscription ?? this.currentTranscription,
      currentDocumentation:
          clearDocumentation ? null : (currentDocumentation ?? this.currentDocumentation),
      isGenerating: isGenerating ?? this.isGenerating,
      isDispatching: isDispatching ?? this.isDispatching,
      currentDispatch: clearDispatch ? null : (currentDispatch ?? this.currentDispatch),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Controller for patient records — voice transcription, AI documentation, local storage.
class PatientsController extends StateNotifier<PatientsState> {
  final ApiClient _apiClient;
  final Ref _ref;

  PatientsController(this._apiClient, this._ref) : super(const PatientsState()) {
    _loadPatients();
  }

  // ── Storage ──────────────────────────────────────────────────────────────

  Future<void> _loadPatients() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null) {
        final list = jsonDecode(jsonStr) as List;
        final patients = list
            .map((j) => PatientRecord.fromJson(j as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        state = state.copyWith(patients: patients);
      }
    } catch (e) {
      dev.log('Failed to load patients: $e', name: 'Patients');
    }
  }

  Future<void> _savePatients() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = state.patients.map((p) => p.toJson()).toList();
      await prefs.setString(_prefsKey, jsonEncode(jsonList));
    } catch (e) {
      dev.log('Failed to save patients: $e', name: 'Patients');
    }
  }

  // ── Transcription ────────────────────────────────────────────────────────

  void updateTranscription(String text) {
    state = state.copyWith(currentTranscription: text, clearError: true);
  }

  void appendTranscription(String text) {
    final current = state.currentTranscription;
    final updated = current.isEmpty ? text : '$current $text';
    state = state.copyWith(currentTranscription: updated, clearError: true);
  }

  // ── AI Documentation ─────────────────────────────────────────────────────

  Future<void> generateDocumentation() async {
    if (state.currentTranscription.trim().isEmpty) return;

    state = state.copyWith(
      isGenerating: true,
      clearError: true,
      clearDocumentation: true,
      clearDispatch: true,
    );

    final prompt =
        'You are an emergency medicine physician. Convert the following voice transcription '
        'into a structured prehospital medical documentation.\n\n'
        'Include these sections if information is available:\n'
        '- Chief Complaint\n'
        '- History of Present Illness (HPI)\n'
        '- Vital Signs\n'
        '- Physical Examination\n'
        '- Assessment\n'
        '- Interventions / Plan\n\n'
        'If information for a section is not mentioned, skip that section.\n'
        'Be concise and use medical terminology.\n\n'
        'Voice transcription:\n${state.currentTranscription}';

    try {
      final connState = _ref.read(connectivityProvider);
      String documentation;

      if (connState.useLocalLlama) {
        // Offline → on-device MedGemma 4B
        final llama = _ref.read(localLlamaProvider);
        if (!llama.isLoaded) {
          final manager = _ref.read(modelManagerProvider.notifier);
          final downloaded = await manager.isModelDownloaded();
          if (!downloaded) throw Exception('Model not downloaded');
          final modelPath = await manager.getModelPath();
          await llama.loadModel(modelPath);
        }
        documentation = await llama.chatRaw(prompt: prompt, maxTokens: 512);
      } else {
        // Online → remote backend (MedGemma 27B)
        final result = await _apiClient.generateDocumentation(
          transcription: state.currentTranscription,
        );
        documentation = result['documentation'] as String? ?? '';
      }

      state = state.copyWith(
        currentDocumentation: _cleanMarkdown(documentation),
        isGenerating: false,
      );
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        error: e.toString(),
      );
    }
  }

  /// Strip markdown formatting (bold, headers) from LLM output.
  String _cleanMarkdown(String text) {
    return text
        .replaceAll('**', '')
        .replaceAll(RegExp(r'^#{1,3}\s+', multiLine: true), '');
  }

  // ── Dispatch — EMSGemmaApp integration ──────────────────────────────────

  Future<void> requestDispatch() async {
    final doc = state.currentDocumentation;
    if (doc == null || doc.trim().isEmpty) return;

    state = state.copyWith(isDispatching: true, clearError: true);

    try {
      final result = await _apiClient.requestDispatch(
        complaint: doc,
        additional: state.currentTranscription,
      );
      final dispatch = DispatchResult.fromJson(result);
      state = state.copyWith(
        currentDispatch: dispatch,
        isDispatching: false,
      );
    } catch (e) {
      state = state.copyWith(
        isDispatching: false,
        error: 'Dispatch failed: $e',
      );
    }
  }

  // ── Patient CRUD ─────────────────────────────────────────────────────────

  Future<void> saveCurrentPatient() async {
    if (state.currentTranscription.trim().isEmpty) return;

    final patient = PatientRecord(
      transcription: state.currentTranscription,
      documentation: state.currentDocumentation ?? state.currentTranscription,
      dispatch: state.currentDispatch,
    );

    state = state.copyWith(
      patients: [patient, ...state.patients],
      currentTranscription: '',
      clearDocumentation: true,
      clearDispatch: true,
    );
    await _savePatients();
  }

  Future<void> deletePatient(String id) async {
    state = state.copyWith(
      patients: state.patients.where((p) => p.id != id).toList(),
    );
    await _savePatients();
  }

  void clearCurrent() {
    state = state.copyWith(
      currentTranscription: '',
      clearDocumentation: true,
      clearDispatch: true,
      clearError: true,
    );
  }
}

/// Provider for patients controller.
final patientsControllerProvider =
    StateNotifierProvider<PatientsController, PatientsState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PatientsController(apiClient, ref);
});

/// Navigation event — triggers tab switch + sends context to chat.
class ChatNavigationEvent {
  final String message;
  final DateTime timestamp;
  ChatNavigationEvent(this.message) : timestamp = DateTime.now();
}

/// Provider to pass patient context to the Assistant chat tab.
final chatNavigationProvider = StateProvider<ChatNavigationEvent?>((ref) => null);
