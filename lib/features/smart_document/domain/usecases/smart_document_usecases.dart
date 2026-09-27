import '../../../../core/utils/result.dart';
import '../../../document_editor/domain/entities/scanned_page.dart';
import '../entities/document_classification.dart';
import '../entities/document_metadata.dart';
import '../entities/document_recognition_result.dart';
import '../repositories/document_recognition_repository.dart';

/// Use case to run smart recognition on a document session or saved document.
class RecognizeDocumentUseCase {
  const RecognizeDocumentUseCase(this._repository);

  final DocumentRecognitionRepository _repository;

  Future<Result<DocumentRecognitionResult>> call({
    required String documentId,
    required List<ScannedPage> pages,
    bool force = false,
  }) {
    return _repository.recognizeDocument(
      documentId: documentId,
      pages: pages,
      force: force,
    );
  }
}

/// Use case to fetch persisted recognition for a document.
class GetDocumentRecognitionUseCase {
  const GetDocumentRecognitionUseCase(this._repository);

  final DocumentRecognitionRepository _repository;

  Future<Result<DocumentRecognitionResult?>> call(String documentId) {
    return _repository.getRecognition(documentId);
  }
}

/// Use case to override document type manually.
class OverrideDocumentTypeUseCase {
  const OverrideDocumentTypeUseCase(this._repository);

  final DocumentRecognitionRepository _repository;

  Future<Result<void>> call({
    required String documentId,
    required DocumentType manualType,
  }) {
    return _repository.updateManualClassification(
      documentId: documentId,
      manualType: manualType,
    );
  }
}

/// Use case to update document metadata manually.
class UpdateDocumentMetadataUseCase {
  const UpdateDocumentMetadataUseCase(this._repository);

  final DocumentRecognitionRepository _repository;

  Future<Result<void>> call({
    required String documentId,
    required DocumentMetadata updatedMetadata,
  }) {
    return _repository.updateManualMetadata(
      documentId: documentId,
      updatedMetadata: updatedMetadata,
    );
  }
}

/// Use case to generate a smart filename suggestion.
class SuggestDocumentNameUseCase {
  const SuggestDocumentNameUseCase(this._repository);

  final DocumentRecognitionRepository _repository;

  Future<Result<String>> call({
    required DocumentClassification classification,
    required DocumentMetadata metadata,
    String? fallbackName,
  }) {
    return _repository.suggestFilename(
      classification: classification,
      metadata: metadata,
      fallbackName: fallbackName,
    );
  }
}
