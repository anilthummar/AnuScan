import '../../../../core/services/pdf_generator_service.dart';
import '../../../../core/utils/result.dart';
import '../../../document_editor/domain/entities/document_session.dart';
import '../../../document_editor/domain/entities/scanned_page.dart';

/// Contract for generating and persisting multi-page PDF documents.
abstract class PdfRepository {
  /// Generates a single PDF document from an active [DocumentSession],
  /// compiling pages in their exact session order.
  Future<Result<String>> generatePdfFromSession({
    required DocumentSession session,
    PdfPageSizeOption pageSize = PdfPageSizeOption.a4,
    PdfQualityOption quality = PdfQualityOption.standard,
    PdfProgressCallback? onProgress,
  });

  /// Generates a single PDF document from a list of [ScanPage] objects.
  Future<Result<String>> generatePdfFromPages({
    required String documentId,
    required String title,
    required List<ScanPage> pages,
    PdfPageSizeOption pageSize = PdfPageSizeOption.a4,
    PdfQualityOption quality = PdfQualityOption.standard,
    PdfProgressCallback? onProgress,
  });
}
