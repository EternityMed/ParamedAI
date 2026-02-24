/// Bottom sheet for managing the on-device GGUF model.
///
/// Accessible from the AppBar model badge. Supports download,
/// pause, resume, and delete operations.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
import '../config/theme.dart';
import '../core/inference/model_manager.dart';

/// Shows the model management bottom sheet.
void showModelManagementSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: ParamedTheme.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _ModelManagementContent(),
  );
}

class _ModelManagementContent extends ConsumerWidget {
  const _ModelManagementContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(modelManagerProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ParamedTheme.textSecondary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Title row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ParamedTheme.medicalBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.memory,
                  color: ParamedTheme.medicalBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'On-Device AI Model',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: ParamedTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '${AppConstants.offlineModelName} (${AppConstants.ggufModelSizeLabel})',
                      style: TextStyle(
                        fontSize: 12,
                        color: ParamedTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusChip(state),
            ],
          ),
          const SizedBox(height: 16),

          // Description
          const Text(
            'Download this model to use the AI assistant without internet. '
            'Text-based clinical decision support runs on-device.',
            style: TextStyle(
              fontSize: 13,
              color: ParamedTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Progress bar (downloading or paused)
          if (state.status == ModelDownloadStatus.downloading ||
              state.status == ModelDownloadStatus.paused)
            _buildProgressSection(state),

          // Error message
          if (state.status == ModelDownloadStatus.error) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ParamedTheme.emergencyRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: ParamedTheme.emergencyRed.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: ParamedTheme.emergencyRed, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.error ?? 'Unknown error',
                      style: const TextStyle(
                        color: ParamedTheme.emergencyRed,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Action buttons
          const SizedBox(height: 4),
          _buildActions(context, ref, state),

          // Bottom safe area
          SizedBox(height: MediaQuery.of(context).viewPadding.bottom),
        ],
      ),
    );
  }

  Widget _buildStatusChip(ModelDownloadState state) {
    final Color color;
    final String label;

    switch (state.status) {
      case ModelDownloadStatus.downloaded:
        color = ParamedTheme.safeGreen;
        label = 'Ready';
      case ModelDownloadStatus.downloading:
        color = ParamedTheme.medicalBlue;
        label = 'Downloading';
      case ModelDownloadStatus.paused:
        color = ParamedTheme.warningOrange;
        label = 'Paused';
      case ModelDownloadStatus.error:
        color = ParamedTheme.emergencyRed;
        label = 'Error';
      case ModelDownloadStatus.notDownloaded:
        color = ParamedTheme.textSecondary;
        label = 'Not Downloaded';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildProgressSection(ModelDownloadState state) {
    final percent = (state.progress * 100).toStringAsFixed(1);
    final isPaused = state.status == ModelDownloadStatus.paused;
    final fileLabel = state.downloadingFile ?? '';

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: state.progress,
            minHeight: 6,
            backgroundColor: ParamedTheme.border,
            valueColor: AlwaysStoppedAnimation<Color>(
              isPaused ? ParamedTheme.warningOrange : ParamedTheme.medicalBlue,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isPaused
              ? '$percent% - Paused'
              : '$percent% downloading $fileLabel...',
          style: const TextStyle(
            fontSize: 12,
            color: ParamedTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildActions(
    BuildContext context,
    WidgetRef ref,
    ModelDownloadState state,
  ) {
    final manager = ref.read(modelManagerProvider.notifier);

    switch (state.status) {
      case ModelDownloadStatus.notDownloaded:
        return _actionButton(
          icon: Icons.download_rounded,
          label: 'Download Model',
          color: ParamedTheme.medicalBlue,
          onPressed: () => manager.downloadModel(),
        );

      case ModelDownloadStatus.downloading:
        return _actionButton(
          icon: Icons.pause_rounded,
          label: 'Pause',
          color: ParamedTheme.warningOrange,
          onPressed: () => manager.pauseDownload(),
        );

      case ModelDownloadStatus.paused:
        return Row(
          children: [
            Expanded(
              child: _actionButton(
                icon: Icons.play_arrow_rounded,
                label: 'Resume',
                color: ParamedTheme.medicalBlue,
                onPressed: () => manager.downloadModel(),
              ),
            ),
            const SizedBox(width: 8),
            _actionButton(
              icon: Icons.delete_outline,
              label: 'Delete',
              color: ParamedTheme.emergencyRed,
              outlined: true,
              onPressed: () => _confirmDelete(context, manager),
            ),
          ],
        );

      case ModelDownloadStatus.downloaded:
        return _actionButton(
          icon: Icons.delete_outline,
          label: 'Delete Model',
          color: ParamedTheme.emergencyRed,
          outlined: true,
          onPressed: () => _confirmDelete(context, manager),
        );

      case ModelDownloadStatus.error:
        return Row(
          children: [
            Expanded(
              child: _actionButton(
                icon: Icons.refresh_rounded,
                label: 'Retry',
                color: ParamedTheme.medicalBlue,
                onPressed: () => manager.downloadModel(),
              ),
            ),
            const SizedBox(width: 8),
            _actionButton(
              icon: Icons.delete_outline,
              label: 'Delete',
              color: ParamedTheme.emergencyRed,
              outlined: true,
              onPressed: () => manager.deleteModel(),
            ),
          ],
        );
    }
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    bool outlined = false,
  }) {
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, ModelManager manager) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ParamedTheme.card,
        title: const Text('Delete Model'),
        content: const Text(
          'The on-device AI model will be deleted. '
          'Offline mode will be unavailable. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              manager.deleteModel();
              Navigator.of(ctx).pop();
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: ParamedTheme.emergencyRed),
            ),
          ),
        ],
      ),
    );
  }
}
