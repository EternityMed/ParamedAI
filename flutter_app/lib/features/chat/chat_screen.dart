import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../core/connectivity/connectivity_manager.dart';
import '../../shared/connection_indicator.dart';
import 'chat_controller.dart';
import 'chat_bubble.dart';
import 'voice_input_button.dart';

/// Main chat screen with AI assistant.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    await ref.read(chatControllerProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      await ref.read(chatControllerProvider.notifier).sendImage(
            bytes,
            pickedFile.name,
          );
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatControllerProvider);
    final connState = ref.watch(connectivityProvider);
    final isOnline = !connState.useLocalLlama;

    // Auto-scroll when new messages arrive
    ref.listen(chatControllerProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: ParamedTheme.emergencyRed.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.local_hospital,
                color: ParamedTheme.emergencyRed,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text('ParaMed AI'),
          ],
        ),
        actions: [
          const ConnectionIndicator(),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 22),
            tooltip: 'Clear chat',
            onPressed: () {
              ref.read(chatControllerProvider.notifier).clearChat();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: chatState.messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 12, bottom: 12),
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, index) {
                      return ChatBubble(message: chatState.messages[index]);
                    },
                  ),
          ),

          // Input area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: ParamedTheme.surface,
              border: Border(
                top: BorderSide(color: ParamedTheme.border),
              ),
            ),
            child: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Camera button for EKG photos (only available in online mode)
                  if (isOnline)
                    IconButton(
                      icon: const Icon(Icons.camera_alt_outlined),
                      color: ParamedTheme.textSecondary,
                      tooltip: 'Capture ECG/Image',
                      onPressed: _pickImage,
                    ),

                  // Text input
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText: 'Type your message...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),

                  // Voice input
                  VoiceInputButton(
                    onResult: (text) {
                      _textController.text = text;
                      _sendMessage();
                    },
                  ),

                  const SizedBox(width: 4),

                  // Send button
                  IconButton(
                    icon: Icon(
                      Icons.send,
                      color: chatState.isSending
                          ? ParamedTheme.textSecondary
                          : ParamedTheme.medicalBlue,
                    ),
                    onPressed: chatState.isSending ? null : _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ParamedTheme.emergencyRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_hospital,
                size: 48,
                color: ParamedTheme.emergencyRed,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'ParaMed AI Assistant',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: ParamedTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'AI-Powered Clinical Decision Support\nfor Emergency Medical Services',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ParamedTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            _buildQuickAction(
              icon: Icons.medication,
              label: 'Calculate drug dose',
              prompt: 'Epinephrine 1:1000, 80 kg patient, anaphylaxis',
            ),
            const SizedBox(height: 8),
            _buildQuickAction(
              icon: Icons.monitor_heart,
              label: 'STEMI protocol',
              prompt: 'Chest pain, ST elevation, suspected STEMI',
            ),
            const SizedBox(height: 8),
            _buildQuickAction(
              icon: Icons.emergency,
              label: 'Trauma management',
              prompt: 'Motor vehicle accident, multiple trauma, unconscious',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required String prompt,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          _textController.text = prompt;
          _sendMessage();
        },
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: ParamedTheme.textPrimary,
          side: const BorderSide(color: ParamedTheme.border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}
