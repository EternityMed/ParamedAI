/// First-launch screen for downloading the on-device GGUF model.
///
/// Shows download progress, model size info, and allows skipping
/// (the app works online-only without the local model).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../core/inference/model_manager.dart';

class ModelDownloadScreen extends ConsumerWidget {
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  const ModelDownloadScreen({
    super.key,
    required this.onComplete,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(modelManagerProvider);

    // Auto-navigate when download completes
    ref.listen<ModelDownloadState>(modelManagerProvider, (prev, next) {
      if (next.status == ModelDownloadStatus.downloaded) {
        onComplete();
      }
    });

    return Scaffold(
      backgroundColor: ParamedTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: ParamedTheme.medicalBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.download_rounded,
                  size: 56,
                  color: ParamedTheme.medicalBlue,
                ),
              ),
              const SizedBox(height: 32),

              // Title
              const Text(
                'On-Device AI Model',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: ParamedTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                'Download the ${AppConstants.offlineModelName} model '
                'to your device for offline use.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: ParamedTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),

              // Size info
              const Text(
                'Model size: ${AppConstants.ggufModelSizeLabel}',
                style: TextStyle(
                  fontSize: 13,
                  color: ParamedTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

              // Progress / Status
              _buildStatusSection(downloadState),

              const SizedBox(height: 32),

              // Actions
              _buildActions(context, ref, downloadState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSection(ModelDownloadState state) {
    switch (state.status) {
      case ModelDownloadStatus.notDownloaded:
        return const SizedBox.shrink();

      case ModelDownloadStatus.downloading:
      case ModelDownloadStatus.paused:
        final percent = (state.progress * 100).toStringAsFixed(1);
        return Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: state.progress,
                minHeight: 8,
                backgroundColor: ParamedTheme.border,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  ParamedTheme.medicalBlue,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Downloading $percent%...',
              style: const TextStyle(
                fontSize: 13,
                color: ParamedTheme.textSecondary,
              ),
            ),
          ],
        );

      case ModelDownloadStatus.downloaded:
        return const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: ParamedTheme.safeGreen, size: 20),
            SizedBox(width: 8),
            Text(
              'Model ready!',
              style: TextStyle(
                color: ParamedTheme.safeGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );

      case ModelDownloadStatus.error:
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    color: ParamedTheme.emergencyRed, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    state.error ?? 'Unknown error',
                    style: const TextStyle(
                      color: ParamedTheme.emergencyRed,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
    }
  }

  Widget _buildActions(
    BuildContext context,
    WidgetRef ref,
    ModelDownloadState state,
  ) {
    final isDownloading = state.status == ModelDownloadStatus.downloading;

    return Column(
      children: [
        // Download button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isDownloading
                ? null
                : () {
                    ref.read(modelManagerProvider.notifier).downloadModel();
                  },
            icon: Icon(isDownloading ? Icons.hourglass_top : Icons.download),
            label: Text(
              isDownloading
                  ? 'Downloading...'
                  : state.status == ModelDownloadStatus.error
                      ? 'Retry'
                      : 'Download Model',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: ParamedTheme.medicalBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Skip button
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: isDownloading ? null : onSkip,
            child: const Text(
              'Skip (Online mode only)',
              style: TextStyle(color: ParamedTheme.textSecondary),
            ),
          ),
        ),
      ],
    );
  }
}
