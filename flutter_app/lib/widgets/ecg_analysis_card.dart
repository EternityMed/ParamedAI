import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Displays ECG/EKG analysis results from MedGemma.
class ECGAnalysisCardWidget extends StatelessWidget {
  final Map<String, dynamic> data;

  const ECGAnalysisCardWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final rhythmType = data['rhythm_type'] as String? ?? 'Unknown';
    final heartRate = data['heart_rate'];
    final interpretation = data['interpretation'] as String? ?? '';
    final stChanges = data['st_changes'] as String?;
    final urgentAction = data['urgent_action'] as String?;
    final differentials = (data['differentials'] as List?)?.cast<String>() ?? [];
    final confidence = data['confidence'];

    return Card(
      color: ParamedTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: urgentAction != null
              ? ParamedTheme.emergencyRed
              : ParamedTheme.medicalBlue,
          width: 1,
        ),
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ParamedTheme.emergencyRed.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.monitor_heart,
                    color: ParamedTheme.emergencyRed,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rhythmType,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: ParamedTheme.textPrimary,
                        ),
                      ),
                      const Text(
                        'ECG Analysis',
                        style: TextStyle(
                          color: ParamedTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (confidence != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ParamedTheme.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '%${((confidence as num) * 100).toInt()}',
                      style: const TextStyle(
                        color: ParamedTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),

            // Heart rate - large display
            if (heartRate != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ParamedTheme.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.favorite, color: ParamedTheme.emergencyRed, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      '$heartRate',
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: ParamedTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'bpm',
                      style: TextStyle(
                        fontSize: 16,
                        color: ParamedTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Interpretation
            if (interpretation.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Interpretation:',
                style: TextStyle(
                  color: ParamedTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                interpretation,
                style: const TextStyle(
                  color: ParamedTheme.textPrimary,
                  fontSize: 14,
                ),
              ),
            ],

            // ST changes
            if (stChanges != null && stChanges.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ParamedTheme.warningOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: ParamedTheme.warningOrange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.show_chart, size: 16, color: ParamedTheme.warningOrange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ST Segment Changes',
                            style: TextStyle(
                              color: ParamedTheme.warningOrange,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            stChanges,
                            style: const TextStyle(
                              color: ParamedTheme.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Urgent action
            if (urgentAction != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ParamedTheme.emergencyRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ParamedTheme.emergencyRed),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.emergency, size: 18, color: ParamedTheme.emergencyRed),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        urgentAction,
                        style: const TextStyle(
                          color: ParamedTheme.emergencyRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Differential diagnoses
            if (differentials.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Differential Diagnoses:',
                style: TextStyle(
                  color: ParamedTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: differentials.map((d) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: ParamedTheme.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ParamedTheme.border),
                    ),
                    child: Text(
                      d,
                      style: const TextStyle(
                        color: ParamedTheme.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
