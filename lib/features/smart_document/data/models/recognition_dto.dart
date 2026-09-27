import 'package:equatable/equatable.dart';

/// Data Transfer Object representing a document recognition & classification entry in SQLite.
class DocumentRecognitionDto extends Equatable {
  const DocumentRecognitionDto({
    required this.id,
    required this.documentId,
    required this.documentType,
    required this.classificationSource,
    required this.confidence,
    this.matchedSignals = '',
    required this.classifierVersion,
    this.suggestedFilename,
    this.personName,
    this.companyName,
    this.documentNumber,
    this.dateText,
    this.dueDateText,
    this.amountText,
    this.amount,
    this.currency,
    this.email,
    this.phone,
    this.website,
    this.metadataJson,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String documentId;
  final String documentType;
  final String classificationSource;
  final double confidence;
  final String matchedSignals;
  final String classifierVersion;
  final String? suggestedFilename;
  final String? personName;
  final String? companyName;
  final String? documentNumber;
  final String? dateText;
  final String? dueDateText;
  final String? amountText;
  final double? amount;
  final String? currency;
  final String? email;
  final String? phone;
  final String? website;
  final String? metadataJson;
  final int createdAt;
  final int updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'document_id': documentId,
      'document_type': documentType,
      'classification_source': classificationSource,
      'confidence': confidence,
      'matched_signals': matchedSignals,
      'classifier_version': classifierVersion,
      'suggested_filename': suggestedFilename,
      'person_name': personName,
      'company_name': companyName,
      'document_number': documentNumber,
      'date_text': dateText,
      'due_date_text': dueDateText,
      'amount_text': amountText,
      'amount': amount,
      'currency': currency,
      'email': email,
      'phone': phone,
      'website': website,
      'metadata_json': metadataJson,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory DocumentRecognitionDto.fromMap(Map<String, dynamic> map) {
    return DocumentRecognitionDto(
      id: map['id'] as String,
      documentId: map['document_id'] as String,
      documentType: map['document_type'] as String,
      classificationSource: map['classification_source'] as String,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      matchedSignals: (map['matched_signals'] as String?) ?? '',
      classifierVersion: (map['classifier_version'] as String?) ?? '1.0',
      suggestedFilename: map['suggested_filename'] as String?,
      personName: map['person_name'] as String?,
      companyName: map['company_name'] as String?,
      documentNumber: map['document_number'] as String?,
      dateText: map['date_text'] as String?,
      dueDateText: map['due_date_text'] as String?,
      amountText: map['amount_text'] as String?,
      amount: (map['amount'] as num?)?.toDouble(),
      currency: map['currency'] as String?,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      website: map['website'] as String?,
      metadataJson: map['metadata_json'] as String?,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
    );
  }

  @override
  List<Object?> get props => [
    id,
    documentId,
    documentType,
    classificationSource,
    confidence,
    matchedSignals,
    classifierVersion,
    suggestedFilename,
    personName,
    companyName,
    documentNumber,
    dateText,
    dueDateText,
    amountText,
    amount,
    currency,
    email,
    phone,
    website,
    metadataJson,
    createdAt,
    updatedAt,
  ];

  DocumentRecognitionDto copyWith({
    String? id,
    String? documentId,
    String? documentType,
    String? classificationSource,
    double? confidence,
    String? matchedSignals,
    String? classifierVersion,
    String? suggestedFilename,
    String? personName,
    String? companyName,
    String? documentNumber,
    String? dateText,
    String? dueDateText,
    String? amountText,
    double? amount,
    String? currency,
    String? email,
    String? phone,
    String? website,
    String? metadataJson,
    int? createdAt,
    int? updatedAt,
  }) {
    return DocumentRecognitionDto(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      documentType: documentType ?? this.documentType,
      classificationSource: classificationSource ?? this.classificationSource,
      confidence: confidence ?? this.confidence,
      matchedSignals: matchedSignals ?? this.matchedSignals,
      classifierVersion: classifierVersion ?? this.classifierVersion,
      suggestedFilename: suggestedFilename ?? this.suggestedFilename,
      personName: personName ?? this.personName,
      companyName: companyName ?? this.companyName,
      documentNumber: documentNumber ?? this.documentNumber,
      dateText: dateText ?? this.dateText,
      dueDateText: dueDateText ?? this.dueDateText,
      amountText: amountText ?? this.amountText,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      metadataJson: metadataJson ?? this.metadataJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
