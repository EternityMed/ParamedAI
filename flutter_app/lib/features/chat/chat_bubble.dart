import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../widgets/drug_dose_card.dart';
import '../../widgets/triage_card.dart';
import '../../widgets/protocol_card.dart';
import '../../widgets/ecg_analysis_card.dart';
import '../../widgets/vital_signs_card.dart';
import '../../widgets/patient_form_card.dart';

import '../../widgets/warning_card.dart';
import 'chat_controller.dart';

/// Chat message bubble widget.
class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';

    // Loading indicator (before any tokens arrive)
    if (message.isLoading) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ParamedTheme.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: ParamedTheme.medicalBlue.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Preparing response...',
                style: TextStyle(
                  color: ParamedTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Streaming: show live text with blinking cursor
    if (message.isStreaming) {
      return _buildStreamingBubble();
    }

    if (isUser) {
      return _buildUserBubble();
    } else {
      return _buildAssistantBubble();
    }
  }

  Widget _buildStreamingBubble() {
    final text = message.text ?? '';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: ParamedTheme.card,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                text,
                style: const TextStyle(
                  color: ParamedTheme.textPrimary,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
            const _BlinkingCursor(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserBubble() {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: ParamedTheme.medicalBlue,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(
          message.text ?? '',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildAssistantBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text content
            if (message.text != null && message.text!.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: ParamedTheme.card,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Text(
                  message.text!,
                  style: const TextStyle(
                    color: ParamedTheme.textPrimary,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ),

            // Widget content
            if (message.widgets != null)
              ...message.widgets!.map((widget) {
                final type = widget['type'] as String? ?? '';
                final data = widget['data'] as Map<String, dynamic>? ?? widget;

                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _buildWidget(type, data),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildWidget(String type, Map<String, dynamic> data) {
    Widget child;
    try {
      switch (type) {
        case 'DrugDoseCard':
          child = DrugDoseCardWidget(data: data);
        case 'TriageCard':
          child = TriageCardWidget(data: data);
        case 'ProtocolCard':
          child = ProtocolCardWidget(data: data);
        case 'ECGAnalysisCard':
          child = ECGAnalysisCardWidget(data: data);
        case 'VitalSignsCard':
          child = VitalSignsCardWidget(data: data);
        case 'PatientFormCard':
          child = PatientFormCardWidget(data: data);

        case 'WarningCard':
          child = WarningCardWidget(data: data);
        default:
          return _widgetError('Unknown widget: $type', '');
      }
    } catch (e, st) {
      return _widgetError('$type constructor error', '$e\n$st');
    }
    // Wrap with error boundary to catch build() errors
    return _WidgetErrorBoundary(typeName: type, child: child);
  }

  static Widget _widgetError(String title, String detail) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ParamedTheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ParamedTheme.warningOrange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(color: ParamedTheme.warningOrange, fontWeight: FontWeight.bold, fontSize: 13)),
          if (detail.isNotEmpty)
            Text(detail, style: const TextStyle(color: ParamedTheme.textSecondary, fontSize: 10), maxLines: 8, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// Catches build() errors and displays an error card instead of a red screen.
class _WidgetErrorBoundary extends StatefulWidget {
  final String typeName;
  final Widget child;

  const _WidgetErrorBoundary({required this.typeName, required this.child});

  @override
  State<_WidgetErrorBoundary> createState() => _WidgetErrorBoundaryState();
}

class _WidgetErrorBoundaryState extends State<_WidgetErrorBoundary> {
  FlutterErrorDetails? _error;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return ChatBubble._widgetError(
        '${widget.typeName} build error',
        _error!.exceptionAsString(),
      );
    }

    // Use a custom error handler for this widget tree
    final originalHandler = FlutterError.onError;
    Widget result;
    try {
      // Build the child within a Builder to capture any layout errors
      result = Builder(
        builder: (context) {
          return widget.child;
        },
      );
    } catch (e, st) {
      FlutterError.onError = originalHandler;
      return ChatBubble._widgetError(
        '${widget.typeName} error',
        '$e',
      );
    }
    return result;
  }
}

/// Blinking cursor shown at the end of streaming text.
class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: const Padding(
        padding: EdgeInsets.only(left: 2, bottom: 1),
        child: Text(
          '▌',
          style: TextStyle(
            color: ParamedTheme.medicalBlue,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
