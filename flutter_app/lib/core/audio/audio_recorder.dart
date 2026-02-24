import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State for the audio recorder.
class AudioRecorderState {
  final bool isRecording;
  final Duration duration;
  final String? filePath;
  final Uint8List? audioData;

  const AudioRecorderState({
    this.isRecording = false,
    this.duration = Duration.zero,
    this.filePath,
    this.audioData,
  });

  AudioRecorderState copyWith({
    bool? isRecording,
    Duration? duration,
    String? filePath,
    Uint8List? audioData,
  }) {
    return AudioRecorderState(
      isRecording: isRecording ?? this.isRecording,
      duration: duration ?? this.duration,
      filePath: filePath ?? this.filePath,
      audioData: audioData ?? this.audioData,
    );
  }
}

/// Audio recorder service using the record package.
class AudioRecorderNotifier extends StateNotifier<AudioRecorderState> {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _durationTimer;

  AudioRecorderNotifier() : super(const AudioRecorderState());

  /// Start recording audio.
  Future<void> startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw Exception('Mikrofon izni verilmedi.');
    }

    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/paramed_recording_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: filePath,
    );

    state = AudioRecorderState(
      isRecording: true,
      duration: Duration.zero,
      filePath: filePath,
    );

    // Track recording duration
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(
        duration: state.duration + const Duration(seconds: 1),
      );
    });
  }

  /// Stop recording and return audio data.
  Future<String?> stopRecording() async {
    _durationTimer?.cancel();

    final path = await _recorder.stop();

    state = state.copyWith(
      isRecording: false,
      filePath: path,
    );

    return path;
  }

  /// Cancel recording without saving.
  Future<void> cancelRecording() async {
    _durationTimer?.cancel();
    await _recorder.stop();
    state = const AudioRecorderState();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }
}

/// Riverpod provider for audio recorder.
final audioRecorderProvider =
    StateNotifierProvider<AudioRecorderNotifier, AudioRecorderState>(
  (ref) => AudioRecorderNotifier(),
);
