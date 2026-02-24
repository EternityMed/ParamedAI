import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'medasr_service.dart';
import 'speech_to_text_service.dart';

const _tag = '[STTRouter]';

/// Unified STT state combining both engines.
class UnifiedSttState {
  final bool isListening;
  final String recognizedText;
  final String activeEngine; // "medasr" or "device"

  const UnifiedSttState({
    this.isListening = false,
    this.recognizedText = '',
    this.activeEngine = 'device',
  });

  UnifiedSttState copyWith({
    bool? isListening,
    String? recognizedText,
    String? activeEngine,
  }) {
    return UnifiedSttState(
      isListening: isListening ?? this.isListening,
      recognizedText: recognizedText ?? this.recognizedText,
      activeEngine: activeEngine ?? this.activeEngine,
    );
  }
}

/// Routes between MedASR (English medical) and device STT (Turkish/other)
/// based on device locale. Awaits engine initialization before routing.
class STTRouterNotifier extends StateNotifier<UnifiedSttState> {
  final Ref _ref;

  STTRouterNotifier(this._ref) : super(const UnifiedSttState()) {
    debugPrint('$_tag created');
  }

  Future<void> startListening() async {
    debugPrint('$_tag startListening() called');

    // Ensure both engines finish initializing before we decide which to use.
    // This prevents the race condition where neither engine is ready yet.
    debugPrint('$_tag awaiting engine initialization...');
    await Future.wait([
      _ref.read(medAsrProvider.notifier).initialized,
      _ref.read(speechToTextProvider.notifier).initialized,
    ]);
    debugPrint('$_tag engines initialized');

    // Now check which engine to use
    final shouldUseMedAsr = _checkShouldUseMedAsr();

    if (shouldUseMedAsr) {
      debugPrint('$_tag → routing to MedASR');
      state = state.copyWith(
        isListening: true,
        recognizedText: '',
        activeEngine: 'medasr',
      );
      await _ref.read(medAsrProvider.notifier).startListening();
      // If MedASR failed to start (e.g. permission), revert state
      if (!_ref.read(medAsrProvider).isListening) {
        debugPrint('$_tag MedASR failed to start, falling back to device STT');
        state = state.copyWith(activeEngine: 'device');
        await _ref.read(speechToTextProvider.notifier).startListening();
        if (!_ref.read(speechToTextProvider).isListening) {
          debugPrint('$_tag device STT also failed to start');
          state = state.copyWith(isListening: false);
          return;
        }
      }
      debugPrint('$_tag MedASR startListening OK');
    } else {
      debugPrint('$_tag → routing to device STT');
      final deviceState = _ref.read(speechToTextProvider);
      debugPrint('$_tag device STT isAvailable=${deviceState.isAvailable}');

      if (!deviceState.isAvailable) {
        debugPrint('$_tag device STT not available, trying MedASR as fallback');
        final medAsrReady = _ref.read(medAsrProvider).isReady;
        if (medAsrReady) {
          debugPrint('$_tag → fallback to MedASR');
          state = state.copyWith(
            isListening: true,
            recognizedText: '',
            activeEngine: 'medasr',
          );
          await _ref.read(medAsrProvider.notifier).startListening();
          if (!_ref.read(medAsrProvider).isListening) {
            debugPrint('$_tag MedASR fallback also failed');
            state = state.copyWith(isListening: false);
          }
          return;
        }
        debugPrint('$_tag NO engine available!');
        state = state.copyWith(isListening: false);
        return;
      }

      state = state.copyWith(
        isListening: true,
        recognizedText: '',
        activeEngine: 'device',
      );
      await _ref.read(speechToTextProvider.notifier).startListening();
      debugPrint('$_tag device STT startListening returned');
    }
  }

  bool _checkShouldUseMedAsr() {
    if (kIsWeb) {
      debugPrint('$_tag _shouldUseMedAsr: false (web platform)');
      return false;
    }
    final locale = Platform.localeName;
    final isEnglish = locale.startsWith('en');
    final medAsrReady = _ref.read(medAsrProvider).isReady;
    debugPrint('$_tag _shouldUseMedAsr: locale="$locale", '
        'isEnglish=$isEnglish, medAsrReady=$medAsrReady '
        '→ ${isEnglish && medAsrReady}');
    return isEnglish && medAsrReady;
  }

  Future<void> stopListening() async {
    debugPrint('$_tag stopListening() called — '
        'activeEngine=${state.activeEngine}');

    if (state.activeEngine == 'medasr') {
      final text =
          await _ref.read(medAsrProvider.notifier).stopListening();
      debugPrint('$_tag MedASR returned text: "$text"');
      state = state.copyWith(isListening: false, recognizedText: text);
    } else {
      await _ref.read(speechToTextProvider.notifier).stopListening();
      final deviceState = _ref.read(speechToTextProvider);
      final text = deviceState.recognizedText;
      debugPrint('$_tag device STT returned text: "$text" '
          '(confidence=${deviceState.confidence}, '
          'isListening=${deviceState.isListening})');
      state = state.copyWith(isListening: false, recognizedText: text);
    }

    debugPrint('$_tag stopListening() DONE — '
        'recognizedText="${state.recognizedText}"');
  }

  void clearText() {
    debugPrint('$_tag clearText()');
    state = state.copyWith(recognizedText: '');
  }
}

/// Unified STT provider — auto-routes MedASR vs device STT by locale.
final activeSTTProvider =
    StateNotifierProvider<STTRouterNotifier, UnifiedSttState>(
  (ref) => STTRouterNotifier(ref),
);
