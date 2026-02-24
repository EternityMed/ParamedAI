import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Displays a grid of patient vital signs with trend indicators.
/// Handles both structured (nested Map) and flat (string/int) vital data.
class VitalSignsCardWidget extends StatelessWidget {
  final Map<String, dynamic> data;

  const VitalSignsCardWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final trending = data['trending'] as String?;
    final timestamp = data['timestamp'] as String?;

    // Build vital tiles from whatever format the data comes in
    final tiles = <Widget>[];

    // Blood pressure
    final bpVal = _extractVital(data, ['blood_pressure', 'bp']);
    if (bpVal != null) {
      tiles.add(_buildVitalTile(
        icon: Icons.speed,
        label: 'BP',
        value: bpVal.display,
        unit: 'mmHg',
        trend: bpVal.trend ?? trending,
        isAbnormal: false,
      ));
    }

    // Heart rate
    final hrVal = _extractVital(data, ['heart_rate', 'hr']);
    if (hrVal != null) {
      final numVal = int.tryParse(hrVal.display);
      tiles.add(_buildVitalTile(
        icon: Icons.favorite,
        label: 'HR',
        value: hrVal.display,
        unit: 'bpm',
        trend: hrVal.trend ?? trending,
        isAbnormal: numVal != null && (numVal < 60 || numVal > 100),
      ));
    }

    // Respiratory rate
    final rrVal = _extractVital(data, ['respiratory_rate', 'rr']);
    if (rrVal != null) {
      final numVal = int.tryParse(rrVal.display);
      tiles.add(_buildVitalTile(
        icon: Icons.air,
        label: 'RR',
        value: rrVal.display,
        unit: '/min',
        trend: rrVal.trend ?? trending,
        isAbnormal: numVal != null && (numVal < 12 || numVal > 20),
      ));
    }

    // SpO2
    final spo2Val = _extractVital(data, ['spo2']);
    if (spo2Val != null) {
      final numVal = int.tryParse(spo2Val.display);
      tiles.add(_buildVitalTile(
        icon: Icons.water_drop,
        label: 'SpO2',
        value: spo2Val.display,
        unit: '%',
        trend: spo2Val.trend ?? trending,
        isAbnormal: numVal != null && numVal < 94,
      ));
    }

    // Temperature
    final tempVal = _extractVital(data, ['temperature', 'temp']);
    if (tempVal != null) {
      final numVal = double.tryParse(tempVal.display);
      tiles.add(_buildVitalTile(
        icon: Icons.thermostat,
        label: 'Temp',
        value: tempVal.display,
        unit: '\u00B0C',
        trend: tempVal.trend ?? trending,
        isAbnormal: numVal != null && (numVal < 36.0 || numVal > 38.0),
      ));
    }

    // GCS
    final gcsVal = _extractVital(data, ['gcs']);
    if (gcsVal != null) {
      final numVal = int.tryParse(gcsVal.display);
      tiles.add(_buildVitalTile(
        icon: Icons.psychology,
        label: 'GCS',
        value: gcsVal.display,
        unit: '/15',
        trend: gcsVal.trend ?? trending,
        isAbnormal: numVal != null && numVal < 15,
      ));
    }

    // Pain
    final painVal = _extractVital(data, ['pain_score', 'pain']);

    return Card(
      color: ParamedTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: ParamedTheme.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.monitor_heart_outlined,
                    color: ParamedTheme.safeGreen, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Vital Signs',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: ParamedTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                if (timestamp != null)
                  Text(
                    timestamp,
                    style: const TextStyle(
                      color: ParamedTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Vitals grid
            if (tiles.isNotEmpty)
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.1,
                children: tiles,
              )
            else
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No vital signs recorded yet',
                    style: TextStyle(
                      color: ParamedTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),

            // Pain score bar
            if (painVal != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Pain Score',
                style: TextStyle(
                  color: ParamedTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Builder(builder: (context) {
                final score = int.tryParse(painVal.display) ?? 0;
                return Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: score / 10.0,
                          minHeight: 12,
                          backgroundColor: ParamedTheme.background,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _painColor(score),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$score/10',
                      style: TextStyle(
                        color: _painColor(score),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVitalTile({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    String? trend,
    bool isAbnormal = false,
  }) {
    final color = isAbnormal ? ParamedTheme.emergencyRed : ParamedTheme.textPrimary;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isAbnormal
            ? ParamedTheme.emergencyRed.withValues(alpha: 0.1)
            : ParamedTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isAbnormal
              ? ParamedTheme.emergencyRed.withValues(alpha: 0.5)
              : ParamedTheme.border,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              if (trend != null) ...[
                const SizedBox(width: 4),
                _buildTrendIcon(trend),
              ],
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          Text(
            unit,
            style: const TextStyle(
              color: ParamedTheme.textSecondary,
              fontSize: 10,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: ParamedTheme.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendIcon(String trend) {
    switch (trend.toUpperCase()) {
      case 'UP':
        return const Icon(Icons.trending_up, size: 14, color: ParamedTheme.emergencyRed);
      case 'DOWN':
        return const Icon(Icons.trending_down, size: 14, color: ParamedTheme.warningOrange);
      case 'STABLE':
        return const Icon(Icons.trending_flat, size: 14, color: ParamedTheme.safeGreen);
      default:
        return const SizedBox.shrink();
    }
  }

  Color _painColor(int score) {
    if (score <= 3) return ParamedTheme.safeGreen;
    if (score <= 6) return ParamedTheme.triageYellow;
    return ParamedTheme.emergencyRed;
  }
}

/// Extracted vital sign value.
class _VitalValue {
  final String display;
  final String? trend;
  _VitalValue(this.display, this.trend);
}

/// Extract a vital sign from data, trying multiple key names.
/// Handles both nested Map format and flat string/int values.
/// Returns null if value is missing or a placeholder like "To be assessed".
_VitalValue? _extractVital(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final val = data[key];
    if (val == null) continue;

    if (val is Map<String, dynamic>) {
      // Nested format: {value: 120, trend: "UP"} or {systolic: 120, diastolic: 80}
      if (val.containsKey('systolic')) {
        return _VitalValue(
          '${val['systolic'] ?? '-'}/${val['diastolic'] ?? '-'}',
          val['trend'] as String?,
        );
      }
      final v = val['value'];
      if (v != null) {
        return _VitalValue('$v', val['trend'] as String?);
      }
    } else if (val is int || val is double) {
      return _VitalValue('$val', null);
    } else if (val is String) {
      // Skip placeholder strings
      final lower = val.toLowerCase();
      if (lower.contains('assess') || lower.contains('pending') || lower == '-' || lower.isEmpty) {
        continue;
      }
      return _VitalValue(val, null);
    }
  }
  return null;
}
