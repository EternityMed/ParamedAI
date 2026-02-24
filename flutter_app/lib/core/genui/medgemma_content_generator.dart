import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart';

import '../api/api_client.dart';

/// Content generator that bridges MedGemma backend with GenUI.
/// Sends requests to the backend /chat endpoint and converts
/// response widgets into A2uiMessage stream for GenUI surfaces.
class MedGemmaContentGenerator implements ContentGenerator {
  final ApiClient _apiClient;

  MedGemmaContentGenerator(this._apiClient);

  final StreamController<A2uiMessage> _a2uiController =
      StreamController<A2uiMessage>.broadcast();
  final StreamController<String> _textController =
      StreamController<String>.broadcast();
  final StreamController<ContentGeneratorError> _errorController =
      StreamController<ContentGeneratorError>.broadcast();
  final ValueNotifier<bool> _isProcessing = ValueNotifier(false);

  int _surfaceCounter = 0;

  @override
  Stream<A2uiMessage> get a2uiMessageStream => _a2uiController.stream;

  @override
  Stream<String> get textResponseStream => _textController.stream;

  @override
  Stream<ContentGeneratorError> get errorStream => _errorController.stream;

  @override
  ValueListenable<bool> get isProcessing => _isProcessing;

  @override
  Future<void> sendRequest(
    ChatMessage message, {
    Iterable<ChatMessage>? history,
    A2UiClientCapabilities? clientCapabilities,
  }) async {
    if (message is! UserMessage) return;

    final userText = message.text;
    if (userText.isEmpty) return;

    _isProcessing.value = true;

    try {
      final response = await _apiClient.chat(
        message: userText,
        history: _buildHistory(history),
      );

      final text = response['text'] as String?;
      final widgets = response['widgets'] as List? ?? [];

      // Emit each widget as its own separate surface
      for (int i = 0; i < widgets.length; i++) {
        final widget = widgets[i] as Map<String, dynamic>;
        final widgetType = widget['type'] as String? ?? 'Text';
        final widgetData = widget['data'] as Map<String, dynamic>? ?? {};

        _surfaceCounter++;
        final surfaceId = 'surface_$_surfaceCounter';

        final component = {
          'id': 'root',
          'component': {
            widgetType: widgetData,
          },
        };

        _a2uiController.add(SurfaceUpdate(
          surfaceId: surfaceId,
          components: [Component.fromJson(component)],
        ));

        _a2uiController.add(BeginRendering(
          surfaceId: surfaceId,
          root: 'root',
        ));
      }

      // Emit text response if present
      if (text != null && text.isNotEmpty) {
        _textController.add(text);
      }
    } catch (e, st) {
      _errorController.add(ContentGeneratorError(e, st));
    } finally {
      _isProcessing.value = false;
    }
  }

  List<Map<String, dynamic>> _buildHistory(Iterable<ChatMessage>? history) {
    if (history == null) return [];
    final result = <Map<String, dynamic>>[];
    for (final msg in history) {
      if (msg is UserMessage) {
        result.add({'role': 'user', 'content': msg.text});
      } else if (msg is AiTextMessage) {
        result.add({'role': 'assistant', 'content': msg.text});
      }
    }
    return result;
  }

  @override
  void dispose() {
    _a2uiController.close();
    _textController.close();
    _errorController.close();
    _isProcessing.dispose();
  }
}
