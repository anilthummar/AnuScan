import 'package:equatable/equatable.dart';
import 'package:anuscan/features/document_editor/domain/entities/scanned_page.dart';

/// Represents a saved multi-page scanned document.
class DocumentEntity extends Equatable {
  const DocumentEntity({
    required this.id,
    required this.title,
    required this.pdfPath,
    this.thumbnailPath,
    required this.pageCount,
    this.fileSizeBytes = 0,
    required this.createdAt,
    required this.updatedAt,
    this.pages = const [],
  });

  final String id;
  final String title;
  final String pdfPath;
  final String? thumbnailPath;
  final int pageCount;
  final int fileSizeBytes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ScannedPage> pages;

  DocumentEntity copyWith({
    String? id,
    String? title,
    String? pdfPath,
    String? thumbnailPath,
    int? pageCount,
    int? fileSizeBytes,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ScannedPage>? pages,
  }) {
    return DocumentEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      pdfPath: pdfPath ?? this.pdfPath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      pageCount: pageCount ?? this.pageCount,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pages: pages ?? this.pages,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        pdfPath,
        thumbnailPath,
        pageCount,
        fileSizeBytes,
        createdAt,
        updatedAt,
        pages,
      ];
}
