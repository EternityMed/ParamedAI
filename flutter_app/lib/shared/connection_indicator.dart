import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../core/connectivity/connectivity_manager.dart';
import '../core/inference/model_manager.dart';
import 'model_badge.dart';
import 'model_management_sheet.dart';

/// Widget showing online/offline status with model badge.
/// Tapping opens the model management bottom sheet.
class ConnectionIndicator extends ConsumerWidget {
  const ConnectionIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connState = ref.watch(connectivityProvider);
    final downloadState = ref.watch(modelManagerProvider);

    // Show a subtle download indicator when downloading
    final isDownloading =
        downloadState.status == ModelDownloadStatus.downloading;

    return GestureDetector(
      onTap: () => showModelManagementSheet(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isDownloading) ...[
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                value: downloadState.progress,
                strokeWidth: 2,
                backgroundColor: ParamedTheme.border,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  ParamedTheme.medicalBlue,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          ModelBadge(
            modelName: connState.modelName,
            isOnline: connState.isOnline,
            useLocalLlama: connState.useLocalLlama,
            isModelLoaded: downloadState.status == ModelDownloadStatus.downloaded,
          ),
        ],
      ),
    );
  }
}
