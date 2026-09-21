import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../../core/services/file_storage_service.dart';
import '../../../../core/services/image_processing_service.dart';
import '../../../../core/services/pdf_generator_service.dart';
import '../../../../core/utils/file_utils.dart';
import '../../../document_editor/domain/entities/scanned_page.dart';

/// Use case for compiling scanned pages into a persistent PDF file.
class GeneratePdfUseCase {
  const GeneratePdfUseCase({
    required this.pdfGeneratorService,
    required this.fileStorageService,
    required this.imageProcessingService,
  });

  final PdfGeneratorService pdfGeneratorService;
  final FileStorageService fileStorageService;
  final ImageProcessingService imageProcessingService;

  Future<({String pdfPath, String thumbnailPath, int fileSizeBytes})> call({
    required String documentId,
    required String title,
    required List<ScannedPage> pages,
    PdfPageSizeOption pageSize = PdfPageSizeOption.a4,
  }) async {
    final docDir = await fileStorageService.getOrCreateDocumentDirectory(documentId);
    final sanitizedTitle = FileUtils.sanitizeFileName(title);
    final pdfOutputPath = p.join(docDir.path, '$sanitizedTitle.pdf');

    // Compile PDF
    final imagePaths = pages.map((p) => p.processedImagePath).toList();
    await pdfGeneratorService.generatePdf(
      imagePaths: imagePaths,
      outputPath: pdfOutputPath,
      pageSize: pageSize,
      title: title,
    );

    // Create thumbnail from first page if available
    String thumbnailPath = '';
    if (pages.isNotEmpty) {
      final thumbFile = p.join(docDir.path, 'thumb_$documentId.jpg');
      thumbnailPath = await imageProcessingService.generateThumbnail(
        inputPath: pages.first.processedImagePath,
        outputPath: thumbFile,
        targetWidth: 300,
      );
    }

    final fileSize = await File(pdfOutputPath).length();

    return (
      pdfPath: pdfOutputPath,
      thumbnailPath: thumbnailPath,
      fileSizeBytes: fileSize,
    );
  }
}
