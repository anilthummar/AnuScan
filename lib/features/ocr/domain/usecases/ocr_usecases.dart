import '../../../../core/utils/result.dart';
import '../../../document_editor/domain/entities/scanned_page.dart';
import '../entities/ocr_entities.dart';
import '../repositories/ocr_repository.dart';

/// Sequentially executes OCR across all pages of a document session.
class ExtractDocumentTextUseCase {
  const ExtractDocumentTextUseCase(this._repository);

  final OcrRepository _repository;

  Stream<OcrProgressUpdate> call({
    required String documentId,
    required List<ScannedPage> pages,
    bool force = false,
  }) {
    return _repository.extractDocumentText(
      documentId: documentId,
      pages: pages,
      force: force,
    );
  }

  void cancel() {
    _repository.cancelCurrentOperation();
  }
}

/// Executes OCR on a single scanned page.
class ExtractPageTextUseCase {
  const ExtractPageTextUseCase(this._repository);

  final OcrRepository _repository;

  Future<Result<OcrPageResult>> call({
    required String documentId,
    required ScannedPage page,
    bool force = false,
  }) {
    return _repository.extractPageText(
      documentId: documentId,
      page: page,
      force: force,
    );
  }
}

/// Retrieves saved OCR text results for a document.
class GetDocumentOcrUseCase {
  const GetDocumentOcrUseCase(this._repository);

  final OcrRepository _repository;

  Future<Result<DocumentOcrResult>> call(String documentId) {
    return _repository.getDocumentOcr(documentId);
  }
}

/// Searches for text within a specific document.
class SearchDocumentTextUseCase {
  const SearchDocumentTextUseCase(this._repository);

  final OcrRepository _repository;

  Future<Result<List<OcrSearchMatch>>> call({
    required String documentId,
    required String query,
  }) {
    return _repository.searchInDocument(documentId: documentId, query: query);
  }
}

/// Searches for text across all stored documents using persisted OCR text.
class SearchAllDocumentsUseCase {
  const SearchAllDocumentsUseCase(this._repository);

  final OcrRepository _repository;

  Future<Result<List<OcrSearchMatch>>> call(String query) {
    return _repository.searchAcrossDocuments(query);
  }
}

/// Invalidates cached OCR when a page's content is modified.
class InvalidatePageOcrUseCase {
  const InvalidatePageOcrUseCase(this._repository);

  final OcrRepository _repository;

  Future<Result<void>> call(String pageId) {
    return _repository.invalidatePageOcr(pageId);
  }
}
