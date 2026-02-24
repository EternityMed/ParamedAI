import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Displays an emergency medical protocol with numbered steps.
class ProtocolCardWidget extends StatelessWidget {
  final Map<String, dynamic> data;

  const ProtocolCardWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final protocolName = data['protocolName'] as String? ??
        data['protocol_name'] as String? ??
        'Protocol';
    final urgency = (data['urgency'] as String? ?? 'moderate').toUpperCase();
    final rawSteps = data['steps'] as List? ?? [];
    final notes = data['notes'] as String?;
    final source = data['source'] as String?;
    final rawCurrentStep = data['currentStep'] ?? data['current_step'];
    final currentStep = rawCurrentStep is int ? rawCurrentStep : int.tryParse('$rawCurrentStep') ?? -1;

    // Normalize steps: accept both List<String> and List<Map>
    final steps = <Map<String, dynamic>>[];
    for (int i = 0; i < rawSteps.length; i++) {
      final item = rawSteps[i];
      if (item is String) {
        steps.add({
          'step_number': i + 1,
          'description': item,
          'is_current': i == currentStep,
        });
      } else if (item is Map) {
        steps.add({
          'step_number': item['step_number'] ?? item['stepNumber'] ?? (i + 1),
          'description': item['description'] ?? item['text'] ?? '',
          'is_current': item['is_current'] ?? item['isCurrent'] ?? (i == currentStep),
        });
      }
    }

    final urgencyColor = _urgencyColor(urgency);

    return Card(
      color: ParamedTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: urgencyColor.withValues(alpha: 0.5), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: urgencyColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    protocolName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: ParamedTheme.textPrimary,
                    ),
                  ),
                ),
                if (source != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: ParamedTheme.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ParamedTheme.border),
                    ),
                    child: Text(
                      source,
                      style: const TextStyle(
                        color: ParamedTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Steps
            ...steps.map((step) {
              final stepNumber = step['step_number'];
              final description = step['description'] as String? ?? '';
              final isCurrent = step['is_current'] as bool? ?? false;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? urgencyColor.withValues(alpha: 0.15)
                      : ParamedTheme.background,
                  borderRadius: BorderRadius.circular(8),
                  border: isCurrent
                      ? Border.all(color: urgencyColor, width: 1.5)
                      : Border.all(color: ParamedTheme.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? urgencyColor
                            : ParamedTheme.border,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$stepNumber',
                          style: TextStyle(
                            color: isCurrent ? Colors.white : ParamedTheme.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        description,
                        style: TextStyle(
                          color: isCurrent
                              ? ParamedTheme.textPrimary
                              : ParamedTheme.textSecondary,
                          fontSize: 14,
                          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (isCurrent)
                      Icon(Icons.arrow_forward_ios, size: 14, color: urgencyColor),
                  ],
                ),
              );
            }),

            // Notes
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ParamedTheme.medicalBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: ParamedTheme.medicalBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        notes,
                        style: const TextStyle(
                          color: ParamedTheme.medicalBlue,
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
  }

  Color _urgencyColor(String urgency) {
    switch (urgency) {
      case 'CRITICAL' || 'RED':
        return ParamedTheme.emergencyRed;
      case 'HIGH' || 'ORANGE':
        return ParamedTheme.warningOrange;
      case 'MODERATE' || 'YELLOW':
        return ParamedTheme.triageYellow;
      case 'LOW' || 'GREEN':
        return ParamedTheme.safeGreen;
      default:
        return ParamedTheme.textSecondary;
    }
  }
}
