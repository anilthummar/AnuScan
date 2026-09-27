import 'package:equatable/equatable.dart';

/// Data Transfer Object representing a single page OCR result in SQLite.
class OcrPageResultDto extends Equatable {
  const OcrPageResultDto({
    required this.id,
    required this.documentId,
    required this.pageId,
    required this.pageIndex,
    required this.extractedText,
    required this.status,
    this.language,
    this.processingDurationMs,
    required this.imagePath,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String documentId;
  final String pageId;
  final int pageIndex;
  final String extractedText;
  final String status;
  final String? language;
  final int? processingDurationMs;
  final String imagePath;
  final int createdAt;
  final int updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'document_id': documentId,
      'page_id': pageId,
      'page_index': pageIndex,
      'extracted_text': extractedText,
      'status': status,
      'language': language,
      'processing_duration_ms': processingDurationMs,
      'image_path': imagePath,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory OcrPageResultDto.fromMap(Map<String, dynamic> map) {
    return OcrPageResultDto(
      id: map['id'] as String,
      documentId: map['document_id'] as String,
      pageId: map['page_id'] as String,
      pageIndex: map['page_index'] as int,
      extractedText: map['extracted_text'] as String,
      status: map['status'] as String,
      language: map['language'] as String?,
      processingDurationMs: map['processing_duration_ms'] as int?,
      imagePath: map['image_path'] as String,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
    );
  }

  @override
  List<Object?> get props => [
    id,
    documentId,
    pageId,
    pageIndex,
    extractedText,
    status,
    language,
    processingDurationMs,
    imagePath,
    createdAt,
    updatedAt,
  ];
}
