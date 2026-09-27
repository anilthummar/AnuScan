import 'package:path/path.dart' as p;
import '../../../../core/errors/failures.dart';
import '../../../../core/services/file_storage_service.dart';
import '../../../../core/services/pdf_generator_service.dart';
import '../../../../core/utils/file_utils.dart';
import '../../../../core/utils/result.dart';
import '../../../document_editor/domain/entities/document_session.dart';
import '../../../document_editor/domain/entities/scanned_page.dart';
import '../../domain/repositories/pdf_repository.dart';

/// Concrete implementation of [PdfRepository] utilizing [PdfGeneratorService]
/// and [FileStorageService] for isolated storage.
class PdfRepositoryImpl implements PdfRepository {
  const PdfRepositoryImpl({
    required this.pdfGeneratorService,
    required this.fileStorageService,
  });

  final PdfGeneratorService pdfGeneratorService;
  final FileStorageService fileStorageService;

  @override
  Future<Result<String>> generatePdfFromSession({
    required DocumentSession session,
    PdfPageSizeOption pageSize = PdfPageSizeOption.a4,
    PdfQualityOption quality = PdfQualityOption.standard,
    PdfProgressCallback? onProgress,
  }) async {
    try {
      if (session.pages.isEmpty) {
        return const Result.failure(
          PdfGenerationFailure(
            'Cannot generate PDF from an empty document session',
          ),
        );
      }

      // Read pages in their current sequence order
      final sortedPages = List<DocumentSessionPage>.from(session.pages)
        ..sort((a, b) => a.order.compareTo(b.order));

      final imagePaths = sortedPages.map((p) => p.imagePath).toList();

      final docDir = await fileStorageService.getOrCreateDocumentDirectory(
        session.id,
      );
      final sanitizedTitle = FileUtils.sanitizeFileName(session.name);
      final outputPath = p.join(docDir.path, '$sanitizedTitle.pdf');

      final generatedPath = await pdfGeneratorService.generatePdf(
        imagePaths: imagePaths,
        outputPath: outputPath,
        pageSize: pageSize,
        quality: quality,
        title: session.name,
        onProgress: onProgress,
      );

      return Result.success(generatedPath);
    } catch (e) {
      return Result.failure(
        PdfGenerationFailure('Failed to generate PDF: $e', e),
      );
    }
  }

  @override
  Future<Result<String>> generatePdfFromPages({
    required String documentId,
    required String title,
    required List<ScanPage> pages,
    PdfPageSizeOption pageSize = PdfPageSizeOption.a4,
    PdfQualityOption quality = PdfQualityOption.standard,
    PdfProgressCallback? onProgress,
  }) async {
    try {
      if (pages.isEmpty) {
        return const Result.failure(
          PdfGenerationFailure('Cannot generate PDF from zero pages'),
        );
      }

      // Sort pages by pageIndex/order
      final sortedPages = List<ScanPage>.from(pages)
        ..sort((a, b) => a.pageIndex.compareTo(b.pageIndex));

      final imagePaths = sortedPages.map((p) => p.processedImagePath).toList();

      final docDir = await fileStorageService.getOrCreateDocumentDirectory(
        documentId,
      );
      final sanitizedTitle = FileUtils.sanitizeFileName(title);
      final outputPath = p.join(docDir.path, '$sanitizedTitle.pdf');

      final generatedPath = await pdfGeneratorService.generatePdf(
        imagePaths: imagePaths,
        outputPath: outputPath,
        pageSize: pageSize,
        quality: quality,
        title: title,
        onProgress: onProgress,
      );

      return Result.success(generatedPath);
    } catch (e) {
      return Result.failure(
        PdfGenerationFailure('Failed to generate PDF: $e', e),
      );
    }
  }
}
