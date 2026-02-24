import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

const _tag = '[DeviceSTT]';

/// State for speech-to-text recognition.
class SpeechState {
  final bool isListening;
  final String recognizedText;
  final double confidence;
  final bool isAvailable;

  const SpeechState({
    this.isListening = false,
    this.recognizedText = '',
    this.confidence = 0.0,
    this.isAvailable = false,
  });

  SpeechState copyWith({
    bool? isListening,
    String? recognizedText,
    double? confidence,
    bool? isAvailable,
  }) {
    return SpeechState(
      isListening: isListening ?? this.isListening,
      recognizedText: recognizedText ?? this.recognizedText,
      confidence: confidence ?? this.confidence,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}

/// Speech-to-text service using the speech_to_text package.
class SpeechToTextNotifier extends StateNotifier<SpeechState> {
  final SpeechToText _speech = SpeechToText();
  final Completer<void> _initCompleter = Completer<void>();

  /// Completes when initialization is done (regardless of success/failure).
  Future<void> get initialized => _initCompleter.future;

  SpeechToTextNotifier() : super(const SpeechState()) {
    debugPrint('$_tag created, initializing...');
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final available = await _speech.initialize(
        onStatus: _onStatus,
        onError: (error) {
          debugPrint('$_tag onError: ${error.errorMsg} '
              '(permanent=${error.permanent})');
          state = state.copyWith(isListening: false);
        },
      );
      state = state.copyWith(isAvailable: available);
      debugPrint('$_tag initialize done — isAvailable=$available');

      if (available) {
        final locales = await _speech.locales();
        final enLocale = locales
            .where((l) => l.localeId.startsWith('en'))
            .map((l) => l.localeId)
            .toList();
        debugPrint('$_tag available English locales: $enLocale');
        debugPrint('$_tag total locales: ${locales.length}');
      }
    } catch (e, st) {
      debugPrint('$_tag initialize FAILED: $e');
      debugPrint('$_tag stack trace: $st');
      state = state.copyWith(isAvailable: false);
    } finally {
      _initCompleter.complete();
    }
  }

  void _onStatus(String status) {
    debugPrint('$_tag onStatus: "$status"');
    if (status == 'notListening' || status == 'done') {
      state = state.copyWith(isListening: false);
    }
  }

  /// Start listening for speech.
  Future<void> startListening() async {
    debugPrint('$_tag startListening() — isAvailable=${state.isAvailable}');
    if (!state.isAvailable) {
      debugPrint('$_tag startListening() ABORTED — not available');
      return;
    }

    state = state.copyWith(
      isListening: true,
      recognizedText: '',
      confidence: 0.0,
    );

    try {
      await _speech.listen(
        onResult: _onResult,
        localeId: 'en_US',
        listenMode: ListenMode.dictation,
        cancelOnError: true,
        partialResults: true,
      );
      debugPrint('$_tag speech.listen() started OK');
    } catch (e, st) {
      debugPrint('$_tag speech.listen() FAILED: $e');
      debugPrint('$_tag stack trace: $st');
      state = state.copyWith(isListening: false);
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    debugPrint('$_tag onResult: "${result.recognizedWords}" '
        '(final=${result.finalResult}, confidence=${result.confidence})');
    state = state.copyWith(
      recognizedText: result.recognizedWords,
      confidence: result.confidence,
      isListening: !result.finalResult,
    );
  }

  /// Stop listening.
  Future<void> stopListening() async {
    debugPrint('$_tag stopListening() — '
        'currentText="${state.recognizedText}"');
    await _speech.stop();
    state = state.copyWith(isListening: false);
    debugPrint('$_tag stopListening() DONE — '
        'finalText="${state.recognizedText}"');
  }

  /// Clear recognized text.
  void clearText() {
    debugPrint('$_tag clearText()');
    state = state.copyWith(recognizedText: '', confidence: 0.0);
  }

  @override
  void dispose() {
    debugPrint('$_tag dispose()');
    _speech.stop();
    super.dispose();
  }
}

/// Riverpod provider for speech-to-text.
final speechToTextProvider =
    StateNotifierProvider<SpeechToTextNotifier, SpeechState>(
  (ref) => SpeechToTextNotifier(),
);
