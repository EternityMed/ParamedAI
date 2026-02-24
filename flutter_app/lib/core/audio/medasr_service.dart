import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import '../../config/constants.dart';

const _tag = '[MedASR]';

/// State for MedASR on-device medical speech recognition.
class MedAsrState {
  final bool isReady;
  final bool isListening;
  final String recognizedText;
  final String partialText;

  const MedAsrState({
    this.isReady = false,
    this.isListening = false,
    this.recognizedText = '',
    this.partialText = '',
  });

  MedAsrState copyWith({
    bool? isReady,
    bool? isListening,
    String? recognizedText,
    String? partialText,
  }) {
    return MedAsrState(
      isReady: isReady ?? this.isReady,
      isListening: isListening ?? this.isListening,
      recognizedText: recognizedText ?? this.recognizedText,
      partialText: partialText ?? this.partialText,
    );
  }
}

/// MedASR service using sherpa-onnx offline recognizer.
///
/// Uses push-to-talk pattern: accumulates all audio during listening,
/// then recognizes on stop. VAD is used for real-time partial results
/// when available, with direct recognition as fallback.
class MedAsrService extends StateNotifier<MedAsrState> {
  sherpa_onnx.OfflineRecognizer? _recognizer;
  sherpa_onnx.VoiceActivityDetector? _vad;
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioSub;

  // VAD buffer for real-time segmentation
  final List<double> _vadBuffer = [];
  static const int _vadWindowSize = 512; // Silero VAD window size for 16kHz

  // Full recording buffer for direct recognition fallback
  final List<double> _fullRecording = [];

  final Completer<void> _initCompleter = Completer<void>();

  /// Completes when initialization is done (regardless of success/failure).
  Future<void> get initialized => _initCompleter.future;

  // Logging counters
  int _audioChunkCount = 0;
  int _totalSamplesReceived = 0;
  int _vadSegmentCount = 0;
  double _peakAmplitude = 0.0;

  MedAsrService() : super(const MedAsrState());

  /// Initialize: extract assets and create recognizer + VAD.
  Future<void> initialize() async {
    debugPrint('$_tag initialize() started');
    try {
      sherpa_onnx.initBindings();
      debugPrint('$_tag initBindings() OK');

      final docDir = await getApplicationDocumentsDirectory();
      final medAsrDir = '${docDir.path}/medasr';
      await Directory(medAsrDir).create(recursive: true);
      debugPrint('$_tag target dir: $medAsrDir');

      debugPrint('$_tag extracting model asset...');
      final modelPath = await _extractAsset(
        AppConstants.medAsrModelFile,
        medAsrDir,
      );
      debugPrint('$_tag model extracted: $modelPath');

      debugPrint('$_tag extracting tokens asset...');
      final tokensPath = await _extractAsset(
        AppConstants.medAsrTokensFile,
        medAsrDir,
      );
      debugPrint('$_tag tokens extracted: $tokensPath');

      debugPrint('$_tag extracting VAD model asset...');
      final vadModelPath = await _extractAsset(
        AppConstants.medAsrVadFile,
        medAsrDir,
      );
      debugPrint('$_tag VAD model extracted: $vadModelPath');

      // Verify files exist and log sizes
      final modelFile = File(modelPath);
      final tokensFile = File(tokensPath);
      final vadFile = File(vadModelPath);
      debugPrint('$_tag model size=${await modelFile.length()} bytes');
      debugPrint('$_tag tokens size=${await tokensFile.length()} bytes');
      debugPrint('$_tag VAD size=${await vadFile.length()} bytes');

      // Create offline recognizer with MedASR-specific config
      debugPrint('$_tag creating OfflineRecognizer...');
      final config = sherpa_onnx.OfflineRecognizerConfig(
        model: sherpa_onnx.OfflineModelConfig(
          medasr: sherpa_onnx.OfflineMedAsrCtcModelConfig(
            model: modelPath,
          ),
          tokens: tokensPath,
          numThreads: AppConstants.medAsrNumThreads,
          provider: 'cpu',
          debug: true,
        ),
        decodingMethod: 'greedy_search',
      );
      _recognizer = sherpa_onnx.OfflineRecognizer(config);
      debugPrint('$_tag OfflineRecognizer created OK');

      // Create Silero VAD for real-time speech segmentation
      debugPrint('$_tag creating VoiceActivityDetector (threshold=0.3)...');
      final vadConfig = sherpa_onnx.VadModelConfig(
        sileroVad: sherpa_onnx.SileroVadModelConfig(
          model: vadModelPath,
          threshold: 0.3, // Lower threshold for better sensitivity
          minSpeechDuration: 0.15,
          minSilenceDuration: 0.3,
          maxSpeechDuration: 30.0,
          windowSize: 512,
        ),
        sampleRate: AppConstants.medAsrSampleRate,
        numThreads: 1,
        provider: 'cpu',
        debug: false,
      );
      _vad = sherpa_onnx.VoiceActivityDetector(
        config: vadConfig,
        bufferSizeInSeconds: 60,
      );
      debugPrint('$_tag VoiceActivityDetector created OK');

      state = state.copyWith(isReady: true);
      debugPrint('$_tag initialize() DONE — isReady=true');
    } catch (e, st) {
      debugPrint('$_tag initialize() FAILED: $e');
      debugPrint('$_tag stack trace: $st');
      state = state.copyWith(isReady: false);
    } finally {
      _initCompleter.complete();
    }
  }

  /// Start listening: capture mic audio, feed through VAD, recognize segments.
  Future<void> startListening() async {
    debugPrint('$_tag startListening() called — '
        'isReady=${state.isReady}, recognizer=${_recognizer != null}');
    if (!state.isReady || _recognizer == null) {
      debugPrint('$_tag startListening() ABORTED — not ready');
      return;
    }

    _audioChunkCount = 0;
    _totalSamplesReceived = 0;
    _vadSegmentCount = 0;
    _peakAmplitude = 0.0;

    state = state.copyWith(
      isListening: true,
      recognizedText: '',
      partialText: '',
    );
    _vadBuffer.clear();
    _fullRecording.clear();

    // Check mic permission
    final hasPerm = await _recorder.hasPermission();
    debugPrint('$_tag mic permission: $hasPerm');
    if (!hasPerm) {
      debugPrint('$_tag startListening() ABORTED — no mic permission');
      state = state.copyWith(isListening: false);
      return;
    }

    debugPrint('$_tag starting audio stream (16kHz, mono, PCM16)...');
    try {
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
      );
      debugPrint('$_tag audio stream started OK');

      _audioSub = stream.listen(
        (bytes) {
          try {
            if (!state.isListening) return;

            _audioChunkCount++;
            final samples = _int16ToFloat32(bytes);
            _totalSamplesReceived += samples.length;

            // Log first chunk raw data for diagnostics
            if (_audioChunkCount == 1) {
              debugPrint('$_tag FIRST CHUNK: ${bytes.length} bytes '
                  '(offset=${bytes.offsetInBytes}) '
                  '→ ${samples.length} samples');
              final preview = samples.sublist(
                  0, math.min(20, samples.length));
              debugPrint('$_tag first 20 samples: $preview');
              final chunkRms = _computeRms(samples);
              debugPrint('$_tag first chunk RMS='
                  '${chunkRms.toStringAsFixed(4)}');
            }

            // Keep full recording for direct recognition fallback
            _fullRecording.addAll(samples);

            // Track audio levels
            for (final s in samples) {
              final abs = s.abs();
              if (abs > _peakAmplitude) _peakAmplitude = abs;
            }

            // Log audio levels every 50 chunks (~3s)
            if (_audioChunkCount % 50 == 0) {
              final rms = _computeRms(samples);
              debugPrint('$_tag audio: chunks=$_audioChunkCount, '
                  'totalSamples=$_totalSamplesReceived '
                  '(${(_totalSamplesReceived / 16000).toStringAsFixed(1)}s), '
                  'rms=${rms.toStringAsFixed(4)}, '
                  'peak=${_peakAmplitude.toStringAsFixed(4)}, '
                  'vadSegments=$_vadSegmentCount, '
                  'fullRecLen=${_fullRecording.length}');
            }

            // Feed VAD for real-time partial results
            _vadBuffer.addAll(samples);
            while (_vadBuffer.length >= _vadWindowSize) {
              final window = Float32List.fromList(
                _vadBuffer.sublist(0, _vadWindowSize),
              );
              _vadBuffer.removeRange(0, _vadWindowSize);

              _vad?.acceptWaveform(window);

              while (_vad != null && !(_vad!.isEmpty())) {
                final segment = _vad!.front();
                _vad!.pop();
                _vadSegmentCount++;
                debugPrint('$_tag VAD segment #$_vadSegmentCount detected! '
                    'samples=${segment.samples.length} '
                    '(${(segment.samples.length / 16000).toStringAsFixed(2)}s)');
                _recognizeSegment(segment.samples);
              }
            }
          } catch (e, st) {
            if (_audioChunkCount <= 3) {
              debugPrint('$_tag AUDIO CALLBACK ERROR (chunk #$_audioChunkCount): $e');
              debugPrint('$_tag stack: $st');
            }
          }
        },
        onError: (e) {
          debugPrint('$_tag audio stream ERROR: $e');
        },
        onDone: () {
          debugPrint('$_tag audio stream DONE');
        },
      );
    } catch (e, st) {
      debugPrint('$_tag startStream FAILED: $e');
      debugPrint('$_tag stack trace: $st');
      state = state.copyWith(isListening: false);
    }
  }

  /// Recognize a single speech segment.
  void _recognizeSegment(Float32List samples) {
    if (_recognizer == null) {
      debugPrint('$_tag _recognizeSegment: recognizer is null!');
      return;
    }

    final segRms = _computeRms(samples);
    final segMin = samples.reduce(math.min);
    final segMax = samples.reduce(math.max);
    debugPrint('$_tag recognizing: ${samples.length} samples '
        '(${(samples.length / 16000).toStringAsFixed(2)}s), '
        'rms=${segRms.toStringAsFixed(4)}, '
        'min=${segMin.toStringAsFixed(4)}, '
        'max=${segMax.toStringAsFixed(4)}');

    try {
      final stream = _recognizer!.createStream();
      debugPrint('$_tag stream created');

      stream.acceptWaveform(
        samples: samples,
        sampleRate: AppConstants.medAsrSampleRate,
      );
      debugPrint('$_tag waveform accepted');

      _recognizer!.decode(stream);
      debugPrint('$_tag decode done');

      final result = _recognizer!.getResult(stream);
      debugPrint('$_tag result: text="${result.text}", '
          'tokens=${result.tokens}, '
          'timestamps=${result.timestamps}');
      stream.free();

      final text = result.text.trim();
      if (text.isNotEmpty) {
        final current = state.recognizedText;
        final updated = current.isEmpty ? text : '$current $text';
        state = state.copyWith(
          recognizedText: updated,
          partialText: updated,
        );
        debugPrint('$_tag accumulated text: "$updated"');
      } else {
        debugPrint('$_tag recognition returned EMPTY text');
      }
    } catch (e, st) {
      debugPrint('$_tag _recognizeSegment FAILED: $e');
      debugPrint('$_tag stack trace: $st');
    }
  }

  /// Stop listening and return final recognized text.
  Future<String> stopListening() async {
    debugPrint('$_tag stopListening() called — '
        'chunks=$_audioChunkCount, '
        'totalSamples=$_totalSamplesReceived, '
        'vadSegments=$_vadSegmentCount, '
        'peak=${_peakAmplitude.toStringAsFixed(4)}, '
        'fullRecLen=${_fullRecording.length}');

    await _audioSub?.cancel();
    _audioSub = null;
    await _recorder.stop();
    debugPrint('$_tag recorder stopped');

    // Try VAD flush for any remaining segments
    if (_vadBuffer.isNotEmpty && _vad != null) {
      debugPrint('$_tag flushing VAD (${_vadBuffer.length} remaining)...');
      var offset = 0;
      final remaining = Float32List.fromList(_vadBuffer);
      _vadBuffer.clear();
      while (offset + _vadWindowSize <= remaining.length) {
        final window = Float32List.sublistView(
          remaining, offset, offset + _vadWindowSize);
        _vad!.acceptWaveform(window);
        offset += _vadWindowSize;
      }
      _vad?.flush();
      while (_vad != null && !(_vad!.isEmpty())) {
        final segment = _vad!.front();
        _vad!.pop();
        _vadSegmentCount++;
        debugPrint('$_tag flush VAD segment: ${segment.samples.length} samples');
        _recognizeSegment(segment.samples);
      }
    }

    // FALLBACK: If VAD found nothing, recognize full recording directly.
    // This handles push-to-talk where VAD may not detect speech
    // (threshold too high, short utterance, quiet audio, etc.)
    if (state.recognizedText.isEmpty && _fullRecording.isNotEmpty) {
      final totalSeconds = _fullRecording.length / 16000;
      debugPrint('$_tag VAD found nothing. '
          'Trying direct recognition on full recording '
          '(${_fullRecording.length} samples, '
          '${totalSeconds.toStringAsFixed(1)}s)...');

      final allSamples = Float32List.fromList(_fullRecording);
      final rms = _computeRms(allSamples);
      debugPrint('$_tag full recording RMS=${rms.toStringAsFixed(4)}, '
          'peak=${_peakAmplitude.toStringAsFixed(4)}');

      if (rms > 0.001) {
        // Only attempt if there's actual audio (not silence)
        _recognizeSegment(allSamples);
      } else {
        debugPrint('$_tag audio appears silent (RMS=${rms.toStringAsFixed(6)}), '
            'skipping recognition');
      }
    }

    _vad?.clear();
    _fullRecording.clear();
    _vadBuffer.clear();

    final finalText = state.recognizedText;
    state = state.copyWith(isListening: false);
    debugPrint('$_tag stopListening() DONE — finalText: "$finalText"');
    return finalText;
  }

  /// Compute RMS (root mean square) amplitude of audio samples.
  double _computeRms(List<double> samples) {
    if (samples.isEmpty) return 0.0;
    var sum = 0.0;
    for (final s in samples) {
      sum += s * s;
    }
    return math.sqrt(sum / samples.length);
  }

  /// Extract a Flutter asset to the app documents directory.
  Future<String> _extractAsset(String assetName, String targetDir) async {
    final targetPath = '$targetDir/$assetName';
    final file = File(targetPath);
    if (await file.exists()) {
      final size = await file.length();
      debugPrint('$_tag asset "$assetName" already exists ($size bytes)');
      return targetPath;
    }

    debugPrint('$_tag copying asset "$assetName" from bundle...');
    final data = await rootBundle.load(
      '${AppConstants.medAsrAssetDir}/$assetName',
    );
    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    final size = await file.length();
    debugPrint('$_tag asset "$assetName" extracted ($size bytes)');
    return targetPath;
  }

  /// Convert PCM16 Int16 bytes to Float32 samples in [-1.0, 1.0].
  /// Uses ByteData for alignment-safe reading (handles any offsetInBytes).
  Float32List _int16ToFloat32(Uint8List bytes) {
    final byteData = ByteData.sublistView(bytes);
    final sampleCount = bytes.length ~/ 2;
    final float32 = Float32List(sampleCount);
    for (var i = 0; i < sampleCount; i++) {
      float32[i] = byteData.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return float32;
  }

  @override
  void dispose() {
    debugPrint('$_tag dispose()');
    _audioSub?.cancel();
    _recorder.dispose();
    _vad?.free();
    _recognizer?.free();
    super.dispose();
  }
}

/// Riverpod provider for MedASR service.
final medAsrProvider = StateNotifierProvider<MedAsrService, MedAsrState>(
  (ref) {
    debugPrint('$_tag provider created');
    final service = MedAsrService();
    service.initialize();
    return service;
  },
);
