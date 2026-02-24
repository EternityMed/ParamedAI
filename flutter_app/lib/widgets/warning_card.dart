import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Displays critical warning, alert, or informational message.
/// Severity levels: CRITICAL (red pulsing), WARNING (orange), INFO (blue).
class WarningCardWidget extends StatefulWidget {
  final Map<String, dynamic> data;

  const WarningCardWidget({super.key, required this.data});

  @override
  State<WarningCardWidget> createState() => _WarningCardWidgetState();
}

class _WarningCardWidgetState extends State<WarningCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    final severity = (widget.data['severity'] as String? ?? 'INFO').toUpperCase();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Only pulse for critical warnings
    if (severity == 'CRITICAL') {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final severity = (widget.data['severity'] as String? ?? 'INFO').toUpperCase();
    final title = widget.data['title'] as String? ?? '';
    final message = widget.data['message'] as String? ?? '';
    final recommendedAction = widget.data['recommended_action'] as String? ??
        widget.data['action'] as String?;

    final config = _severityConfig(severity);

    final card = Card(
      color: config.bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: config.borderColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(config.icon, color: config.iconColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (severity == 'CRITICAL')
                        Text(
                          'CRITICAL WARNING',
                          style: TextStyle(
                            color: config.textColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: config.textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Message
            Text(
              message,
              style: TextStyle(
                color: config.textColor.withValues(alpha: 0.9),
                fontSize: 14,
                height: 1.4,
              ),
            ),

            // Recommended action
            if (recommendedAction != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: config.textColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        recommendedAction,
                        style: TextStyle(
                          color: config.textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );

    // Pulse animation for critical
    if (severity == 'CRITICAL') {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: ParamedTheme.emergencyRed.withValues(alpha: _pulseAnimation.value * 0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: child,
          );
        },
        child: card,
      );
    }

    return card;
  }

  _SeverityConfig _severityConfig(String severity) {
    switch (severity) {
      case 'CRITICAL':
        return _SeverityConfig(
          bgColor: ParamedTheme.emergencyRed.withValues(alpha: 0.9),
          borderColor: ParamedTheme.emergencyRed,
          textColor: Colors.white,
          iconColor: Colors.white,
          icon: Icons.warning_amber_rounded,
        );
      case 'WARNING':
        return _SeverityConfig(
          bgColor: ParamedTheme.warningOrange.withValues(alpha: 0.85),
          borderColor: ParamedTheme.warningOrange,
          textColor: Colors.white,
          iconColor: Colors.white,
          icon: Icons.error_outline,
        );
      default: // INFO
        return _SeverityConfig(
          bgColor: ParamedTheme.medicalBlue.withValues(alpha: 0.15),
          borderColor: ParamedTheme.medicalBlue,
          textColor: ParamedTheme.medicalBlue,
          iconColor: ParamedTheme.medicalBlue,
          icon: Icons.info_outline,
        );
    }
  }
}

class _SeverityConfig {
  final Color bgColor;
  final Color borderColor;
  final Color textColor;
  final Color iconColor;
  final IconData icon;

  const _SeverityConfig({
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
    required this.iconColor,
    required this.icon,
  });
}
