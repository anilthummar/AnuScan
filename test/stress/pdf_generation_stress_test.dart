import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:anuscan/core/services/pdf_generator_service.dart';

void main() {
  late Directory tempDir;
  late String sampleImagePath;
  const service = PdfGeneratorServiceImpl();

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('pdf_stress_test_');

    // Create a realistic sample JPEG image (800x1200)
    final image = img.Image(width: 800, height: 1200);
    img.fill(image, color: img.ColorRgb8(240, 240, 240));
    // Draw some test shapes/pixels
    for (var y = 100; y < 300; y++) {
      for (var x = 100; x < 700; x++) {
        image.setPixelRgb(x, y, 40, 80, 160);
      }
    }
    final jpgBytes = img.encodeJpg(image, quality: 80);
    sampleImagePath = p.join(tempDir.path, 'sample_page.jpg');
    await File(sampleImagePath).writeAsBytes(jpgBytes);
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('PDF Generation Stress & Scale Tests', () {
    test(
      'successfully compiles a 10-page document with progress tracking',
      () async {
        final outputPath = p.join(tempDir.path, 'doc_10_pages.pdf');
        final imagePaths = List.generate(10, (_) => sampleImagePath);
        final progressUpdates = <double>[];

        final result = await service.generatePdf(
          imagePaths: imagePaths,
          outputPath: outputPath,
          pageSize: PdfPageSizeOption.a4,
          quality: PdfQualityOption.standard,
          onProgress: (progress, current, total) {
            progressUpdates.add(progress);
          },
        );

        final pdfFile = File(result);
        expect(pdfFile.existsSync(), isTrue);
        expect(await pdfFile.length(), greaterThan(0));
        expect(progressUpdates, isNotEmpty);
        expect(progressUpdates.last, equals(1.0));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'successfully compiles a 20-page document with progress tracking',
      () async {
        final outputPath = p.join(tempDir.path, 'doc_20_pages.pdf');
        final imagePaths = List.generate(20, (_) => sampleImagePath);
        final progressUpdates = <double>[];

        final result = await service.generatePdf(
          imagePaths: imagePaths,
          outputPath: outputPath,
          pageSize: PdfPageSizeOption.a4,
          quality: PdfQualityOption.standard,
          onProgress: (progress, current, total) {
            progressUpdates.add(progress);
          },
        );

        final pdfFile = File(result);
        expect(pdfFile.existsSync(), isTrue);
        expect(await pdfFile.length(), greaterThan(0));
        expect(progressUpdates.last, equals(1.0));
      },
      timeout: const Timeout(Duration(seconds: 45)),
    );

    test(
      'successfully compiles a 30-page document with US Letter format',
      () async {
        final outputPath = p.join(tempDir.path, 'doc_30_pages.pdf');
        final imagePaths = List.generate(30, (_) => sampleImagePath);

        final result = await service.generatePdf(
          imagePaths: imagePaths,
          outputPath: outputPath,
          pageSize: PdfPageSizeOption.letter,
          quality: PdfQualityOption.low,
        );

        final pdfFile = File(result);
        expect(pdfFile.existsSync(), isTrue);
        expect(await pdfFile.length(), greaterThan(0));
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'successfully compiles a 50-page document without memory exhaustion',
      () async {
        final outputPath = p.join(tempDir.path, 'doc_50_pages.pdf');
        final imagePaths = List.generate(50, (_) => sampleImagePath);
        final progressUpdates = <double>[];

        final result = await service.generatePdf(
          imagePaths: imagePaths,
          outputPath: outputPath,
          pageSize: PdfPageSizeOption.fitImage,
          quality: PdfQualityOption.standard,
          onProgress: (progress, current, total) {
            progressUpdates.add(progress);
          },
        );

        final pdfFile = File(result);
        expect(pdfFile.existsSync(), isTrue);
        expect(await pdfFile.length(), greaterThan(0));
        expect(progressUpdates.last, equals(1.0));
      },
      timeout: const Timeout(Duration(seconds: 90)),
    );
  });
}
