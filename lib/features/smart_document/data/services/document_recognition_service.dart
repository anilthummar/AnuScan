import '../../domain/entities/document_recognition_result.dart';
import 'document_classifier.dart';
import 'document_metadata_extractor.dart';
import 'smart_filename_generator.dart';

/// Aggregation service that executes deterministic classification, metadata extraction,
/// and smart filename generation in sequence.
class DocumentRecognitionService {
  const DocumentRecognitionService({
    this.classifier = const DocumentClassifier(),
    this.metadataExtractor = const DocumentMetadataExtractor(),
    this.filenameGenerator = const SmartFilenameGenerator(),
  });

  final DocumentClassifier classifier;
  final DocumentMetadataExtractor metadataExtractor;
  final SmartFilenameGenerator filenameGenerator;

  /// Runs full document recognition on [combinedText].
  Future<DocumentRecognitionResult> recognize({
    required String documentId,
    required String combinedText,
    String? fallbackName,
  }) async {
    // 1. Classify document
    final classification = classifier.classify(combinedText);

    // 2. Extract metadata
    final metadata = metadataExtractor.extract(
      rawText: combinedText,
      classification: classification,
    );

    // 3. Generate suggested filename
    final suggestedFilename = filenameGenerator.generate(
      classification: classification,
      metadata: metadata,
      fallbackName: fallbackName,
    );

    final now = DateTime.now();
    return DocumentRecognitionResult(
      documentId: documentId,
      classification: classification,
      metadata: metadata,
      suggestedFilename: suggestedFilename,
      recognitionVersion: DocumentClassifier.currentVersion,
      createdAt: now,
      updatedAt: now,
    );
  }
}
