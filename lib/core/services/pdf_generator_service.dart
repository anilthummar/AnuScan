import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../errors/exceptions.dart';

/// Available page formats for PDF compilation.
enum PdfPageSizeOption { a4, letter, fitImage }

extension PdfPageSizeOptionExtension on PdfPageSizeOption {
  String get displayName {
    switch (this) {
      case PdfPageSizeOption.a4:
        return 'A4 Standard';
      case PdfPageSizeOption.letter:
        return 'US Letter';
      case PdfPageSizeOption.fitImage:
        return 'Auto Fit';
    }
  }
}

/// Abstract service interface for generating multi-page PDF documents.
abstract class PdfGeneratorService {
  /// Compiles [imagePaths] into a single PDF document at [outputPath].
  /// Returns the generated PDF file path.
  Future<String> generatePdf({
    required List<String> imagePaths,
    required String outputPath,
    PdfPageSizeOption pageSize = PdfPageSizeOption.a4,
    String? title,
  });
}

/// Concrete implementation of [PdfGeneratorService] utilizing isolates for non-blocking UI.
class PdfGeneratorServiceImpl implements PdfGeneratorService {
  const PdfGeneratorServiceImpl();

  @override
  Future<String> generatePdf({
    required List<String> imagePaths,
    required String outputPath,
    PdfPageSizeOption pageSize = PdfPageSizeOption.a4,
    String? title,
  }) async {
    try {
      if (imagePaths.isEmpty) {
        throw const PdfGenerationException(
          'Cannot generate PDF from zero pages',
        );
      }

      final params = _PdfParams(
        imagePaths: imagePaths,
        outputPath: outputPath,
        pageSize: pageSize,
        title: title,
      );

      return await compute(_generatePdfIsolate, params);
    } catch (e) {
      throw PdfGenerationException('Failed to generate PDF: $e', e);
    }
  }
}

class _PdfParams {
  const _PdfParams({
    required this.imagePaths,
    required this.outputPath,
    required this.pageSize,
    this.title,
  });

  final List<String> imagePaths;
  final String outputPath;
  final PdfPageSizeOption pageSize;
  final String? title;
}

Future<String> _generatePdfIsolate(_PdfParams params) async {
  final pdf = pw.Document(
    title: params.title ?? 'AnuScan Document',
    author: 'AnuScan',
    creator: 'AnuScan Document Scanner',
  );

  for (final imagePath in params.imagePaths) {
    final file = File(imagePath);
    if (!await file.exists()) {
      continue;
    }

    final bytes = await file.readAsBytes();
    final imageProvider = pw.MemoryImage(bytes);

    PdfPageFormat format;
    switch (params.pageSize) {
      case PdfPageSizeOption.a4:
        format = PdfPageFormat.a4;
        break;
      case PdfPageSizeOption.letter:
        format = PdfPageFormat.letter;
        break;
      case PdfPageSizeOption.fitImage:
        // Use image's intrinsic aspect ratio with standard margin
        final w = imageProvider.width?.toDouble() ?? 595.0;
        final h = imageProvider.height?.toDouble() ?? 842.0;
        format = PdfPageFormat(w, h, marginAll: 0);
        break;
    }

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          return pw.FullPage(
            ignoreMargins: true,
            child: pw.Center(
              child: pw.Image(imageProvider, fit: pw.BoxFit.contain),
            ),
          );
        },
      ),
    );
  }

  final pdfBytes = await pdf.save();
  final outputFile = File(params.outputPath);
  await outputFile.writeAsBytes(pdfBytes, flush: true);

  return params.outputPath;
}
