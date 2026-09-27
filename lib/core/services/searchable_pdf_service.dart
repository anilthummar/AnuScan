import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../features/document_editor/domain/entities/scanned_page.dart';
import '../../features/ocr/domain/entities/ocr_entities.dart';
import '../errors/exceptions.dart';
import 'pdf_generator_service.dart';

/// Abstract service contract for compiling multi-page searchable PDFs.
/// Renders high-resolution image layer with invisible, selectable OCR text layer.
abstract class SearchablePdfService {
  Future<String> generateSearchablePdf({
    required List<ScannedPage> pages,
    required List<OcrPageResult> ocrResults,
    required String outputPath,
    PdfPageSizeOption pageSize = PdfPageSizeOption.a4,
    PdfQualityOption quality = PdfQualityOption.standard,
    String? title,
    PdfProgressCallback? onProgress,
  });
}

/// Concrete implementation of [SearchablePdfService].
class SearchablePdfServiceImpl implements SearchablePdfService {
  const SearchablePdfServiceImpl();

  @override
  Future<String> generateSearchablePdf({
    required List<ScannedPage> pages,
    required List<OcrPageResult> ocrResults,
    required String outputPath,
    PdfPageSizeOption pageSize = PdfPageSizeOption.a4,
    PdfQualityOption quality = PdfQualityOption.standard,
    String? title,
    PdfProgressCallback? onProgress,
  }) async {
    if (pages.isEmpty) {
      throw const PdfGenerationException('Cannot generate PDF from zero pages');
    }

    final doc = pw.Document(title: title ?? 'Searchable Document');
    final total = pages.length;

    // Index OCR results by page ID
    final ocrByPageId = {for (final o in ocrResults) o.pageId: o};

    for (int i = 0; i < total; i++) {
      final page = pages[i];
      final imageFile = File(page.processedImagePath);
      if (!await imageFile.exists()) {
        throw PdfGenerationException(
          'Page image not found: ${page.processedImagePath}',
        );
      }

      final imageBytes = await imageFile.readAsBytes();
      final pdfImage = pw.MemoryImage(imageBytes);

      final ocrResult = ocrByPageId[page.id];
      final pageText = ocrResult?.extractedText ?? '';

      final targetFormat = switch (pageSize) {
        PdfPageSizeOption.a4 => PdfPageFormat.a4,
        PdfPageSizeOption.letter => PdfPageFormat.letter,
        PdfPageSizeOption.fitImage => PdfPageFormat(
          pdfImage.width?.toDouble() ?? PdfPageFormat.a4.width,
          pdfImage.height?.toDouble() ?? PdfPageFormat.a4.height,
        ),
      };

      doc.addPage(
        pw.Page(
          pageFormat: targetFormat,
          margin: pw.EdgeInsets.zero,
          build: (context) {
            return pw.Stack(
              fit: pw.StackFit.expand,
              children: [
                // 1. High-fidelity Scanned Image Layer
                pw.Image(pdfImage, fit: pw.BoxFit.contain),

                // 2. Selectable OCR Text Layer (rendered with transparent color)
                if (pageText.isNotEmpty)
                  pw.Opacity(
                    opacity: 0.0,
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.all(24.0),
                      child: pw.Text(
                        pageText,
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.black,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      );

      onProgress?.call((i + 1) / total, i + 1, total);
    }

    final outputFile = File(outputPath);
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsBytes(await doc.save());

    return outputPath;
  }
}
