import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:anuscan/core/services/image_processing_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String testImagePath;
  late ImageProcessingServiceImpl service;

  setUp(() async {
    service = const ImageProcessingServiceImpl();
    tempDir = await Directory.systemTemp.createTemp('anuscan_test_');

    // Create a 100x200 test RGB image
    final testImage = img.Image(width: 100, height: 200);
    img.fill(testImage, color: img.ColorRgb8(200, 100, 50));
    testImagePath = '${tempDir.path}/test_source.jpg';
    await File(testImagePath).writeAsBytes(img.encodeJpg(testImage));
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('getImageDimensions returns accurate width and height', () async {
    final (width, height) = await service.getImageDimensions(testImagePath);
    expect(width, equals(100));
    expect(height, equals(200));
  });

  test('rotateImage rotates 90 degrees and flips dimensions', () async {
    final outputPath = '${tempDir.path}/rotated.jpg';
    final result = await service.rotateImage(
      inputPath: testImagePath,
      outputPath: outputPath,
      angleDegrees: 90,
    );

    expect(result, equals(outputPath));
    expect(await File(outputPath).exists(), isTrue);

    final (w, h) = await service.getImageDimensions(outputPath);
    expect(w, equals(200));
    expect(h, equals(100));
  });

  test('applyFilter produces valid images for all filter types', () async {
    for (final filter in DocumentFilterType.values) {
      final outputPath = '${tempDir.path}/filter_${filter.name}.jpg';
      final result = await service.applyFilter(
        inputPath: testImagePath,
        outputPath: outputPath,
        filterType: filter,
      );

      expect(result, equals(outputPath));
      expect(await File(outputPath).exists(), isTrue);
      expect((await File(outputPath).length()), greaterThan(0));
    }
  });

  test('rectifyPerspective performs perspective crop correctly', () async {
    final outputPath = '${tempDir.path}/rectified.jpg';
    final result = await service.rectifyPerspective(
      inputPath: testImagePath,
      outputPath: outputPath,
      corners: const DocumentCornerPoints(
        topLeftX: 0.1,
        topLeftY: 0.1,
        topRightX: 0.9,
        topRightY: 0.1,
        bottomLeftX: 0.1,
        bottomLeftY: 0.9,
        bottomRightX: 0.9,
        bottomRightY: 0.9,
      ),
    );

    expect(result, equals(outputPath));
    expect(await File(outputPath).exists(), isTrue);
    expect((await File(outputPath).length()), greaterThan(0));
  });

  test('generateThumbnail produces downsized image', () async {
    final outputPath = '${tempDir.path}/thumb.jpg';
    final result = await service.generateThumbnail(
      inputPath: testImagePath,
      outputPath: outputPath,
      targetWidth: 50,
    );

    expect(result, equals(outputPath));
    expect(await File(outputPath).exists(), isTrue);
    final (w, _) = await service.getImageDimensions(outputPath);
    expect(w, equals(50));
  });
}
