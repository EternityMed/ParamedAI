import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../config/theme.dart';
import '../../widgets/triage_card.dart';
import 'triage_controller.dart';

/// Triage dashboard showing patient distribution and status.
class TriageDashboard extends ConsumerWidget {
  const TriageDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final triageState = ref.watch(triageControllerProvider);

    if (triageState.patients.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 48,
              color: ParamedTheme.textSecondary,
            ),
            SizedBox(height: 12),
            Text(
              'No triaged patients yet',
              style: TextStyle(
                color: ParamedTheme.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards
          Row(
            children: [
              _buildCountCard('Total', triageState.totalCount, ParamedTheme.medicalBlue),
              _buildCountCard('Red', triageState.redCount, ParamedTheme.triageRed),
              _buildCountCard('Yellow', triageState.yellowCount, ParamedTheme.triageYellow),
              _buildCountCard('Green', triageState.greenCount, ParamedTheme.triageGreen),
            ],
          ),
          const SizedBox(height: 20),

          // Pie chart
          if (triageState.totalCount > 0) ...[
            const Text(
              'Distribution',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: ParamedTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sections: _buildPieSections(triageState),
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Patient list
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Patients',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ParamedTheme.textPrimary,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  ref.read(triageControllerProvider.notifier).clearAll();
                },
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Clear'),
                style: TextButton.styleFrom(
                  foregroundColor: ParamedTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Sorted patient cards
          ...triageState.sortedPatients.map((patient) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Dismissible(
                key: Key(patient.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: ParamedTheme.emergencyRed.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete, color: ParamedTheme.emergencyRed),
                ),
                onDismissed: (_) {
                  ref
                      .read(triageControllerProvider.notifier)
                      .removePatient(patient.id);
                },
                child: TriageCardWidget(
                  data: {
                    'patient_id': patient.patientId,
                    'category': patient.category,
                    'gcs': patient.gcs,
                    'injuries': patient.notes,
                    'vitals': patient.vitals,
                    'timestamp': _formatTime(patient.timestamp),
                  },
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCountCard(String label, int count, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.8),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(TriageState state) {
    final sections = <PieChartSectionData>[];

    if (state.redCount > 0) {
      sections.add(PieChartSectionData(
        value: state.redCount.toDouble(),
        color: ParamedTheme.triageRed,
        title: '${state.redCount}',
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        radius: 50,
      ));
    }
    if (state.yellowCount > 0) {
      sections.add(PieChartSectionData(
        value: state.yellowCount.toDouble(),
        color: ParamedTheme.triageYellow,
        title: '${state.yellowCount}',
        titleStyle: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        radius: 50,
      ));
    }
    if (state.greenCount > 0) {
      sections.add(PieChartSectionData(
        value: state.greenCount.toDouble(),
        color: ParamedTheme.triageGreen,
        title: '${state.greenCount}',
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        radius: 50,
      ));
    }
    if (state.blackCount > 0) {
      sections.add(PieChartSectionData(
        value: state.blackCount.toDouble(),
        color: ParamedTheme.triageBlack,
        title: '${state.blackCount}',
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        radius: 50,
      ));
    }

    return sections;
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
