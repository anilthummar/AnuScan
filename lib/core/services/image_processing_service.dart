import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../errors/exceptions.dart';

/// Supported visual filters for scanned documents.
enum DocumentFilterType {
  original,
  color,
  grayscale,
  blackAndWhite,
  enhanced,
}

extension DocumentFilterTypeExtension on DocumentFilterType {
  String get displayName {
    switch (this) {
      case DocumentFilterType.original:
        return 'Original';
      case DocumentFilterType.color:
        return 'Color';
      case DocumentFilterType.grayscale:
        return 'Grayscale';
      case DocumentFilterType.blackAndWhite:
        return 'B & W';
      case DocumentFilterType.enhanced:
        return 'Enhanced';
    }
  }

  static DocumentFilterType fromString(String val) {
    return DocumentFilterType.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => DocumentFilterType.original,
    );
  }
}

/// Normalized 4-corner perspective coordinates (0.0 to 1.0 or pixel coordinates).
class DocumentCornerPoints {
  const DocumentCornerPoints({
    required this.topLeftX,
    required this.topLeftY,
    required this.topRightX,
    required this.topRightY,
    required this.bottomLeftX,
    required this.bottomLeftY,
    required this.bottomRightX,
    required this.bottomRightY,
  });

  final double topLeftX;
  final double topLeftY;
  final double topRightX;
  final double topRightY;
  final double bottomLeftX;
  final double bottomLeftY;
  final double bottomRightX;
  final double bottomRightY;

  /// Default full bounds (0,0 to 1,1)
  factory DocumentCornerPoints.fullBounds() {
    return const DocumentCornerPoints(
      topLeftX: 0.0,
      topLeftY: 0.0,
      topRightX: 1.0,
      topRightY: 0.0,
      bottomLeftX: 0.0,
      bottomLeftY: 1.0,
      bottomRightX: 1.0,
      bottomRightY: 1.0,
    );
  }
}

/// Abstract service for processing images (perspective correction, filtering, rotating, thumbnailing).
abstract class ImageProcessingService {
  /// Rotates an image by [angleDegrees] (e.g. 90, 180, 270) and saves the result to [outputPath].
  Future<String> rotateImage({
    required String inputPath,
    required String outputPath,
    required int angleDegrees,
  });

  /// Applies a [DocumentFilterType] to an image and saves to [outputPath].
  Future<String> applyFilter({
    required String inputPath,
    required String outputPath,
    required DocumentFilterType filterType,
  });

  /// Warps/rectifies a quadrilateral corner perspective region and saves to [outputPath].
  Future<String> rectifyPerspective({
    required String inputPath,
    required String outputPath,
    required DocumentCornerPoints corners,
  });

  /// Generates a downsampled thumbnail image and saves to [outputPath].
  Future<String> generateThumbnail({
    required String inputPath,
    required String outputPath,
    int targetWidth = 300,
  });

  /// Retrieves dimensions (width, height) of an image file.
  Future<(int width, int height)> getImageDimensions(String imagePath);
}

/// Concrete implementation of [ImageProcessingService] executing CPU-heavy tasks in isolates.
class ImageProcessingServiceImpl implements ImageProcessingService {
  const ImageProcessingServiceImpl();

  @override
  Future<String> rotateImage({
    required String inputPath,
    required String outputPath,
    required int angleDegrees,
  }) async {
    try {
      final params = _RotateParams(
        inputPath: inputPath,
        outputPath: outputPath,
        angleDegrees: angleDegrees,
      );
      return await compute(_rotateIsolate, params);
    } catch (e) {
      throw ImageProcessingException('Failed to rotate image: $e', e);
    }
  }

  @override
  Future<String> applyFilter({
    required String inputPath,
    required String outputPath,
    required DocumentFilterType filterType,
  }) async {
    try {
      if (filterType == DocumentFilterType.original) {
        // Direct file copy is instant and lossless
        final source = File(inputPath);
        await source.copy(outputPath);
        return outputPath;
      }

      final params = _FilterParams(
        inputPath: inputPath,
        outputPath: outputPath,
        filterType: filterType,
      );
      return await compute(_filterIsolate, params);
    } catch (e) {
      throw ImageProcessingException('Failed to apply filter: $e', e);
    }
  }

  @override
  Future<String> rectifyPerspective({
    required String inputPath,
    required String outputPath,
    required DocumentCornerPoints corners,
  }) async {
    try {
      final params = _RectifyParams(
        inputPath: inputPath,
        outputPath: outputPath,
        corners: corners,
      );
      return await compute(_rectifyIsolate, params);
    } catch (e) {
      throw ImageProcessingException('Failed to rectify image perspective: $e', e);
    }
  }

  @override
  Future<String> generateThumbnail({
    required String inputPath,
    required String outputPath,
    int targetWidth = 300,
  }) async {
    try {
      final params = _ThumbnailParams(
        inputPath: inputPath,
        outputPath: outputPath,
        targetWidth: targetWidth,
      );
      return await compute(_thumbnailIsolate, params);
    } catch (e) {
      throw ImageProcessingException('Failed to generate thumbnail: $e', e);
    }
  }

  @override
  Future<(int width, int height)> getImageDimensions(String imagePath) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return (0, 0);
      }
      return (decoded.width, decoded.height);
    } catch (e) {
      return (0, 0);
    }
  }
}

// ---------------------------------------------------------------------------
// Isolate parameter classes and workers
// ---------------------------------------------------------------------------

class _RotateParams {
  const _RotateParams({
    required this.inputPath,
    required this.outputPath,
    required this.angleDegrees,
  });

  final String inputPath;
  final String outputPath;
  final int angleDegrees;
}

Future<String> _rotateIsolate(_RotateParams params) async {
  final bytes = await File(params.inputPath).readAsBytes();
  final image = img.decodeImage(bytes);
  if (image == null) {
    throw Exception('Unable to decode source image at ${params.inputPath}');
  }

  final rotated = img.copyRotate(image, angle: params.angleDegrees);
  final encoded = img.encodeJpg(rotated, quality: 92);
  await File(params.outputPath).writeAsBytes(encoded, flush: true);
  return params.outputPath;
}

class _FilterParams {
  const _FilterParams({
    required this.inputPath,
    required this.outputPath,
    required this.filterType,
  });

  final String inputPath;
  final String outputPath;
  final DocumentFilterType filterType;
}

Future<String> _filterIsolate(_FilterParams params) async {
  final bytes = await File(params.inputPath).readAsBytes();
  final image = img.decodeImage(bytes);
  if (image == null) {
    throw Exception('Unable to decode source image at ${params.inputPath}');
  }

  img.Image processed;
  switch (params.filterType) {
    case DocumentFilterType.original:
      processed = image;
      break;

    case DocumentFilterType.color:
      // Enhanced color: slight contrast and saturation boost to make ink/text punchy
      processed = img.adjustColor(
        image,
        contrast: 1.15,
        saturation: 1.12,
        brightness: 1.02,
      );
      break;

    case DocumentFilterType.grayscale:
      // Standard grayscale
      processed = img.grayscale(image);
      break;

    case DocumentFilterType.blackAndWhite:
      // Clean binary B&W for printed text documents
      final gray = img.grayscale(image);
      // High-contrast binarization thresholding
      processed = img.adjustColor(
        gray,
        contrast: 1.6,
        brightness: 1.05,
      );
      break;

    case DocumentFilterType.enhanced:
      // Magic filter: clears background shadows and sharpens document text
      processed = img.adjustColor(
        image,
        contrast: 1.25,
        brightness: 1.08,
      );
      break;
  }

  final encoded = img.encodeJpg(processed, quality: 92);
  await File(params.outputPath).writeAsBytes(encoded, flush: true);
  return params.outputPath;
}

class _RectifyParams {
  const _RectifyParams({
    required this.inputPath,
    required this.outputPath,
    required this.corners,
  });

  final String inputPath;
  final String outputPath;
  final DocumentCornerPoints corners;
}

Future<String> _rectifyIsolate(_RectifyParams params) async {
  final bytes = await File(params.inputPath).readAsBytes();
  final image = img.decodeImage(bytes);
  if (image == null) {
    throw Exception('Unable to decode source image at ${params.inputPath}');
  }

  final w = image.width.toDouble();
  final h = image.height.toDouble();

  // Convert normalized corner coordinates (0.0 - 1.0) to pixel points
  final tl = img.Point(
    (params.corners.topLeftX * w).clamp(0, w - 1).toInt(),
    (params.corners.topLeftY * h).clamp(0, h - 1).toInt(),
  );
  final tr = img.Point(
    (params.corners.topRightX * w).clamp(0, w - 1).toInt(),
    (params.corners.topRightY * h).clamp(0, h - 1).toInt(),
  );
  final bl = img.Point(
    (params.corners.bottomLeftX * w).clamp(0, w - 1).toInt(),
    (params.corners.bottomLeftY * h).clamp(0, h - 1).toInt(),
  );
  final br = img.Point(
    (params.corners.bottomRightX * w).clamp(0, w - 1).toInt(),
    (params.corners.bottomRightY * h).clamp(0, h - 1).toInt(),
  );

  final rectified = img.copyRectify(
    image,
    topLeft: tl,
    topRight: tr,
    bottomLeft: bl,
    bottomRight: br,
    interpolation: img.Interpolation.linear,
  );

  final encoded = img.encodeJpg(rectified, quality: 92);
  await File(params.outputPath).writeAsBytes(encoded, flush: true);
  return params.outputPath;
}

class _ThumbnailParams {
  const _ThumbnailParams({
    required this.inputPath,
    required this.outputPath,
    required this.targetWidth,
  });

  final String inputPath;
  final String outputPath;
  final int targetWidth;
}

Future<String> _thumbnailIsolate(_ThumbnailParams params) async {
  final bytes = await File(params.inputPath).readAsBytes();
  final image = img.decodeImage(bytes);
  if (image == null) {
    throw Exception('Unable to decode source image at ${params.inputPath}');
  }

  final resized = img.copyResize(
    image,
    width: params.targetWidth,
    interpolation: img.Interpolation.linear,
  );

  final encoded = img.encodeJpg(resized, quality: 80);
  await File(params.outputPath).writeAsBytes(encoded, flush: true);
  return params.outputPath;
}
