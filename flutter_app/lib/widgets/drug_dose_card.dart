import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Displays drug dose calculation results with safety warnings.
/// Data is always deterministic (never LLM-generated doses).
class DrugDoseCardWidget extends StatelessWidget {
  final Map<String, dynamic> data;

  const DrugDoseCardWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final drugName = data['drugName'] as String? ??
        data['drug_name'] as String? ??
        'Unknown Drug';
    final doseMg = data['dose_mg'] ?? data['dose'] ?? data['calculatedDose'];
    final doseMl = data['dose_ml'] ?? data['doseMl'];
    final route = data['route'] as String? ?? '';
    final concentration = data['concentration'] as String?;
    final maxDoseMg = data['max_dose_mg'] ?? data['maxDose'];
    final frequency = data['frequency'] as String?;
    // Handle both List<String> warnings and single String warning
    final rawWarnings = data['warnings'];
    final singleWarning = data['warning'] as String?;
    final warnings = rawWarnings is List
        ? rawWarnings.cast<String>()
        : (singleWarning != null ? [singleWarning] : <String>[]);
    final weightKg = data['weight_kg'] ?? data['weightKg'];
    final indication = data['indication'] as String?;

    return Card(
      color: ParamedTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: ParamedTheme.medicalBlue, width: 1),
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
                    color: ParamedTheme.medicalBlue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.medication,
                    color: ParamedTheme.medicalBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    drugName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ParamedTheme.textPrimary,
                    ),
                  ),
                ),
                if (route.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: ParamedTheme.medicalBlue,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      route.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Dose display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ParamedTheme.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ParamedTheme.border),
              ),
              child: Column(
                children: [
                  if (doseMg != null)
                    _buildDoseRow('Dose', _formatWithUnit(doseMg, 'mg')),
                  if (doseMl != null)
                    _buildDoseRow('Volume', _formatWithUnit(doseMl, 'mL')),
                  if (frequency != null)
                    _buildDoseRow('Frequency', frequency),
                  if (weightKg != null)
                    _buildDoseRow('Patient Weight', '$weightKg kg'),
                ],
              ),
            ),

            // Concentration
            if (concentration != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.science, size: 16, color: ParamedTheme.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    'Concentration: $concentration',
                    style: const TextStyle(
                      color: ParamedTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],

            // Indication
            if (indication != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: ParamedTheme.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Indication: $indication',
                      style: const TextStyle(
                        color: ParamedTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Max dose indicator
            if (maxDoseMg != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: ParamedTheme.warningOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: ParamedTheme.warningOrange.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.speed,
                      size: 18,
                      color: ParamedTheme.warningOrange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Maximum dose: ${_formatWithUnit(maxDoseMg, 'mg')}',
                        style: const TextStyle(
                          color: ParamedTheme.warningOrange,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Warnings
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...warnings.map((warning) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: ParamedTheme.emergencyRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: ParamedTheme.emergencyRed.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_amber,
                          size: 16,
                          color: ParamedTheme.emergencyRed,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            warning,
                            style: const TextStyle(
                              color: ParamedTheme.emergencyRed,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  /// Appends [unit] only if the value is purely numeric (no unit already present).
  static String _formatWithUnit(dynamic value, String unit) {
    final str = value.toString().trim();
    // If value is a pure number (int or double), append the unit
    if (num.tryParse(str) != null) {
      return '$str $unit';
    }
    // Already contains text/unit — return as-is
    return str;
  }

  Widget _buildDoseRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: ParamedTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: ParamedTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
