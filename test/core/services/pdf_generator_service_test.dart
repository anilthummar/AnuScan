import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:anuscan/core/services/pdf_generator_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String page1Path;
  late String page2Path;
  late PdfGeneratorServiceImpl service;

  setUp(() async {
    service = const PdfGeneratorServiceImpl();
    tempDir = await Directory.systemTemp.createTemp('anuscan_pdf_test_');

    // Create 2 test pages
    final img1 = img.Image(width: 200, height: 300);
    img.fill(img1, color: img.ColorRgb8(255, 255, 255));
    page1Path = '${tempDir.path}/page1.jpg';
    await File(page1Path).writeAsBytes(img.encodeJpg(img1));

    final img2 = img.Image(width: 200, height: 300);
    img.fill(img2, color: img.ColorRgb8(240, 240, 240));
    page2Path = '${tempDir.path}/page2.jpg';
    await File(page2Path).writeAsBytes(img.encodeJpg(img2));
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('generatePdf compiles multiple pages into valid PDF file', () async {
    final pdfPath = '${tempDir.path}/output.pdf';
    final result = await service.generatePdf(
      imagePaths: [page1Path, page2Path],
      outputPath: pdfPath,
      pageSize: PdfPageSizeOption.a4,
      title: 'Test Scan Document',
    );

    expect(result, equals(pdfPath));
    final pdfFile = File(pdfPath);
    expect(await pdfFile.exists(), isTrue);

    final bytes = await pdfFile.readAsBytes();
    // PDF files always start with '%PDF-'
    expect(String.fromCharCodes(bytes.sublist(0, 5)), equals('%PDF-'));
    expect(bytes.length, greaterThan(500));
  });
}
