import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/api_client.dart';
import '../../core/connectivity/connectivity_manager.dart';
import '../../core/inference/genui_parser.dart';
import '../../core/inference/local_llama_service.dart';
import '../../core/inference/model_manager.dart';

/// Represents a single chat message.
class ChatMessage {
  final String id;
  final String role; // 'user' or 'assistant'
  final String? text;
  final List<Map<String, dynamic>>? widgets;
  final String? imageUrl;
  final DateTime timestamp;
  final bool isLoading;
  final bool isStreaming;

  ChatMessage({
    String? id,
    required this.role,
    this.text,
    this.widgets,
    this.imageUrl,
    this.isLoading = false,
    this.isStreaming = false,
    DateTime? timestamp,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({
    String? text,
    List<Map<String, dynamic>>? widgets,
    bool? isLoading,
    bool? isStreaming,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      text: text ?? this.text,
      widgets: widgets ?? this.widgets,
      imageUrl: imageUrl,
      isLoading: isLoading ?? this.isLoading,
      isStreaming: isStreaming ?? this.isStreaming,
      timestamp: timestamp,
    );
  }
}

/// Chat state holding messages and loading state.
class ChatState {
  final List<ChatMessage> messages;
  final bool isSending;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isSending = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isSending,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      error: error,
    );
  }
}

/// Riverpod controller for chat state management.
///
/// Routes messages to either the remote API or on-device llamadart
/// depending on connectivity state.
class ChatController extends StateNotifier<ChatState> {
  final ApiClient _apiClient;
  final Ref _ref;

  ChatController(this._apiClient, this._ref) : super(const ChatState());

  /// Send a text message — routes to remote API or on-device model.
  ///
  /// On-device: streams tokens live to UI, then parses GenUI widgets at the end.
  /// Online: sends request and waits for full response (already fast).
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Add user message
    final userMsg = ChatMessage(role: 'user', text: text);
    final loadingMsg = ChatMessage(role: 'assistant', isLoading: true);

    state = state.copyWith(
      messages: [...state.messages, userMsg, loadingMsg],
      isSending: true,
      error: null,
    );

    try {
      final connState = _ref.read(connectivityProvider);

      if (connState.useLocalLlama) {
        // Offline → stream tokens from on-device model
        await _sendLocalStreaming(text);
      } else {
        // Online → remote backend API (full response)
        await _sendRemote(text);
      }
    } catch (e) {
      // Replace last message with error
      final msgs = List<ChatMessage>.from(state.messages);
      msgs.removeLast();
      msgs.add(ChatMessage(
        role: 'assistant',
        text: 'Error: ${e.toString()}',
      ));

      state = state.copyWith(
        messages: msgs,
        isSending: false,
        error: e.toString(),
      );
    }
  }

  /// Stream tokens from on-device llamadart and show extracted text live.
  /// Filters out raw JSON — only the "text" field value is displayed.
  /// When stream completes, parse GenUI widgets and replace the message.
  Future<void> _sendLocalStreaming(String text) async {
    final llama = _ref.read(localLlamaProvider);
    await _ensureModelLoaded(llama);

    final buffer = StringBuffer();

    // Replace loading message with streaming message
    _updateLastMessage(ChatMessage(
      role: 'assistant',
      text: '',
      isStreaming: true,
    ));

    await for (final token in llama.chatStream(message: text)) {
      buffer.write(token);

      // Extract only the "text" field value from partial JSON for display
      final displayText = _extractStreamingText(buffer.toString());

      _updateLastMessage(ChatMessage(
        role: 'assistant',
        text: displayText ?? '',
        isStreaming: true,
      ));
    }

    // Stream complete — parse GenUI widgets from the full response
    final rawOutput = buffer.toString();
    dev.log('=== RAW LLM OUTPUT ===\n$rawOutput\n=== END RAW ===', name: 'ParaMed');

    final parser = GenUIParser();
    final parsed = parser.parse(rawOutput);

    final responseText = parsed['text'] as String?;
    final responseWidgets = (parsed['widgets'] as List?)
        ?.map((w) => w as Map<String, dynamic>)
        .toList();

    dev.log('=== PARSED RESULT ===\ntext: $responseText\nwidgets: $responseWidgets\n=== END PARSED ===', name: 'ParaMed');

    _updateLastMessage(ChatMessage(
      role: 'assistant',
      text: responseText,
      widgets: responseWidgets,
    ));

    state = state.copyWith(isSending: false);
  }

  /// Extract the "text" field value from a partial JSON stream for live display.
  /// After text is complete, also shows which widgets are being generated.
  /// Returns null if the "text" field hasn't started yet.
  String? _extractStreamingText(String raw) {
    final match = RegExp(r'"text"\s*:\s*"').firstMatch(raw);
    if (match == null) return null;

    final start = match.end;
    if (start >= raw.length) return '';

    final sb = StringBuffer();
    var textComplete = false;

    for (var i = start; i < raw.length; i++) {
      if (raw[i] == '\\' && i + 1 < raw.length) {
        // Handle JSON escape sequences
        switch (raw[i + 1]) {
          case '"':
            sb.write('"');
          case 'n':
            sb.write('\n');
          case 't':
            sb.write('\t');
          case '\\':
            sb.write('\\');
          default:
            sb.write(raw[i + 1]);
        }
        i++;
      } else if (raw[i] == '"') {
        textComplete = true;
        break;
      } else {
        sb.write(raw[i]);
      }
    }

    // After text field is complete, show which widgets are being generated
    if (textComplete) {
      final widgetTypes =
          RegExp(r'"type"\s*:\s*"(\w+)"').allMatches(raw).toList();
      if (widgetTypes.isNotEmpty) {
        sb.write('\n');
        for (final wt in widgetTypes) {
          sb.write('\nGenerating ${_widgetDisplayName(wt.group(1)!)}...');
        }
      }
    }

    return sb.toString();
  }

  /// Map GenUI widget type to display name.
  static String _widgetDisplayName(String type) {
    return switch (type) {
      'DrugDoseCard' => 'Drug Dose Card',
      'TriageCard' => 'Triage Card',
      'ProtocolCard' => 'Protocol Card',
      'ECGAnalysisCard' => 'ECG Analysis Card',
      'VitalSignsCard' => 'Vital Signs Card',
      'PatientFormCard' => 'Patient Form Card',

      'WarningCard' => 'Warning Card',
      _ => type,
    };
  }

  /// Send message to remote backend API (non-streaming).
  Future<void> _sendRemote(String text) async {
    final history = state.messages
        .where((m) => !m.isLoading && !m.isStreaming && m.text != null)
        .map((m) => {
              'role': m.role,
              'content': m.text!,
            })
        .toList();

    final response = await _apiClient.chat(
      message: text,
      history: history,
    );

    final responseText = response['text'] as String?;
    final responseWidgets = (response['widgets'] as List?)
        ?.map((w) => w as Map<String, dynamic>)
        .toList();

    _updateLastMessage(ChatMessage(
      role: 'assistant',
      text: responseText,
      widgets: responseWidgets,
    ));

    state = state.copyWith(isSending: false);
  }

  /// Replace the last message in the list (loading/streaming → updated).
  void _updateLastMessage(ChatMessage message) {
    final msgs = List<ChatMessage>.from(state.messages);
    msgs[msgs.length - 1] = message;
    state = state.copyWith(messages: msgs);
  }

  /// Send an image for analysis via remote API (online mode only).
  Future<void> sendImage(Uint8List imageData, String filename) async {
    final userMsg = ChatMessage(
      role: 'user',
      text: 'ECG/Image analysis sent',
    );
    final loadingMsg = ChatMessage(role: 'assistant', isLoading: true);

    state = state.copyWith(
      messages: [...state.messages, userMsg, loadingMsg],
      isSending: true,
    );

    try {
      final response = await _apiClient.analyzeImage(
        imageData: imageData,
        filename: filename,
      );

      final responseText = response['text'] as String?;
      final responseWidgets = (response['widgets'] as List?)
          ?.map((w) => w as Map<String, dynamic>)
          .toList();

      final assistantMsg = ChatMessage(
        role: 'assistant',
        text: responseText,
        widgets: responseWidgets,
      );

      final msgs = List<ChatMessage>.from(state.messages);
      msgs.removeLast();
      msgs.add(assistantMsg);

      state = state.copyWith(messages: msgs, isSending: false);
    } catch (e) {
      final msgs = List<ChatMessage>.from(state.messages);
      msgs.removeLast();
      msgs.add(ChatMessage(role: 'assistant', text: 'Error: ${e.toString()}'));
      state = state.copyWith(messages: msgs, isSending: false);
    }
  }

  /// Load the on-device model into memory if not already loaded.
  Future<void> _ensureModelLoaded(LocalLlamaService llama) async {
    if (llama.isLoaded) return;
    final manager = _ref.read(modelManagerProvider.notifier);
    final downloaded = await manager.isModelDownloaded();
    if (!downloaded) {
      throw Exception(
        'Model not downloaded. Tap the badge to download the model.',
      );
    }
    final modelPath = await manager.getModelPath();
    await llama.loadModel(modelPath);
  }

  /// Clear chat history.
  void clearChat() {
    state = const ChatState();
  }
}

/// Provider for chat controller.
final chatControllerProvider =
    StateNotifierProvider<ChatController, ChatState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ChatController(apiClient, ref);
});
