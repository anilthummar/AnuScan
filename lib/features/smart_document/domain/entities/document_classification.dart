import 'package:equatable/equatable.dart';

/// Supported classifications for scanned documents.
enum DocumentType {
  invoice,
  receipt,
  businessCard,
  identityDocument,
  form,
  certificate,
  letter,
  report,
  notes,
  contract,
  bankStatement,
  medicalDocument,
  taxDocument,
  other,
}

extension DocumentTypeExtension on DocumentType {
  String get displayName {
    switch (this) {
      case DocumentType.invoice:
        return 'Invoice';
      case DocumentType.receipt:
        return 'Receipt';
      case DocumentType.businessCard:
        return 'Business Card';
      case DocumentType.identityDocument:
        return 'Identity Document';
      case DocumentType.form:
        return 'Form';
      case DocumentType.certificate:
        return 'Certificate';
      case DocumentType.letter:
        return 'Letter';
      case DocumentType.report:
        return 'Report';
      case DocumentType.notes:
        return 'Notes';
      case DocumentType.contract:
        return 'Contract';
      case DocumentType.bankStatement:
        return 'Bank Statement';
      case DocumentType.medicalDocument:
        return 'Medical Document';
      case DocumentType.taxDocument:
        return 'Tax Document';
      case DocumentType.other:
        return 'Other';
    }
  }
}

/// Provenance tracking: whether classification was produced by algorithm or set manually by user.
enum ProvenanceSource { automatic, manual }

/// Classification outcome for a scanned document.
class DocumentClassification extends Equatable {
  const DocumentClassification({
    required this.type,
    required this.confidence,
    this.matchedSignals = const [],
    this.classifierVersion = '1.0',
    this.source = ProvenanceSource.automatic,
    this.explanation = '',
  });

  final DocumentType type;
  final double confidence; // Normalized 0.0 to 1.0
  final List<String> matchedSignals;
  final String classifierVersion;
  final ProvenanceSource source;
  final String explanation;

  bool get isConfident => confidence >= 0.5;
  bool get isManual => source == ProvenanceSource.manual;

  DocumentClassification copyWith({
    DocumentType? type,
    double? confidence,
    List<String>? matchedSignals,
    String? classifierVersion,
    ProvenanceSource? source,
    String? explanation,
  }) {
    return DocumentClassification(
      type: type ?? this.type,
      confidence: confidence ?? this.confidence,
      matchedSignals: matchedSignals ?? this.matchedSignals,
      classifierVersion: classifierVersion ?? this.classifierVersion,
      source: source ?? this.source,
      explanation: explanation ?? this.explanation,
    );
  }

  @override
  List<Object?> get props => [
    type,
    confidence,
    matchedSignals,
    classifierVersion,
    source,
    explanation,
  ];
}
