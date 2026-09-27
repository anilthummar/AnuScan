import 'package:uuid/uuid.dart';
import '../../../../core/services/file_storage_service.dart';
import '../../../../core/services/image_processing_service.dart';
import '../entities/scanned_page.dart';

/// Use case for editing an individual [ScanPage] (Crop/Perspective, Rotation, Visual Filters).
///
/// Ensures the raw source image [page.originalImagePath] is never overwritten,
/// applying operations in a lossless pipeline and saving to a fresh [processedImagePath].
class EditScanPageUseCase {
  const EditScanPageUseCase({
    required this.imageProcessingService,
    required this.fileStorageService,
  });

  final ImageProcessingService imageProcessingService;
  final FileStorageService fileStorageService;

  Future<ScanPage> call({
    required ScanPage page,
    ScanFilter? filterType,
    int? rotationDegrees,
    CropCorners? corners,
    BwIntensity bwIntensity = BwIntensity.medium,
  }) async {
    final effectiveFilter = filterType ?? page.filterType;
    final effectiveRotation = rotationDegrees ?? page.rotationDegrees;
    final effectiveCorners = corners ?? page.corners;

    // We start from the original high-resolution image to avoid compounding compression loss
    var currentInputPath = page.originalImagePath;
    final intermediateFiles = <String>[];
    String? finalOutput;
    var success = false;

    try {
      // 1. Apply perspective rectification if corners provided and not full bounds
      if (effectiveCorners != null && !effectiveCorners.isFullBounds) {
        final rectifiedOutput = await fileStorageService.createTempFilePath(
          extension: 'rect_${const Uuid().v4()}.jpg',
        );
        intermediateFiles.add(rectifiedOutput);
        currentInputPath = await imageProcessingService.rectifyPerspective(
          inputPath: currentInputPath,
          outputPath: rectifiedOutput,
          corners: effectiveCorners,
        );
      }

      // 2. Apply rotation if any
      if (effectiveRotation % 360 != 0) {
        final rotatedOutput = await fileStorageService.createTempFilePath(
          extension: 'rot_${const Uuid().v4()}.jpg',
        );
        intermediateFiles.add(rotatedOutput);
        currentInputPath = await imageProcessingService.rotateImage(
          inputPath: currentInputPath,
          outputPath: rotatedOutput,
          angleDegrees: effectiveRotation % 360,
        );
      }

      // 3. Apply visual filter
      finalOutput = await fileStorageService.createTempFilePath(
        extension: 'proc_${const Uuid().v4()}.jpg',
      );
      final processedPath = await imageProcessingService.applyFilter(
        inputPath: currentInputPath,
        outputPath: finalOutput,
        filterType: effectiveFilter,
        bwIntensity: bwIntensity,
      );

      final (w, h) = await imageProcessingService.getImageDimensions(
        processedPath,
      );

      success = true;
      return page.copyWith(
        processedImagePath: processedPath,
        filterType: effectiveFilter,
        rotationDegrees: effectiveRotation,
        corners: effectiveCorners,
        width: w > 0 ? w : page.width,
        height: h > 0 ? h : page.height,
      );
    } finally {
      for (final path in intermediateFiles) {
        await fileStorageService.deleteFile(path);
      }
      if (!success && finalOutput != null) {
        await fileStorageService.deleteFile(finalOutput);
      }
    }
  }
}
