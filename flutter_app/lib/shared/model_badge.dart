import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Badge showing the active model and connection status.
///
/// Three states:
/// | State              | Color   | Label         |
/// |--------------------|---------|---------------|
/// | Online (remote)    | Green   | 27B Server    |
/// | Offline (on-device)| Orange  | 4B Device     |
/// | Offline (no model) | Red     | Offline       |
class ModelBadge extends StatelessWidget {
  final String modelName;
  final bool isOnline;
  final bool useLocalLlama;
  final bool isModelLoaded;

  const ModelBadge({
    super.key,
    required this.modelName,
    required this.isOnline,
    required this.useLocalLlama,
    this.isModelLoaded = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color textColor;
    final String label;

    if (isOnline) {
      // Online — remote API
      bgColor = ParamedTheme.safeGreen.withValues(alpha: 0.2);
      textColor = ParamedTheme.safeGreen;
      label = '27B Server';
    } else if (useLocalLlama && isModelLoaded) {
      // Offline — on-device model loaded
      bgColor = ParamedTheme.warningOrange.withValues(alpha: 0.2);
      textColor = ParamedTheme.warningOrange;
      label = '4B Device';
    } else {
      // Offline — no model available
      bgColor = ParamedTheme.emergencyRed.withValues(alpha: 0.2);
      textColor = ParamedTheme.emergencyRed;
      label = 'Offline';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: textColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
