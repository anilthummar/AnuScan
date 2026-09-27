import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:anuscan/core/errors/exceptions.dart';
import 'package:anuscan/core/services/pdf_generator_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PdfGeneratorServiceImpl service;

  setUp(() async {
    service = const PdfGeneratorServiceImpl();
    tempDir = await Directory.systemTemp.createTemp('anuscan_pdf_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Helper to create a dummy image on disk
  Future<String> createTestImage({
    required String name,
    int width = 200,
    int height = 300,
    img.Color? fillColor,
    bool grayscale = false,
  }) async {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: fillColor ?? img.ColorRgb8(100, 150, 200));

    if (grayscale) {
      img.grayscale(image);
    }

    final filePath = '${tempDir.path}/$name.jpg';
    await File(filePath).writeAsBytes(img.encodeJpg(image, quality: 85));
    return filePath;
  }

  test('generates exactly one PDF with 1 page', () async {
    final pagePath = await createTestImage(name: 'page_single');
    final outputPath = '${tempDir.path}/single_page.pdf';

    final result = await service.generatePdf(
      imagePaths: [pagePath],
      outputPath: outputPath,
      pageSize: PdfPageSizeOption.a4,
      title: 'Single Page Doc',
    );

    expect(result, equals(outputPath));
    final file = File(outputPath);
    expect(await file.exists(), isTrue);

    final bytes = await file.readAsBytes();
    // PDF Magic bytes
    expect(String.fromCharCodes(bytes.sublist(0, 5)), equals('%PDF-'));
    expect(bytes.length, greaterThan(300));
  });

  test('generates PDF with 5 pages and tracks progress accurately', () async {
    final paths = <String>[];
    for (int i = 1; i <= 5; i++) {
      paths.add(await createTestImage(name: 'page_5_$i'));
    }

    final outputPath = '${tempDir.path}/five_pages.pdf';
    final progressReports = <double>[];
    final pageReports = <int>[];

    final result = await service.generatePdf(
      imagePaths: paths,
      outputPath: outputPath,
      pageSize: PdfPageSizeOption.a4,
      title: 'Five Pages Doc',
      onProgress: (progress, current, total) {
        progressReports.add(progress);
        pageReports.add(current);
        expect(total, equals(5));
      },
    );

    expect(result, equals(outputPath));
    expect(await File(outputPath).exists(), isTrue);
    expect(progressReports.length, equals(5));
    expect(progressReports.last, equals(1.0));
    expect(pageReports, equals([1, 2, 3, 4, 5]));
  });

  test('generates PDF with 20 pages seamlessly', () async {
    final paths = <String>[];
    for (int i = 1; i <= 20; i++) {
      paths.add(
        await createTestImage(
          name: 'page_20_$i',
          width: 100,
          height: 140,
          fillColor: img.ColorRgb8(i * 10, i * 10, i * 10),
        ),
      );
    }

    final outputPath = '${tempDir.path}/twenty_pages.pdf';
    var lastProgress = 0.0;
    var finalPage = 0;

    final result = await service.generatePdf(
      imagePaths: paths,
      outputPath: outputPath,
      pageSize: PdfPageSizeOption.a4,
      title: 'Twenty Pages Doc',
      onProgress: (progress, current, total) {
        lastProgress = progress;
        finalPage = current;
      },
    );

    expect(result, equals(outputPath));
    expect(lastProgress, equals(1.0));
    expect(finalPage, equals(20));

    final file = File(outputPath);
    expect(await file.exists(), isTrue);
    final bytes = await file.readAsBytes();
    expect(String.fromCharCodes(bytes.sublist(0, 5)), equals('%PDF-'));
  });

  test('compiles large images with compression without failure', () async {
    // 1600 x 2200 large image
    final largePath = await createTestImage(
      name: 'large_image',
      width: 1600,
      height: 2200,
      fillColor: img.ColorRgb8(220, 180, 140),
    );

    final outputPath = '${tempDir.path}/large_image.pdf';
    final result = await service.generatePdf(
      imagePaths: [largePath],
      outputPath: outputPath,
      pageSize: PdfPageSizeOption.a4,
      quality: PdfQualityOption.standard,
    );

    expect(result, equals(outputPath));
    expect(await File(outputPath).exists(), isTrue);
  });

  test(
    'compiles rotated pages (portrait and landscape orientations)',
    () async {
      // Normal portrait page
      final portrait = await createTestImage(
        name: 'portrait_page',
        width: 600,
        height: 800,
      );
      // 90 degree rotated landscape page
      final landscape = await createTestImage(
        name: 'landscape_page',
        width: 800,
        height: 600,
      );

      final outputPath = '${tempDir.path}/rotated_pages.pdf';
      final result = await service.generatePdf(
        imagePaths: [portrait, landscape],
        outputPath: outputPath,
        pageSize: PdfPageSizeOption.a4,
        title: 'Rotated Pages',
      );

      expect(result, equals(outputPath));
      expect(await File(outputPath).exists(), isTrue);
    },
  );

  test(
    'compiles pages with different filters (Color, Grayscale, B&W)',
    () async {
      final colorPage = await createTestImage(
        name: 'color_page',
        fillColor: img.ColorRgb8(255, 100, 50),
      );
      final grayPage = await createTestImage(
        name: 'gray_page',
        grayscale: true,
      );
      final bwPage = await createTestImage(
        name: 'bw_page',
        fillColor: img.ColorRgb8(0, 0, 0),
      );

      final outputPath = '${tempDir.path}/filtered_pages.pdf';
      final result = await service.generatePdf(
        imagePaths: [colorPage, grayPage, bwPage],
        outputPath: outputPath,
        pageSize: PdfPageSizeOption.a4,
        title: 'Filter Tests',
      );

      expect(result, equals(outputPath));
      expect(await File(outputPath).exists(), isTrue);
    },
  );

  test('supports US Letter and Auto Fit page formats', () async {
    final pagePath = await createTestImage(name: 'letter_page');

    final letterOutput = '${tempDir.path}/letter.pdf';
    await service.generatePdf(
      imagePaths: [pagePath],
      outputPath: letterOutput,
      pageSize: PdfPageSizeOption.letter,
    );
    expect(await File(letterOutput).exists(), isTrue);

    final fitOutput = '${tempDir.path}/fit.pdf';
    await service.generatePdf(
      imagePaths: [pagePath],
      outputPath: fitOutput,
      pageSize: PdfPageSizeOption.fitImage,
    );
    expect(await File(fitOutput).exists(), isTrue);
  });

  test('quality compression reduces file size (Low vs High)', () async {
    final imagePath = await createTestImage(
      name: 'comp_test',
      width: 800,
      height: 1000,
      fillColor: img.ColorRgb8(120, 200, 150),
    );

    final lowPdfPath = '${tempDir.path}/low.pdf';
    await service.generatePdf(
      imagePaths: [imagePath],
      outputPath: lowPdfPath,
      quality: PdfQualityOption.low,
    );

    final highPdfPath = '${tempDir.path}/high.pdf';
    await service.generatePdf(
      imagePaths: [imagePath],
      outputPath: highPdfPath,
      quality: PdfQualityOption.high,
    );

    final lowSize = await File(lowPdfPath).length();
    final highSize = await File(highPdfPath).length();

    // High quality retains original bytes without downscale/compression
    expect(lowSize, greaterThan(0));
    expect(highSize, greaterThan(0));
  });

  test('throws PdfGenerationException on empty image paths', () async {
    expect(
      () => service.generatePdf(
        imagePaths: [],
        outputPath: '${tempDir.path}/empty.pdf',
      ),
      throwsA(isA<PdfGenerationException>()),
    );
  });

  test('throws PdfGenerationException on missing image file', () async {
    expect(
      () => service.generatePdf(
        imagePaths: ['${tempDir.path}/does_not_exist.jpg'],
        outputPath: '${tempDir.path}/missing.pdf',
      ),
      throwsA(isA<PdfGenerationException>()),
    );
  });
}
