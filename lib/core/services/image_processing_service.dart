import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../errors/exceptions.dart';

/// Supported visual filters for scanned documents.
enum DocumentFilterType { original, color, grayscale, blackAndWhite, enhanced }

/// Intensity levels for Black & White thresholding and contrast.
enum BwIntensity { low, medium, high }

extension BwIntensityExtension on BwIntensity {
  String get displayName {
    switch (this) {
      case BwIntensity.low:
        return 'Low';
      case BwIntensity.medium:
        return 'Medium';
      case BwIntensity.high:
        return 'High';
    }
  }
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

/// Type alias for DocumentFilterType matching ScanFilter specification.
typedef ScanFilter = DocumentFilterType;

/// Type alias for DocumentCornerPoints matching CropCorners specification.
typedef CropCorners = DocumentCornerPoints;

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

  /// Whether the corners represent the uncropped full bounding box.
  bool get isFullBounds =>
      topLeftX == 0.0 &&
      topLeftY == 0.0 &&
      topRightX == 1.0 &&
      topRightY == 0.0 &&
      bottomLeftX == 0.0 &&
      bottomLeftY == 1.0 &&
      bottomRightX == 1.0 &&
      bottomRightY == 1.0;

  /// Whether the quadrilateral formed by these 4 points is geometrically valid
  /// (no duplicate/collinear vertices, non-degenerate edge lengths).
  bool get isValidQuad {
    if (topLeftX.isNaN ||
        topLeftY.isNaN ||
        topRightX.isNaN ||
        topRightY.isNaN ||
        bottomRightX.isNaN ||
        bottomRightY.isNaN ||
        bottomLeftX.isNaN ||
        bottomLeftY.isNaN) {
      return false;
    }

    // Coordinates must lie within normalized [0.0, 1.0] bounds
    final coords = [
      topLeftX,
      topLeftY,
      topRightX,
      topRightY,
      bottomRightX,
      bottomRightY,
      bottomLeftX,
      bottomLeftY,
    ];
    for (final c in coords) {
      if (c < 0.0 || c > 1.0) return false;
    }

    // Check minimum edge lengths (at least 5% of normalized viewport)
    final topLen = math.sqrt(
      math.pow(topRightX - topLeftX, 2) + math.pow(topRightY - topLeftY, 2),
    );
    final rightLen = math.sqrt(
      math.pow(bottomRightX - topRightX, 2) +
          math.pow(bottomRightY - topRightY, 2),
    );
    final bottomLen = math.sqrt(
      math.pow(bottomRightX - bottomLeftX, 2) +
          math.pow(bottomRightY - bottomLeftY, 2),
    );
    final leftLen = math.sqrt(
      math.pow(bottomLeftX - topLeftX, 2) + math.pow(bottomLeftY - topLeftY, 2),
    );

    if (topLen < 0.05 ||
        rightLen < 0.05 ||
        bottomLen < 0.05 ||
        leftLen < 0.05) {
      return false;
    }

    final ar = aspectRatio;
    if (ar < 0.15 || ar > 6.5) return false;

    return isConvex && quadArea >= 0.02;
  }

  /// Calculates normalized area of the quadrilateral using the Shoelace formula.
  double get quadArea {
    final area2 =
        ((topLeftX * topRightY - topLeftY * topRightX) +
                (topRightX * bottomRightY - topRightY * bottomRightX) +
                (bottomRightX * bottomLeftY - bottomRightY * bottomLeftX) +
                (bottomLeftX * topLeftY - bottomLeftY * topLeftX))
            .abs();
    return 0.5 * area2;
  }

  /// Whether the quadrilateral is strictly convex (all consecutive edge cross products share same sign).
  bool get isConvex {
    final v1x = topRightX - topLeftX;
    final v1y = topRightY - topLeftY;

    final v2x = bottomRightX - topRightX;
    final v2y = bottomRightY - topRightY;

    final v3x = bottomLeftX - bottomRightX;
    final v3y = bottomLeftY - bottomRightY;

    final v4x = topLeftX - bottomLeftX;
    final v4y = topLeftY - bottomLeftY;

    final cp1 = v1x * v2y - v1y * v2x;
    final cp2 = v2x * v3y - v2y * v3x;
    final cp3 = v3x * v4y - v3y * v4x;
    final cp4 = v4x * v1y - v4y * v1x;

    const eps = 1e-6;
    final allPositive = cp1 > eps && cp2 > eps && cp3 > eps && cp4 > eps;
    final allNegative = cp1 < -eps && cp2 < -eps && cp3 < -eps && cp4 < -eps;

    return allPositive || allNegative;
  }

  /// Ratio of average width to average height.
  double get aspectRatio {
    final avgWidth =
        0.5 *
        (math.sqrt(
              math.pow(topRightX - topLeftX, 2) +
                  math.pow(topRightY - topLeftY, 2),
            ) +
            math.sqrt(
              math.pow(bottomRightX - bottomLeftX, 2) +
                  math.pow(bottomRightY - bottomLeftY, 2),
            ));
    final avgHeight =
        0.5 *
        (math.sqrt(
              math.pow(bottomLeftX - topLeftX, 2) +
                  math.pow(bottomLeftY - topLeftY, 2),
            ) +
            math.sqrt(
              math.pow(bottomRightX - topRightX, 2) +
                  math.pow(bottomRightY - topRightY, 2),
            ));

    if (avgHeight < 0.01) return 1.0;
    return avgWidth / avgHeight;
  }

  /// Normalized distance of the quadrilateral centroid from frame center (0.5, 0.5).
  double get centerOffset {
    final cx = 0.25 * (topLeftX + topRightX + bottomRightX + bottomLeftX);
    final cy = 0.25 * (topLeftY + topRightY + bottomRightY + bottomLeftY);
    return math.sqrt(math.pow(cx - 0.5, 2) + math.pow(cy - 0.5, 2));
  }

  /// Computes average corner displacement to another set of corners for motion/stability detection.
  double distanceTo(DocumentCornerPoints other) {
    final dTL = math.sqrt(
      math.pow(topLeftX - other.topLeftX, 2) +
          math.pow(topLeftY - other.topLeftY, 2),
    );
    final dTR = math.sqrt(
      math.pow(topRightX - other.topRightX, 2) +
          math.pow(topRightY - other.topRightY, 2),
    );
    final dBR = math.sqrt(
      math.pow(bottomRightX - other.bottomRightX, 2) +
          math.pow(bottomRightY - other.bottomRightY, 2),
    );
    final dBL = math.sqrt(
      math.pow(bottomLeftX - other.bottomLeftX, 2) +
          math.pow(bottomLeftY - other.bottomLeftY, 2),
    );
    return 0.25 * (dTL + dTR + dBR + dBL);
  }

  /// Applies a safety margin clamping inward/outward within [0.0, 1.0].
  DocumentCornerPoints withSafetyMargin([double margin = 0.01]) {
    return DocumentCornerPoints(
      topLeftX: (topLeftX - margin).clamp(0.0, 1.0),
      topLeftY: (topLeftY - margin).clamp(0.0, 1.0),
      topRightX: (topRightX + margin).clamp(0.0, 1.0),
      topRightY: (topRightY - margin).clamp(0.0, 1.0),
      bottomLeftX: (bottomLeftX - margin).clamp(0.0, 1.0),
      bottomLeftY: (bottomLeftY + margin).clamp(0.0, 1.0),
      bottomRightX: (bottomRightX + margin).clamp(0.0, 1.0),
      bottomRightY: (bottomRightY + margin).clamp(0.0, 1.0),
    );
  }

  DocumentCornerPoints copyWith({
    double? topLeftX,
    double? topLeftY,
    double? topRightX,
    double? topRightY,
    double? bottomLeftX,
    double? bottomLeftY,
    double? bottomRightX,
    double? bottomRightY,
  }) {
    return DocumentCornerPoints(
      topLeftX: topLeftX ?? this.topLeftX,
      topLeftY: topLeftY ?? this.topLeftY,
      topRightX: topRightX ?? this.topRightX,
      topRightY: topRightY ?? this.topRightY,
      bottomLeftX: bottomLeftX ?? this.bottomLeftX,
      bottomLeftY: bottomLeftY ?? this.bottomLeftY,
      bottomRightX: bottomRightX ?? this.bottomRightX,
      bottomRightY: bottomRightY ?? this.bottomRightY,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentCornerPoints &&
          runtimeType == other.runtimeType &&
          topLeftX == other.topLeftX &&
          topLeftY == other.topLeftY &&
          topRightX == other.topRightX &&
          topRightY == other.topRightY &&
          bottomLeftX == other.bottomLeftX &&
          bottomLeftY == other.bottomLeftY &&
          bottomRightX == other.bottomRightX &&
          bottomRightY == other.bottomRightY;

  @override
  int get hashCode => Object.hash(
    topLeftX,
    topLeftY,
    topRightX,
    topRightY,
    bottomLeftX,
    bottomLeftY,
    bottomRightX,
    bottomRightY,
  );

  @override
  String toString() =>
      'DocumentCornerPoints(tl: ($topLeftX, $topLeftY), tr: ($topRightX, $topRightY), bl: ($bottomLeftX, $bottomLeftY), br: ($bottomRightX, $bottomRightY))';
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
    BwIntensity bwIntensity = BwIntensity.medium,
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
    BwIntensity bwIntensity = BwIntensity.medium,
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
        bwIntensity: bwIntensity,
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
      throw ImageProcessingException(
        'Failed to rectify image perspective: $e',
        e,
      );
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
      return await compute(_dimensionsIsolate, imagePath);
    } catch (e) {
      return (0, 0);
    }
  }
}

Future<(int, int)> _dimensionsIsolate(String imagePath) async {
  try {
    final file = File(imagePath);
    if (!file.existsSync()) {
      return (0, 0);
    }
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return (0, 0);
    }
    return (decoded.width, decoded.height);
  } catch (_) {
    return (0, 0);
  }
}

// ---------------------------------------------------------------------------
// Isolate parameter classes and workers
// ---------------------------------------------------------------------------

img.Image _ensureManageableSize(img.Image image, {int maxDimension = 3200}) {
  if (image.width > maxDimension || image.height > maxDimension) {
    if (image.width >= image.height) {
      return img.copyResize(
        image,
        width: maxDimension,
        interpolation: img.Interpolation.linear,
      );
    } else {
      return img.copyResize(
        image,
        height: maxDimension,
        interpolation: img.Interpolation.linear,
      );
    }
  }
  return image;
}

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
  var image = img.decodeImage(bytes);
  if (image == null) {
    throw Exception('Unable to decode source image at ${params.inputPath}');
  }

  image = _ensureManageableSize(image);

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
    this.bwIntensity = BwIntensity.medium,
  });

  final String inputPath;
  final String outputPath;
  final DocumentFilterType filterType;
  final BwIntensity bwIntensity;
}

Future<String> _filterIsolate(_FilterParams params) async {
  final bytes = await File(params.inputPath).readAsBytes();
  var image = img.decodeImage(bytes);
  if (image == null) {
    throw Exception('Unable to decode source image at ${params.inputPath}');
  }

  image = _ensureManageableSize(image);

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
      final gray = img.grayscale(image);
      switch (params.bwIntensity) {
        case BwIntensity.low:
          // Softer contrast to preserve thin characters and pencil handwriting
          processed = img.adjustColor(gray, contrast: 1.35, brightness: 1.03);
          break;
        case BwIntensity.medium:
          // Balanced binarization for standard documents
          processed = img.adjustColor(gray, contrast: 1.6, brightness: 1.06);
          break;
        case BwIntensity.high:
          // High-contrast clean background binarization
          processed = img.adjustColor(gray, contrast: 1.9, brightness: 1.10);
          break;
      }
      break;

    case DocumentFilterType.enhanced:
      // Auto Enhance: clears background shadows and sharpens document text
      final adjusted = img.adjustColor(
        image,
        contrast: 1.25,
        brightness: 1.08,
        saturation: 1.05,
      );
      // Mild unsharp text enhancement
      processed = img.convolution(
        adjusted,
        filter: [0, -0.2, 0, -0.2, 1.8, -0.2, 0, -0.2, 0],
        div: 1.0,
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
  var image = img.decodeImage(bytes);
  if (image == null) {
    throw Exception('Unable to decode source image at ${params.inputPath}');
  }

  image = _ensureManageableSize(image);

  final w = image.width.toDouble();
  final h = image.height.toDouble();

  // Safety fallback if degenerate quadrilateral
  if (!params.corners.isValidQuad) {
    final encoded = img.encodeJpg(image, quality: 92);
    await File(params.outputPath).writeAsBytes(encoded, flush: true);
    return params.outputPath;
  }

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

  // Calculate Euclidean width and height to preserve document aspect ratio without stretching
  final topWidth = math.sqrt(
    math.pow(tr.x - tl.x, 2) + math.pow(tr.y - tl.y, 2),
  );
  final bottomWidth = math.sqrt(
    math.pow(br.x - bl.x, 2) + math.pow(br.y - bl.y, 2),
  );
  final destWidth = math
      .max(topWidth, bottomWidth)
      .round()
      .clamp(50, w.toInt());

  final leftHeight = math.sqrt(
    math.pow(bl.x - tl.x, 2) + math.pow(bl.y - tl.y, 2),
  );
  final rightHeight = math.sqrt(
    math.pow(br.x - tr.x, 2) + math.pow(br.y - tr.y, 2),
  );
  final destHeight = math
      .max(leftHeight, rightHeight)
      .round()
      .clamp(50, h.toInt());

  final dstImage = img.Image(
    width: destWidth,
    height: destHeight,
    numChannels: image.numChannels,
  );

  final rectified = img.copyRectify(
    image,
    topLeft: tl,
    topRight: tr,
    bottomLeft: bl,
    bottomRight: br,
    toImage: dstImage,
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
