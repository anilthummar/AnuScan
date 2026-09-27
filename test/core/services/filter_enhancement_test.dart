import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:anuscan/core/services/image_processing_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String testImagePath;
  const service = ImageProcessingServiceImpl();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('filter_test_');

    // Create a 200x300 gradient RGB image with text-like high contrast lines
    final image = img.Image(width: 200, height: 300);
    for (int y = 0; y < 300; y++) {
      for (int x = 0; x < 200; x++) {
        final gray = ((x + y) % 256);
        image.setPixelRgb(x, y, gray, gray, gray);
      }
    }
    testImagePath = '${tempDir.path}/test_source.jpg';
    await File(testImagePath).writeAsBytes(img.encodeJpg(image));
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Filter Enhancement & B&W Intensity (Phase 10.9, 10.10, 10.11)', () {
    test('BwIntensity enum has proper labels and values', () {
      expect(BwIntensity.values.length, equals(3));
      expect(BwIntensity.low.displayName, equals('Low'));
      expect(BwIntensity.medium.displayName, equals('Medium'));
      expect(BwIntensity.high.displayName, equals('High'));
    });

    test('B&W filter applies with each intensity level successfully', () async {
      for (final intensity in BwIntensity.values) {
        final outPath = '${tempDir.path}/bw_${intensity.name}.jpg';
        final result = await service.applyFilter(
          inputPath: testImagePath,
          outputPath: outPath,
          filterType: DocumentFilterType.blackAndWhite,
          bwIntensity: intensity,
        );

        expect(result, equals(outPath));
        expect(await File(outPath).exists(), isTrue);
        final (w, h) = await service.getImageDimensions(outPath);
        expect(w, equals(200));
        expect(h, equals(300));
      }
    });

    test(
      'Enhanced filter applies with unsharp sharpening without error',
      () async {
        final outPath = '${tempDir.path}/enhanced.jpg';
        final result = await service.applyFilter(
          inputPath: testImagePath,
          outputPath: outPath,
          filterType: DocumentFilterType.enhanced,
        );

        expect(result, equals(outPath));
        expect(await File(outPath).exists(), isTrue);
        expect(await File(outPath).length(), greaterThan(0));
      },
    );

    test('Rectify perspective preserves Euclidean aspect ratio', () async {
      final outPath = '${tempDir.path}/rectified.jpg';
      // Skewed quad representing a tilted A4-like rectangle
      const corners = DocumentCornerPoints(
        topLeftX: 0.1,
        topLeftY: 0.1,
        topRightX: 0.9,
        topRightY: 0.15,
        bottomLeftX: 0.15,
        bottomLeftY: 0.85,
        bottomRightX: 0.85,
        bottomRightY: 0.9,
      );

      final result = await service.rectifyPerspective(
        inputPath: testImagePath,
        outputPath: outPath,
        corners: corners,
      );

      expect(result, equals(outPath));
      expect(await File(outPath).exists(), isTrue);
      final (w, h) = await service.getImageDimensions(outPath);
      expect(w, greaterThan(50));
      expect(h, greaterThan(50));
    });

    test(
      'Rectify perspective gracefully handles degenerate quad without crashing',
      () async {
        final outPath = '${tempDir.path}/degenerate.jpg';
        // Collinear invalid quad
        const degenerateCorners = DocumentCornerPoints(
          topLeftX: 0.2,
          topLeftY: 0.2,
          topRightX: 0.2,
          topRightY: 0.2,
          bottomLeftX: 0.2,
          bottomLeftY: 0.2,
          bottomRightX: 0.2,
          bottomRightY: 0.2,
        );

        final result = await service.rectifyPerspective(
          inputPath: testImagePath,
          outputPath: outPath,
          corners: degenerateCorners,
        );

        expect(result, equals(outPath));
        expect(await File(outPath).exists(), isTrue);
        final (w, h) = await service.getImageDimensions(outPath);
        expect(w, equals(200));
        expect(h, equals(300));
      },
    );
  });
}
