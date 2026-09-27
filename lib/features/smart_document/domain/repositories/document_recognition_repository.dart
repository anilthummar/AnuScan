import '../../../../core/utils/result.dart';
import '../../../document_editor/domain/entities/scanned_page.dart';
import '../entities/document_classification.dart';
import '../entities/document_metadata.dart';
import '../entities/document_recognition_result.dart';

/// Abstract contract for document recognition, classification, metadata extraction,
/// smart filename suggestion, and local persistence.
abstract class DocumentRecognitionRepository {
  /// Analyzes document pages and OCR text, returning recognition result.
  /// If cached result exists and [force] is false, returns cached result unless manual.
  Future<Result<DocumentRecognitionResult>> recognizeDocument({
    required String documentId,
    required List<ScannedPage> pages,
    bool force = false,
  });

  /// Retrieves persisted recognition result for [documentId] if available.
  Future<Result<DocumentRecognitionResult?>> getRecognition(String documentId);

  /// Saves or updates document recognition result in local storage.
  Future<Result<void>> saveRecognition(DocumentRecognitionResult result);

  /// Updates document type manually, setting provenance to [ProvenanceSource.manual].
  Future<Result<void>> updateManualClassification({
    required String documentId,
    required DocumentType manualType,
  });

  /// Updates document metadata manually, setting provenance to [ProvenanceSource.manual].
  Future<Result<void>> updateManualMetadata({
    required String documentId,
    required DocumentMetadata updatedMetadata,
  });

  /// Deletes stored recognition result for [documentId].
  Future<Result<void>> deleteRecognition(String documentId);

  /// Computes a sanitized, prioritized smart filename suggestion.
  Future<Result<String>> suggestFilename({
    required DocumentClassification classification,
    required DocumentMetadata metadata,
    String? fallbackName,
  });
}
