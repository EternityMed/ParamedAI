import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../shared/connection_indicator.dart';
import 'quick_triage_buttons.dart';
import 'triage_dashboard.dart';
import 'triage_controller.dart';

/// Triage tab with START triage quick entry and dashboard.
class TriageScreen extends ConsumerStatefulWidget {
  const TriageScreen({super.key});

  @override
  ConsumerState<TriageScreen> createState() => _TriageScreenState();
}

class _TriageScreenState extends ConsumerState<TriageScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Triage question states
  bool _canWalk = false;
  bool _hasBreathing = false;
  bool _hasPulse = false;
  bool _followsCommands = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final triageState = ref.watch(triageControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: ParamedTheme.triageRed.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.emergency,
                color: ParamedTheme.triageRed,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Triage System'),
          ],
        ),
        actions: const [
          ConnectionIndicator(),
          SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: ParamedTheme.emergencyRed,
          labelColor: ParamedTheme.textPrimary,
          unselectedLabelColor: ParamedTheme.textSecondary,
          tabs: [
            const Tab(
              icon: Icon(Icons.touch_app, size: 20),
              text: 'Quick Triage',
            ),
            Tab(
              icon: const Icon(Icons.dashboard, size: 20),
              text: 'Dashboard (${triageState.totalCount})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Quick triage tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const QuickTriageButtons(),
                const SizedBox(height: 24),
                _buildQuickTriageForm(context),
              ],
            ),
          ),

          // Dashboard tab
          const TriageDashboard(),
        ],
      ),
    );
  }

  Widget _buildQuickTriageForm(BuildContext context) {
    final notesController = TextEditingController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: ParamedTheme.border),
        const SizedBox(height: 12),
        const Text(
          'Detailed Triage',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: ParamedTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'AI-assisted triage classification',
          style: TextStyle(
            color: ParamedTheme.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),

        // Walking checkbox
        _buildTriageCheck(
          'Can the patient walk?',
          Icons.directions_walk,
          _canWalk,
          (v) => setState(() => _canWalk = v ?? false),
        ),

        // Breathing checkbox
        _buildTriageCheck(
          'Is the patient breathing?',
          Icons.air,
          _hasBreathing,
          (v) => setState(() => _hasBreathing = v ?? false),
        ),

        // Pulse checkbox
        _buildTriageCheck(
          'Is radial pulse present?',
          Icons.favorite,
          _hasPulse,
          (v) => setState(() => _hasPulse = v ?? false),
        ),

        // Mental status
        _buildTriageCheck(
          'Does the patient follow commands?',
          Icons.psychology,
          _followsCommands,
          (v) => setState(() => _followsCommands = v ?? false),
        ),

        const SizedBox(height: 12),
        TextField(
          controller: notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Additional notes...',
            prefixIcon: Icon(Icons.note_add),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: Consumer(
            builder: (context, ref, _) {
              final isClassifying =
                  ref.watch(triageControllerProvider).isClassifying;
              return ElevatedButton.icon(
                onPressed: isClassifying
                    ? null
                    : () => _classifyByStart(notesController.text),
                icon: isClassifying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.assessment),
                label: Text(
                    isClassifying ? 'AI Analyzing...' : 'Classify with AI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ParamedTheme.emergencyRed,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// AI-assisted START triage classification.
  Future<void> _classifyByStart(String notes) async {
    await ref.read(triageControllerProvider.notifier).aiTriage(
          canWalk: _canWalk,
          hasBreathing: _hasBreathing,
          hasPulse: _hasPulse,
          followsCommands: _followsCommands,
          notes: notes.isNotEmpty ? notes : null,
        );

    // Reset form
    setState(() {
      _canWalk = false;
      _hasBreathing = false;
      _hasPulse = false;
      _followsCommands = false;
    });

    // Navigate to dashboard
    _tabController.animateTo(1);
  }

  Widget _buildTriageCheck(
    String question,
    IconData icon,
    bool value,
    ValueChanged<bool?> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ParamedTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: value ? ParamedTheme.safeGreen : ParamedTheme.border,
        ),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        title: Text(
          question,
          style: const TextStyle(
            color: ParamedTheme.textPrimary,
            fontSize: 14,
          ),
        ),
        secondary: Icon(icon, color: ParamedTheme.textSecondary, size: 22),
        controlAffinity: ListTileControlAffinity.trailing,
        activeColor: ParamedTheme.safeGreen,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
