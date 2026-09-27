import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/file_storage_service.dart';
import '../../../../core/services/image_processing_service.dart';
import '../../../../core/services/pdf_generator_service.dart';
import '../../../../core/utils/result.dart';
import '../../../document_editor/domain/entities/document_session.dart';
import '../../../document_editor/domain/entities/scanned_page.dart';
import '../repositories/pdf_repository.dart';

/// Use case for compiling scanned pages or a [DocumentSession] into a persistent PDF file.
class GeneratePdfUseCase {
  const GeneratePdfUseCase({
    required this.pdfRepository,
    this.fileStorageService,
    this.imageProcessingService,
  });

  final PdfRepository pdfRepository;
  final FileStorageService? fileStorageService;
  final ImageProcessingService? imageProcessingService;

  /// Generates a PDF directly from an active [DocumentSession].
  Future<Result<String>> fromSession({
    required DocumentSession session,
    PdfPageSizeOption pageSize = PdfPageSizeOption.a4,
    PdfQualityOption quality = PdfQualityOption.standard,
    PdfProgressCallback? onProgress,
  }) {
    return pdfRepository.generatePdfFromSession(
      session: session,
      pageSize: pageSize,
      quality: quality,
      onProgress: onProgress,
    );
  }

  /// Generates a PDF from a list of [ScanPage] objects.
  Future<Result<String>> fromPages({
    required String documentId,
    required String title,
    required List<ScanPage> pages,
    PdfPageSizeOption pageSize = PdfPageSizeOption.a4,
    PdfQualityOption quality = PdfQualityOption.standard,
    PdfProgressCallback? onProgress,
  }) {
    return pdfRepository.generatePdfFromPages(
      documentId: documentId,
      title: title,
      pages: pages,
      pageSize: pageSize,
      quality: quality,
      onProgress: onProgress,
    );
  }

  /// Primary invocation method supporting both [session] and explicit page lists.
  Future<({String pdfPath, String thumbnailPath, int fileSizeBytes})> call({
    DocumentSession? session,
    String? documentId,
    String? title,
    List<ScanPage>? pages,
    PdfPageSizeOption pageSize = PdfPageSizeOption.a4,
    PdfQualityOption quality = PdfQualityOption.standard,
    PdfProgressCallback? onProgress,
  }) async {
    final effectiveId =
        session?.id ??
        documentId ??
        'doc_${DateTime.now().millisecondsSinceEpoch}';
    final effectiveTitle = session?.name ?? title ?? 'Document';
    final effectivePages = session != null
        ? session.toScanPages()
        : (pages ?? const <ScanPage>[]);

    final result = session != null
        ? await pdfRepository.generatePdfFromSession(
            session: session,
            pageSize: pageSize,
            quality: quality,
            onProgress: onProgress,
          )
        : await pdfRepository.generatePdfFromPages(
            documentId: effectiveId,
            title: effectiveTitle,
            pages: effectivePages,
            pageSize: pageSize,
            quality: quality,
            onProgress: onProgress,
          );

    if (result.isFailure) {
      throw PdfGenerationException(
        result.failureOrNull?.message ?? 'Failed to generate PDF',
      );
    }

    final pdfPath = result.dataOrNull!;
    String thumbnailPath = '';

    if (effectivePages.isNotEmpty &&
        fileStorageService != null &&
        imageProcessingService != null) {
      try {
        final docDir = await fileStorageService!.getOrCreateDocumentDirectory(
          effectiveId,
        );
        final thumbFile = p.join(docDir.path, 'thumb_$effectiveId.jpg');
        thumbnailPath = await imageProcessingService!.generateThumbnail(
          inputPath: effectivePages.first.processedImagePath,
          outputPath: thumbFile,
          targetWidth: 300,
        );
      } catch (_) {
        // Non-critical thumbnail failure
      }
    }

    final fileSize = await File(pdfPath).length();

    return (
      pdfPath: pdfPath,
      thumbnailPath: thumbnailPath,
      fileSizeBytes: fileSize,
    );
  }
}
