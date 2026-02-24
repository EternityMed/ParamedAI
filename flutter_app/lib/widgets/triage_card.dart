import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Displays START triage classification for a patient.
class TriageCardWidget extends StatelessWidget {
  final Map<String, dynamic> data;

  const TriageCardWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final patientId = data['patientId'] as String? ??
        data['patient_id'] as String? ?? '-';
    final category = (data['category'] as String? ?? 'UNKNOWN').toUpperCase();
    final categoryLabel = data['categoryLabel'] as String? ??
        data['category_label'] as String? ?? _categoryLabel(category);
    final recommendedAction = data['recommendedAction'] as String? ??
        data['recommended_action'] as String? ??
        data['action'] as String?;
    final timestamp = data['timestamp'] as String?;
    final color = ParamedTheme.triageColor(category);

    // Parse vitals — could be Map, String, or null
    final rawVitals = data['vitals'];
    Map<String, dynamic>? vitalsMap;
    String? vitalsText;
    if (rawVitals is Map<String, dynamic>) {
      vitalsMap = rawVitals;
    } else if (rawVitals is Map) {
      vitalsMap = Map<String, dynamic>.from(rawVitals);
    } else if (rawVitals is String && rawVitals.isNotEmpty) {
      vitalsText = rawVitals;
    }

    // Parse GCS — could be int, String, or null
    final rawGcs = data['gcs'] ?? vitalsMap?['gcs'];
    int? gcsValue;
    if (rawGcs is int) {
      gcsValue = rawGcs;
    } else if (rawGcs is String) {
      gcsValue = int.tryParse(rawGcs.replaceAll(RegExp(r'[^0-9]'), ''));
    }

    // Parse injuries — could be List<String>, String, or null
    final rawInjuries = data['injuries'];
    String? injuriesText;
    if (rawInjuries is List) {
      final items = rawInjuries.whereType<String>().where((s) => s.isNotEmpty).toList();
      if (items.isNotEmpty) injuriesText = items.join(', ');
    } else if (rawInjuries is String && rawInjuries.isNotEmpty) {
      injuriesText = rawInjuries;
    }

    return Card(
      color: ParamedTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with triage color
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.person, color: ParamedTheme.textPrimary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Patient: $patientId',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: ParamedTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Category badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    categoryLabel.toUpperCase(),
                    style: TextStyle(
                      color: category == 'YELLOW' || category == 'SARI'
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vitals as structured chips
                if (vitalsMap != null) ...[
                  Row(
                    children: [
                      if (_hasVital(vitalsMap, ['pulse', 'hr']))
                        _buildVitalChip(Icons.favorite, 'HR', _getVital(vitalsMap, ['pulse', 'hr'])),
                      if (_hasVital(vitalsMap, ['respiration', 'rr']))
                        _buildVitalChip(Icons.air, 'RR', _getVital(vitalsMap, ['respiration', 'rr'])),
                      if (_hasVital(vitalsMap, ['bp', 'blood_pressure']))
                        _buildVitalChip(Icons.speed, 'BP', _getVital(vitalsMap, ['bp', 'blood_pressure'])),
                      if (_hasVital(vitalsMap, ['spo2']))
                        _buildVitalChip(Icons.water_drop, 'SpO2', _getVital(vitalsMap, ['spo2'])),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Vitals as plain text (when AI returns a string)
                if (vitalsText != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.monitor_heart, size: 16, color: ParamedTheme.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          vitalsText,
                          style: const TextStyle(
                            color: ParamedTheme.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // GCS
                if (gcsValue != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.psychology, size: 16, color: ParamedTheme.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        'GCS: $gcsValue/15',
                        style: TextStyle(
                          color: gcsValue <= 8
                              ? ParamedTheme.emergencyRed
                              : ParamedTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // Injuries
                if (injuriesText != null) ...[
                  const Text(
                    'Injuries:',
                    style: TextStyle(
                      color: ParamedTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    injuriesText,
                    style: const TextStyle(
                      color: ParamedTheme.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Recommended action
                if (recommendedAction != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.arrow_forward, size: 16, color: color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            recommendedAction,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Timestamp
                if (timestamp != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    timestamp,
                    style: const TextStyle(
                      color: ParamedTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _hasVital(Map<String, dynamic> vitals, List<String> keys) {
    for (final key in keys) {
      if (vitals[key] != null) return true;
    }
    return false;
  }

  String _getVital(Map<String, dynamic> vitals, List<String> keys) {
    for (final key in keys) {
      final val = vitals[key];
      if (val != null) return '$val';
    }
    return '-';
  }

  Widget _buildVitalChip(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: ParamedTheme.background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14, color: ParamedTheme.textSecondary),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: ParamedTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              label,
              style: const TextStyle(
                color: ParamedTheme.textSecondary,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _categoryLabel(String category) {
    switch (category.toUpperCase()) {
      case 'RED':
        return 'Immediate';
      case 'YELLOW':
        return 'Delayed';
      case 'GREEN':
        return 'Minor';
      case 'BLACK':
        return 'Expectant';
      default:
        return category;
    }
  }
}
