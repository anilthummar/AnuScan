import '../../../../core/utils/result.dart';
import '../../../document_editor/domain/entities/scanned_page.dart';
import '../entities/ocr_entities.dart';

/// Progress event emitted during sequential multi-page OCR execution.
class OcrProgressUpdate {
  const OcrProgressUpdate({
    required this.currentPageIndex,
    required this.totalPages,
    required this.progress,
    this.currentResult,
    required this.accumulatedResults,
    this.isCompleted = false,
    this.isCancelled = false,
    this.errorMessage,
  });

  final int currentPageIndex;
  final int totalPages;
  final double progress; // 0.0 to 1.0
  final OcrPageResult? currentResult;
  final List<OcrPageResult> accumulatedResults;
  final bool isCompleted;
  final bool isCancelled;
  final String? errorMessage;
}

/// Abstract contract for OCR extraction, local caching, search, and invalidation.
abstract class OcrRepository {
  /// Extracts text from a single page. If [force] is false and cached OCR is valid,
  /// returns cached result.
  Future<Result<OcrPageResult>> extractPageText({
    required String documentId,
    required ScannedPage page,
    bool force = false,
  });

  /// Sequentially extracts text across [pages] with streaming progress updates.
  Stream<OcrProgressUpdate> extractDocumentText({
    required String documentId,
    required List<ScannedPage> pages,
    bool force = false,
  });

  /// Retrieves persisted OCR results for a document.
  Future<Result<DocumentOcrResult>> getDocumentOcr(String documentId);

  /// Retrieves persisted OCR result for a single page.
  Future<Result<OcrPageResult?>> getPageOcr(String pageId);

  /// Searches for occurrences of [query] within a specific document.
  Future<Result<List<OcrSearchMatch>>> searchInDocument({
    required String documentId,
    required String query,
  });

  /// Searches for occurrences of [query] across all saved documents.
  Future<Result<List<OcrSearchMatch>>> searchAcrossDocuments(String query);

  /// Invalidates (deletes) OCR for a specific page when its image is edited.
  Future<Result<void>> invalidatePageOcr(String pageId);

  /// Deletes all OCR records for a document.
  Future<Result<void>> deleteDocumentOcr(String documentId);

  /// Cancels any currently active sequential OCR processing stream.
  void cancelCurrentOperation();
}
