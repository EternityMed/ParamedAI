import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../core/audio/stt_router.dart';
import '../../core/connectivity/connectivity_manager.dart';
import '../../shared/connection_indicator.dart';
import 'patients_controller.dart';

/// Patients screen — voice input, AI medical documentation, patient history.
class DocScreen extends ConsumerStatefulWidget {
  const DocScreen({super.key});

  @override
  ConsumerState<DocScreen> createState() => _DocScreenState();
}

class _DocScreenState extends ConsumerState<DocScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pState = ref.watch(patientsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: ParamedTheme.safeGreen.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.people, color: ParamedTheme.safeGreen, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Patients'),
          ],
        ),
        actions: const [ConnectionIndicator(), SizedBox(width: 8)],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: ParamedTheme.safeGreen,
          labelColor: ParamedTheme.textPrimary,
          unselectedLabelColor: ParamedTheme.textSecondary,
          tabs: [
            const Tab(icon: Icon(Icons.add_circle_outline, size: 20), text: 'New Patient'),
            Tab(
              icon: const Icon(Icons.history, size: 20),
              text: 'History (${pState.patients.length})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNewPatientTab(pState),
          _buildHistoryTab(pState),
        ],
      ),
    );
  }

  // ── New Patient Tab ────────────────────────────────────────────────────────

  Widget _buildNewPatientTab(PatientsState pState) {
    final sttState = ref.watch(activeSTTProvider);

    // Sync text controller with state
    if (_textController.text != pState.currentTranscription) {
      _textController.text = pState.currentTranscription;
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Voice recording section
          _buildVoiceSection(sttState),
          const SizedBox(height: 20),

          // Transcription
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Transcription',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ParamedTheme.textPrimary,
                ),
              ),
              if (pState.currentTranscription.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    ref.read(patientsControllerProvider.notifier).clearCurrent();
                    _textController.clear();
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                    foregroundColor: ParamedTheme.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            maxLines: 6,
            onChanged: (text) {
              ref.read(patientsControllerProvider.notifier).updateTranscription(text);
            },
            decoration: const InputDecoration(
              hintText: 'Patient name, age, gender, chief complaint, vital signs, medications, allergies, medical history...',
              alignLabelWithHint: true,
            ),
          ),

          // Error
          if (pState.error != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ParamedTheme.emergencyRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                pState.error!,
                style: const TextStyle(color: ParamedTheme.emergencyRed, fontSize: 13),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Generate AI Documentation button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: pState.currentTranscription.trim().isEmpty || pState.isGenerating
                  ? null
                  : () => ref.read(patientsControllerProvider.notifier).generateDocumentation(),
              icon: pState.isGenerating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(pState.isGenerating ? 'Generating...' : 'Generate AI Documentation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ParamedTheme.medicalBlue,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          // AI Documentation result
          if (pState.currentDocumentation != null) ...[
            const SizedBox(height: 20),
            _buildDocumentationCard(pState.currentDocumentation!),
            const SizedBox(height: 16),

            // ── Action Buttons: Dispatch + Send to Assistant ──
            Builder(builder: (context) {
              final isOnline = !ref.watch(connectivityProvider).useLocalLlama;
              return Row(
              children: [
                // Request Dispatch (only when server is available)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: !isOnline || pState.isDispatching
                        ? null
                        : () => ref.read(patientsControllerProvider.notifier).requestDispatch(),
                    icon: pState.isDispatching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.local_hospital, size: 18),
                    label: Text(
                      pState.isDispatching
                          ? 'Dispatching...'
                          : !isOnline
                              ? 'Dispatch (Offline)'
                              : 'Request Dispatch',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ParamedTheme.emergencyRed,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Send to Assistant
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _sendToAssistant(pState),
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text('Send to Assistant'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ParamedTheme.medicalBlue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            );
            }),

            // Dispatch Result
            if (pState.currentDispatch != null) ...[
              const SizedBox(height: 16),
              _buildDispatchResultCard(pState.currentDispatch!),
            ],

            const SizedBox(height: 16),

            // Save Patient button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await ref.read(patientsControllerProvider.notifier).saveCurrentPatient();
                  _textController.clear();
                  _tabController.animateTo(1);
                },
                icon: const Icon(Icons.save),
                label: const Text('Save Patient'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ParamedTheme.safeGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _sendToAssistant(PatientsState pState) {
    final doc = pState.currentDocumentation ?? '';
    final message =
        'Here is a patient medical documentation. Please review and advise:\n\n$doc';
    ref.read(chatNavigationProvider.notifier).state = ChatNavigationEvent(message);
  }

  // ── Documentation Card ──────────────────────────────────────────────────

  Widget _buildDocumentationCard(String documentation) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ParamedTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ParamedTheme.medicalBlue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: ParamedTheme.medicalBlue.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.description, color: ParamedTheme.medicalBlue, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Prehospital Medical Record',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ParamedTheme.medicalBlue,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatNow(),
                  style: const TextStyle(fontSize: 11, color: ParamedTheme.textSecondary),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: SelectableText(
              documentation,
              style: const TextStyle(
                color: ParamedTheme.textPrimary,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNow() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
  }

  // ── Dispatch Result Card ────────────────────────────────────────────────

  Widget _buildDispatchResultCard(DispatchResult dispatch) {
    final triageColor = _triageColor(dispatch.triageLevel);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ParamedTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: triageColor.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with triage color
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: triageColor.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.emergency, color: triageColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Dispatch Decision',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: triageColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: triageColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    dispatch.triageLevel.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hospital
                _dispatchRow(
                  icon: Icons.local_hospital,
                  iconColor: ParamedTheme.medicalBlue,
                  label: 'Hospital',
                  value: dispatch.primaryHospital,
                ),
                const SizedBox(height: 10),

                // Ambulance Team
                _dispatchRow(
                  icon: Icons.directions_car,
                  iconColor: ParamedTheme.emergencyRed,
                  label: 'Ambulance',
                  value: dispatch.primaryTeam,
                ),
                const SizedBox(height: 10),

                // ETA
                _dispatchRow(
                  icon: Icons.timer,
                  iconColor: ParamedTheme.warningOrange,
                  label: 'ETA',
                  value: '${dispatch.etaMin.toStringAsFixed(0)} min',
                ),
                const SizedBox(height: 10),

                // Urgency
                _dispatchRow(
                  icon: Icons.speed,
                  iconColor: triageColor,
                  label: 'Urgency Score',
                  value: '${dispatch.urgencyScore}/10',
                ),

                if (dispatch.clinicalReasoning.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(color: ParamedTheme.border),
                  const SizedBox(height: 8),
                  Text(
                    dispatch.clinicalReasoning,
                    style: const TextStyle(
                      fontSize: 12,
                      color: ParamedTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],

                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Pipeline: ${dispatch.pipelineTimeSec.toStringAsFixed(1)}s',
                    style: const TextStyle(fontSize: 10, color: ParamedTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dispatchRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 13,
            color: ParamedTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: ParamedTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Color _triageColor(String level) {
    switch (level.toUpperCase()) {
      case 'RED':
      case 'IMMEDIATE':
        return ParamedTheme.emergencyRed;
      case 'YELLOW':
      case 'DELAYED':
        return ParamedTheme.triageYellow;
      case 'GREEN':
      case 'MINOR':
        return ParamedTheme.safeGreen;
      case 'BLACK':
      case 'EXPECTANT':
        return ParamedTheme.triageBlack;
      default:
        return ParamedTheme.medicalBlue;
    }
  }

  // ── Voice Section ──────────────────────────────────────────────────────────

  Widget _buildVoiceSection(UnifiedSttState sttState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ParamedTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: sttState.isListening ? ParamedTheme.emergencyRed : ParamedTheme.border,
          width: sttState.isListening ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _toggleVoice,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: sttState.isListening
                    ? ParamedTheme.emergencyRed
                    : ParamedTheme.medicalBlue,
                boxShadow: sttState.isListening
                    ? [
                        BoxShadow(
                          color: ParamedTheme.emergencyRed.withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                sttState.isListening ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            sttState.isListening
                ? 'Listening... (${sttState.activeEngine == "medasr" ? "MedASR" : "Device STT"})'
                : 'Tap to start voice input',
            style: TextStyle(
              color: sttState.isListening
                  ? ParamedTheme.emergencyRed
                  : ParamedTheme.textSecondary,
              fontSize: 14,
              fontWeight: sttState.isListening ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleVoice() async {
    final sttNotifier = ref.read(activeSTTProvider.notifier);
    final sttState = ref.read(activeSTTProvider);

    if (sttState.isListening) {
      await sttNotifier.stopListening();
      final text = ref.read(activeSTTProvider).recognizedText;
      if (text.isNotEmpty) {
        ref.read(patientsControllerProvider.notifier).appendTranscription(text);
      }
    } else {
      await sttNotifier.startListening();
    }
  }

  // ── History Tab ────────────────────────────────────────────────────────────

  Widget _buildHistoryTab(PatientsState pState) {
    if (pState.patients.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 48, color: ParamedTheme.textSecondary),
            SizedBox(height: 12),
            Text(
              'No patients yet',
              style: TextStyle(color: ParamedTheme.textSecondary, fontSize: 16),
            ),
            SizedBox(height: 4),
            Text(
              'Record voice notes to create patient records',
              style: TextStyle(color: ParamedTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pState.patients.length,
      itemBuilder: (context, index) {
        final patient = pState.patients[index];
        return _buildPatientCard(patient);
      },
    );
  }

  Widget _buildPatientCard(PatientRecord patient) {
    final timeStr = '${patient.createdAt.day.toString().padLeft(2, '0')}/'
        '${patient.createdAt.month.toString().padLeft(2, '0')} '
        '${patient.createdAt.hour.toString().padLeft(2, '0')}:'
        '${patient.createdAt.minute.toString().padLeft(2, '0')}';

    final summary = patient.documentation
        .split('\n')
        .firstWhere((l) => l.trim().isNotEmpty, orElse: () => patient.transcription);

    return Dismissible(
      key: Key(patient.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: ParamedTheme.emergencyRed.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: ParamedTheme.emergencyRed),
      ),
      onDismissed: (_) {
        ref.read(patientsControllerProvider.notifier).deletePatient(patient.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: ParamedTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ParamedTheme.border),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: ParamedTheme.safeGreen.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person, color: ParamedTheme.safeGreen, size: 22),
            ),
            title: Text(
              summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: ParamedTheme.textPrimary,
              ),
            ),
            subtitle: Row(
              children: [
                Text(
                  timeStr,
                  style: const TextStyle(fontSize: 12, color: ParamedTheme.textSecondary),
                ),
                if (patient.dispatch != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: _triageColor(patient.dispatch!.triageLevel),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      patient.dispatch!.triageLevel.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            children: [
              const Divider(color: ParamedTheme.border),
              const SizedBox(height: 8),
              if (patient.documentation.isNotEmpty) ...[
                const Text(
                  'Documentation',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ParamedTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  patient.documentation,
                  style: const TextStyle(
                    fontSize: 13,
                    color: ParamedTheme.textPrimary,
                    height: 1.5,
                  ),
                ),
              ],
              if (patient.dispatch != null) ...[
                const SizedBox(height: 12),
                _buildDispatchResultCard(patient.dispatch!),
              ],
              if (patient.transcription.isNotEmpty &&
                  patient.documentation != patient.transcription) ...[
                const SizedBox(height: 12),
                const Text(
                  'Original Transcription',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ParamedTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  patient.transcription,
                  style: const TextStyle(
                    fontSize: 12,
                    color: ParamedTheme.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              // Quick actions on saved patients
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final message =
                            'Here is a patient medical documentation. Please review and advise:\n\n${patient.documentation}';
                        ref.read(chatNavigationProvider.notifier).state =
                            ChatNavigationEvent(message);
                      },
                      icon: const Icon(Icons.chat, size: 16),
                      label: const Text('Ask Assistant'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ParamedTheme.medicalBlue,
                        side: const BorderSide(color: ParamedTheme.medicalBlue),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
