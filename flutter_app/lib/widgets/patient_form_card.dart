import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Displays structured patient form data.
class PatientFormCardWidget extends StatelessWidget {
  final Map<String, dynamic> data;

  const PatientFormCardWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final patientName = data['patient_name'] as String?;
    final age = data['age'];
    final gender = data['gender'] as String?;
    final chiefComplaint = data['chief_complaint'] as String? ?? '';
    final history = data['history'] as String?;
    final vitalsSummary = data['vitals_summary'] as String?;
    final injuries = _toStringList(data['injuries']);
    final interventions = _toMapList(data['interventions']);
    final allergies = _toStringList(data['allergies']);
    final medications = _toStringList(data['medications']);

    return Card(
      color: ParamedTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: ParamedTheme.safeGreen, width: 1),
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
                    color: ParamedTheme.safeGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.assignment_ind,
                    color: ParamedTheme.safeGreen,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Patient Form',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: ParamedTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Patient demographics
            if (patientName != null || age != null || gender != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ParamedTheme.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    if (patientName != null) ...[
                      const Icon(Icons.person, size: 16, color: ParamedTheme.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        patientName,
                        style: const TextStyle(
                          color: ParamedTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    if (age != null) ...[
                      Text(
                        '$age y/o',
                        style: const TextStyle(color: ParamedTheme.textSecondary),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (gender != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: ParamedTheme.medicalBlue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          gender,
                          style: const TextStyle(
                            color: ParamedTheme.medicalBlue,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            // Chief complaint
            if (chiefComplaint.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildSection('Chief Complaint', chiefComplaint),
            ],

            // History
            if (history != null && history.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildSection('Medical History', history),
            ],

            // Vitals summary
            if (vitalsSummary != null && vitalsSummary.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildSection('Vital Signs', vitalsSummary),
            ],

            // Injuries
            if (injuries.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildListSection('Injuries', injuries, Icons.healing),
            ],

            // Allergies
            if (allergies.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ParamedTheme.emergencyRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: ParamedTheme.emergencyRed.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber, size: 16, color: ParamedTheme.emergencyRed),
                        SizedBox(width: 6),
                        Text(
                          'Allergies',
                          style: TextStyle(
                            color: ParamedTheme.emergencyRed,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: allergies.map((a) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: ParamedTheme.emergencyRed.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            a,
                            style: const TextStyle(
                              color: ParamedTheme.emergencyRed,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],

            // Medications
            if (medications.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildListSection('Current Medications', medications, Icons.medication),
            ],

            // Interventions
            if (interventions.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Interventions',
                style: TextStyle(
                  color: ParamedTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              ...interventions.map((intervention) {
                final name = intervention['name'] as String? ?? '';
                final done = intervention['done'] as bool? ?? false;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        done ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 18,
                        color: done ? ParamedTheme.safeGreen : ParamedTheme.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            color: done
                                ? ParamedTheme.textPrimary
                                : ParamedTheme.textSecondary,
                            fontSize: 14,
                            decoration: done ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: ParamedTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: const TextStyle(
            color: ParamedTheme.textPrimary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  /// Safely convert dynamic value to a string list.
  /// Handles String (split by comma), List, or null.
  static List<String> _toStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String && value.isNotEmpty) {
      return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return [];
  }

  /// Safely convert dynamic value to a list of maps.
  /// Handles String, List, or null.
  static List<Map<String, dynamic>> _toMapList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) {
        if (e is Map<String, dynamic>) return e;
        if (e is Map) return Map<String, dynamic>.from(e);
        return <String, dynamic>{'name': e.toString(), 'done': false};
      }).toList();
    }
    if (value is String && value.isNotEmpty) {
      return [<String, dynamic>{'name': value, 'done': false}];
    }
    return [];
  }

  Widget _buildListSection(String title, List<String> items, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: ParamedTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 14, color: ParamedTheme.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: ParamedTheme.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}
