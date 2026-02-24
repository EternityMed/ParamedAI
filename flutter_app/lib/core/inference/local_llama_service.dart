/// On-device inference service using llamadart (llama.cpp).
///
/// Wraps LlamaEngine to provide the same response format as ApiClient.chat(),
/// enabling seamless switching between online API and offline on-device mode.
/// Text-only mode — multimodal/vision disabled to prevent device freezing.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llamadart/llamadart.dart';

import '../../config/constants.dart';
import 'genui_parser.dart';
import 'prompt_builder.dart';

class LocalLlamaService {
  LlamaEngine? _engine;
  final GenUIParser _parser = GenUIParser();

  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  /// Load the GGUF model into memory.
  ///
  /// Throws on failure with the actual error message.
  Future<void> loadModel(String modelPath) async {
    // Create engine and load model
    _engine = LlamaEngine(LlamaBackend());

    final gpuLayers = AppConstants.llamaGpuLayers;

    await _engine!.loadModel(
      modelPath,
      modelParams: ModelParams(
        contextSize: AppConstants.llamaContextSize,
        gpuLayers: gpuLayers,
        preferredBackend: gpuLayers > 0 ? GpuBackend.auto : GpuBackend.cpu,
        numberOfThreads: AppConstants.llamaThreads,
      ),
    );
    _isLoaded = true;
  }

  /// Send a text message and get a GenUI-formatted response.
  ///
  /// Returns `{text: String, widgets: List<Map>}` — same format as ApiClient.chat().
  Future<Map<String, dynamic>> chat({required String message}) async {
    if (!_isLoaded || _engine == null) {
      return _notLoadedResponse();
    }

    // Build messages for llamadart (no RAG — disabled for performance)
    final messages = PromptBuilder.buildMessages(
      message: message,
    );

    // Generate response via streaming, collect full text
    final buffer = StringBuffer();
    await for (final chunk in _engine!.create(
      messages,
      params: const GenerationParams(
        maxTokens: AppConstants.llamaMaxTokens,
        temp: 0.2,
        topP: 0.9,
        topK: 20,
        penalty: 1.0,
      ),
    )) {
      final content = chunk.choices.firstOrNull?.delta.content;
      if (content != null) buffer.write(content);
    }

    // Parse GenUI JSON from LLM output
    return _parser.parse(buffer.toString());
  }

  /// Stream tokens from the model.
  Stream<String> chatStream({required String message}) async* {
    if (!_isLoaded || _engine == null) {
      yield 'Model yuklenmedi.';
      return;
    }

    final messages = PromptBuilder.buildMessages(
      message: message,
    );

    await for (final chunk in _engine!.create(
      messages,
      params: const GenerationParams(
        maxTokens: AppConstants.llamaMaxTokens,
        temp: 0.2,
        topP: 0.9,
        topK: 20,
        penalty: 1.0,
      ),
    )) {
      final content = chunk.choices.firstOrNull?.delta.content;
      if (content != null) yield content;
    }
  }

  /// Send a raw prompt without GenUI system prompt.
  /// Used for triage and other tasks that don't need widget catalog.
  /// [maxTokens] allows callers to limit output length for faster response.
  Future<String> chatRaw({
    required String prompt,
    int maxTokens = 128,
  }) async {
    if (!_isLoaded || _engine == null) return '';

    final messages = [
      LlamaChatMessage.fromText(
        role: LlamaChatRole.user,
        text: prompt,
      ),
    ];

    final buffer = StringBuffer();
    await for (final chunk in _engine!.create(
      messages,
      params: GenerationParams(
        maxTokens: maxTokens,
        temp: 0.2,
        topP: 0.9,
        topK: 20,
        penalty: 1.0,
      ),
    )) {
      final content = chunk.choices.firstOrNull?.delta.content;
      if (content != null) buffer.write(content);
    }

    return buffer.toString();
  }

  /// Unload model from memory.
  Future<void> unload() async {
    if (_engine != null) {
      await _engine!.dispose();
      _engine = null;
      _isLoaded = false;
    }
  }

  Map<String, dynamic> _notLoadedResponse() {
    return {
      'text': 'Model not loaded. Please load the model first.',
      'widgets': <Map<String, dynamic>>[
        {
          'type': 'WarningCard',
          'data': {
            'title': 'Model Not Loaded',
            'message':
                'No on-device model is loaded. Download the model from settings.',
            'severity': 'WARNING',
            'action': 'Download the model or establish an internet connection.',
          },
        },
      ],
    };
  }
}

/// Riverpod provider for the local llama service.
final localLlamaProvider = Provider<LocalLlamaService>((ref) {
  final service = LocalLlamaService();
  ref.onDispose(() => service.unload());
  return service;
});
