import 'package:uuid/uuid.dart';
import '../../../../core/services/file_storage_service.dart';
import '../../../../core/services/image_processing_service.dart';
import '../entities/scanned_page.dart';

/// Use case for applying filters, rotation, or perspective warping to a page.
class ProcessPageUseCase {
  const ProcessPageUseCase({
    required this.imageProcessingService,
    required this.fileStorageService,
  });

  final ImageProcessingService imageProcessingService;
  final FileStorageService fileStorageService;

  Future<ScannedPage> call({
    required ScannedPage page,
    DocumentFilterType? filterType,
    int? rotationDegrees,
    DocumentCornerPoints? corners,
  }) async {
    final effectiveFilter = filterType ?? page.filterType;
    final effectiveRotation = rotationDegrees ?? page.rotationDegrees;
    final effectiveCorners = corners ?? page.corners;

    // We start from the original high-resolution image to avoid compounding compression loss
    var currentInputPath = page.originalImagePath;

    // 1. Apply perspective rectification if corners provided
    if (effectiveCorners != null) {
      final rectifiedOutput = await fileStorageService.createTempFilePath(
        extension: 'rect_${const Uuid().v4()}.jpg',
      );
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
      currentInputPath = await imageProcessingService.rotateImage(
        inputPath: currentInputPath,
        outputPath: rotatedOutput,
        angleDegrees: effectiveRotation % 360,
      );
    }

    // 3. Apply visual filter
    final finalOutput = await fileStorageService.createTempFilePath(
      extension: 'proc_${const Uuid().v4()}.jpg',
    );
    final processedPath = await imageProcessingService.applyFilter(
      inputPath: currentInputPath,
      outputPath: finalOutput,
      filterType: effectiveFilter,
    );

    final (w, h) = await imageProcessingService.getImageDimensions(processedPath);

    return page.copyWith(
      processedImagePath: processedPath,
      filterType: effectiveFilter,
      rotationDegrees: effectiveRotation,
      corners: effectiveCorners,
      width: w,
      height: h,
    );
  }
}
