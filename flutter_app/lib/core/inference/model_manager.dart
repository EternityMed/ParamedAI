/// Manages GGUF model and mmproj file download, storage, and lifecycle.
///
/// Downloads both the main model and vision projector from HuggingFace.
/// Supports resume on interrupted downloads and pause/cancel.
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../config/constants.dart';

/// Download state for UI binding.
enum ModelDownloadStatus {
  notDownloaded,
  downloading,
  paused,
  downloaded,
  error,
}

class ModelDownloadState {
  final ModelDownloadStatus status;
  final double progress; // 0.0 – 1.0
  final String? error;
  final String? downloadingFile; // Which file is being downloaded

  const ModelDownloadState({
    this.status = ModelDownloadStatus.notDownloaded,
    this.progress = 0.0,
    this.error,
    this.downloadingFile,
  });

  ModelDownloadState copyWith({
    ModelDownloadStatus? status,
    double? progress,
    String? error,
    String? downloadingFile,
  }) {
    return ModelDownloadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error,
      downloadingFile: downloadingFile ?? this.downloadingFile,
    );
  }
}

// Total size for progress calculation (main model only, no mmproj)
const int _mainModelBytes = 2830000000; // ~2.83 GB

class ModelManager extends StateNotifier<ModelDownloadState> {
  final Dio _dio;
  CancelToken? _cancelToken;

  ModelManager()
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 30),
        )),
        super(const ModelDownloadState()) {
    _checkModelStatus();
  }

  Future<void> _checkModelStatus() async {
    final ready = await isModelDownloaded();
    if (ready) {
      state = state.copyWith(
        status: ModelDownloadStatus.downloaded,
        progress: 1.0,
      );
    }
  }

  /// Directory where models are stored.
  Future<String> getModelDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${appDir.path}/models');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    return modelDir.path;
  }

  /// Full path to the main GGUF model file.
  Future<String> getModelPath() async {
    final dir = await getModelDir();
    return '$dir/${AppConstants.ggufModelFileName}';
  }

  /// Check if the model file exists and is valid.
  Future<bool> _isMainModelReady() async {
    try {
      final path = await getModelPath();
      final file = File(path);
      if (!await file.exists()) return false;
      final size = await file.length();
      return size > 1.5 * 1024 * 1024 * 1024; // > 1.5 GB
    } catch (_) {
      return false;
    }
  }

  /// Check if the model is downloaded and valid.
  Future<bool> isModelDownloaded() async {
    return await _isMainModelReady();
  }

  /// Download both model files from HuggingFace with resume support.
  Future<void> downloadModel() async {
    _cancelToken = CancelToken();

    state = state.copyWith(
      status: ModelDownloadStatus.downloading,
      progress: 0.0,
      error: null,
    );

    try {
      // Download main model (0% – 100%)
      final mainReady = await _isMainModelReady();
      if (!mainReady) {
        final mainPath = await getModelPath();
        await _downloadFile(
          url: AppConstants.ggufModelUrl,
          savePath: mainPath,
          label: 'Model',
          progressStart: 0.0,
          progressEnd: 1.0,
        );
      }

      // Verify both files
      if (await isModelDownloaded()) {
        state = state.copyWith(
          status: ModelDownloadStatus.downloaded,
          progress: 1.0,
          downloadingFile: null,
        );
      } else {
        state = state.copyWith(
          status: ModelDownloadStatus.error,
          error: 'Download completed but files could not be verified.',
        );
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        state = state.copyWith(status: ModelDownloadStatus.paused);
        return;
      }
      state = state.copyWith(
        status: ModelDownloadStatus.error,
        error: 'Download error: ${e.message}',
      );
    } catch (e) {
      state = state.copyWith(
        status: ModelDownloadStatus.error,
        error: 'Unexpected error: $e',
      );
    } finally {
      _cancelToken = null;
    }
  }

  /// Download a single file with resume support and progress mapping.
  Future<void> _downloadFile({
    required String url,
    required String savePath,
    required String label,
    required double progressStart,
    required double progressEnd,
  }) async {
    final file = File(savePath);
    int downloadedBytes = 0;
    if (await file.exists()) {
      downloadedBytes = await file.length();
    }

    state = state.copyWith(downloadingFile: label);

    await _dio.download(
      url,
      savePath,
      cancelToken: _cancelToken,
      options: Options(
        headers: downloadedBytes > 0
            ? {'Range': 'bytes=$downloadedBytes-'}
            : null,
      ),
      deleteOnError: false,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          final fileProgress =
              (received + downloadedBytes) / (total + downloadedBytes);
          final range = progressEnd - progressStart;
          final overall = progressStart + (fileProgress * range);
          state = state.copyWith(progress: overall.clamp(0.0, 1.0));
        }
      },
    );
  }

  /// Pause an active download. Partial files are kept for resume.
  void pauseDownload() {
    _cancelToken?.cancel('User paused');
  }

  /// Delete downloaded model file to free space.
  Future<void> deleteModel() async {
    try {
      final modelPath = await getModelPath();

      final modelFile = File(modelPath);
      if (await modelFile.exists()) await modelFile.delete();

      state = const ModelDownloadState();
    } catch (e) {
      state = state.copyWith(
        status: ModelDownloadStatus.error,
        error: 'Silme hatasi: $e',
      );
    }
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }
}

/// Riverpod provider for model manager.
final modelManagerProvider =
    StateNotifierProvider<ModelManager, ModelDownloadState>(
  (ref) => ModelManager(),
);
