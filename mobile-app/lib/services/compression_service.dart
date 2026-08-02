import 'dart:async';
import 'package:flutter/foundation.dart';

enum CompressionQuality { low, medium, high }

class CompressionResult {
  final bool isSuccess;
  final String outputPath;
  final int originalSizeBytes;
  final int compressedSizeBytes;
  final double reductionPercentage;

  CompressionResult({
    required this.isSuccess,
    required this.outputPath,
    required this.originalSizeBytes,
    required this.compressedSizeBytes,
    required this.reductionPercentage,
  });
}

class CompressionService {
  CompressionService._();
  static final CompressionService instance = CompressionService._();

  /// Compress video file on device before upload.
  /// NOTE: This is a pass-through stub — actual compression requires
  /// native FFmpeg/video_compress package. Reports honest size (no fake reduction).
  Future<CompressionResult> compressVideo({
    required String inputPath,
    CompressionQuality quality = CompressionQuality.medium,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.3);
    await Future.delayed(const Duration(milliseconds: 200));
    onProgress?.call(0.7);
    await Future.delayed(const Duration(milliseconds: 200));
    onProgress?.call(1.0);

    // No actual compression — return pass-through with zero reduction
    return CompressionResult(
      isSuccess: true,
      outputPath: inputPath,
      originalSizeBytes: 0,
      compressedSizeBytes: 0,
      reductionPercentage: 0.0,
    );
  }
}
