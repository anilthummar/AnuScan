import 'package:equatable/equatable.dart';

/// Processing lifecycle states for OCR operations.
enum OcrStatus { notProcessed, processing, completed, failed, cancelled }

extension OcrStatusExtension on OcrStatus {
  String get displayName {
    switch (this) {
      case OcrStatus.notProcessed:
        return 'Not Processed';
      case OcrStatus.processing:
        return 'Processing';
      case OcrStatus.completed:
        return 'Completed';
      case OcrStatus.failed:
        return 'Failed';
      case OcrStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Represents a recognized text block or line with geometric bounds.
class OcrTextBlockEntity extends Equatable {
  const OcrTextBlockEntity({
    required this.text,
    this.confidence = 1.0,
    this.boundingBox,
  });

  final String text;
  final double confidence;
  final List<double>? boundingBox; // [left, top, right, bottom]

  @override
  List<Object?> get props => [text, confidence, boundingBox];
}

/// Extracted text and recognition metadata for a single document page.
class OcrPageResult extends Equatable {
  const OcrPageResult({
    required this.id,
    required this.documentId,
    required this.pageId,
    required this.pageIndex,
    required this.extractedText,
    this.blocks = const [],
    this.status = OcrStatus.completed,
    this.language,
    this.processingDurationMs,
    required this.imagePath,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String documentId;
  final String pageId;
  final int pageIndex;
  final String extractedText;
  final List<OcrTextBlockEntity> blocks;
  final OcrStatus status;
  final String? language;
  final int? processingDurationMs;
  final String imagePath;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasText => extractedText.trim().isNotEmpty;
  int get wordCount =>
      hasText ? extractedText.trim().split(RegExp(r'\s+')).length : 0;

  OcrPageResult copyWith({
    String? id,
    String? documentId,
    String? pageId,
    int? pageIndex,
    String? extractedText,
    List<OcrTextBlockEntity>? blocks,
    OcrStatus? status,
    String? language,
    int? processingDurationMs,
    String? imagePath,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OcrPageResult(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      pageId: pageId ?? this.pageId,
      pageIndex: pageIndex ?? this.pageIndex,
      extractedText: extractedText ?? this.extractedText,
      blocks: blocks ?? this.blocks,
      status: status ?? this.status,
      language: language ?? this.language,
      processingDurationMs: processingDurationMs ?? this.processingDurationMs,
      imagePath: imagePath ?? this.imagePath,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    documentId,
    pageId,
    pageIndex,
    extractedText,
    blocks,
    status,
    language,
    processingDurationMs,
    imagePath,
    errorMessage,
    createdAt,
    updatedAt,
  ];
}

/// Aggregated multi-page document OCR result.
class DocumentOcrResult extends Equatable {
  const DocumentOcrResult({
    required this.documentId,
    required this.pageResults,
    required this.combinedText,
    required this.status,
    required this.lastProcessedAt,
  });

  final String documentId;
  final List<OcrPageResult> pageResults;
  final String combinedText;
  final OcrStatus status;
  final DateTime lastProcessedAt;

  int get totalWordCount {
    if (combinedText.trim().isEmpty) return 0;
    return combinedText.trim().split(RegExp(r'\s+')).length;
  }

  int get pageCount => pageResults.length;

  bool get hasText => combinedText.trim().isNotEmpty;

  @override
  List<Object?> get props => [
    documentId,
    pageResults,
    combinedText,
    status,
    lastProcessedAt,
  ];
}

/// A search hit found within document OCR text.
class OcrSearchMatch extends Equatable {
  const OcrSearchMatch({
    required this.documentId,
    required this.documentTitle,
    required this.pageId,
    required this.pageIndex,
    required this.snippet,
    required this.matchCount,
    this.updatedAt,
  });

  final String documentId;
  final String documentTitle;
  final String pageId;
  final int pageIndex; // 0-based
  final String snippet;
  final int matchCount;
  final DateTime? updatedAt;

  int get displayPageNumber => pageIndex + 1;

  @override
  List<Object?> get props => [
    documentId,
    documentTitle,
    pageId,
    pageIndex,
    snippet,
    matchCount,
    updatedAt,
  ];
}
