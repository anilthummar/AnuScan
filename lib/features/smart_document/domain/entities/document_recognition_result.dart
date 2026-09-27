import 'package:equatable/equatable.dart';
import 'document_classification.dart';
import 'document_metadata.dart';

/// Aggregated recognition outcome for a document.
class DocumentRecognitionResult extends Equatable {
  const DocumentRecognitionResult({
    required this.documentId,
    required this.classification,
    required this.metadata,
    required this.suggestedFilename,
    this.recognitionVersion = '1.0',
    required this.createdAt,
    required this.updatedAt,
  });

  final String documentId;
  final DocumentClassification classification;
  final DocumentMetadata metadata;
  final String suggestedFilename;
  final String recognitionVersion;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isManual =>
      classification.isManual || metadata.source == ProvenanceSource.manual;

  DocumentRecognitionResult copyWith({
    String? documentId,
    DocumentClassification? classification,
    DocumentMetadata? metadata,
    String? suggestedFilename,
    String? recognitionVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DocumentRecognitionResult(
      documentId: documentId ?? this.documentId,
      classification: classification ?? this.classification,
      metadata: metadata ?? this.metadata,
      suggestedFilename: suggestedFilename ?? this.suggestedFilename,
      recognitionVersion: recognitionVersion ?? this.recognitionVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    documentId,
    classification,
    metadata,
    suggestedFilename,
    recognitionVersion,
    createdAt,
    updatedAt,
  ];
}
