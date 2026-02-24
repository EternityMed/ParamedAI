import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../core/audio/stt_router.dart';

const _tag = '[VoiceBtn]';

/// Animated microphone button for voice input.
class VoiceInputButton extends ConsumerStatefulWidget {
  final ValueChanged<String> onResult;

  const VoiceInputButton({super.key, required this.onResult});

  @override
  ConsumerState<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends ConsumerState<VoiceInputButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sttState = ref.watch(activeSTTProvider);
    final sttNotifier = ref.read(activeSTTProvider.notifier);

    // Animate when listening
    if (sttState.isListening && !_animController.isAnimating) {
      _animController.repeat(reverse: true);
    } else if (!sttState.isListening && _animController.isAnimating) {
      _animController.stop();
      _animController.reset();
    }

    return GestureDetector(
      onTap: () async {
        debugPrint('$_tag tapped — isListening=${sttState.isListening}, '
            'engine=${sttState.activeEngine}');

        if (sttState.isListening) {
          debugPrint('$_tag stopping...');
          await sttNotifier.stopListening();
          final text = ref.read(activeSTTProvider).recognizedText;
          debugPrint('$_tag stop result: "$text"');
          if (text.isNotEmpty) {
            debugPrint('$_tag → calling onResult("$text")');
            widget.onResult(text);
          } else {
            debugPrint('$_tag → text empty, NOT calling onResult');
          }
        } else {
          debugPrint('$_tag starting...');
          await sttNotifier.startListening();
          debugPrint('$_tag startListening returned — '
              'engine=${ref.read(activeSTTProvider).activeEngine}');
        }
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: sttState.isListening ? _scaleAnimation.value : 1.0,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: sttState.isListening
                    ? ParamedTheme.emergencyRed
                    : ParamedTheme.medicalBlue,
                boxShadow: sttState.isListening
                    ? [
                        BoxShadow(
                          color: ParamedTheme.emergencyRed.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                sttState.isListening ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 24,
              ),
            ),
          );
        },
      ),
    );
  }
}
