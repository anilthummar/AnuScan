import 'package:equatable/equatable.dart';
import 'package:anuscan/features/document_editor/domain/entities/scanned_page.dart';
import 'tag_entity.dart';

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
    this.isFavorite = false,
    this.isArchived = false,
    this.isDeleted = false,
    this.isPrivate = false,
    this.deletedAt,
    this.folderId,
    this.folderName,
    this.tags = const [],
    this.lastOpenedAt,
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
  final bool isFavorite;
  final bool isArchived;
  final bool isDeleted;
  final bool isPrivate;
  final DateTime? deletedAt;
  final String? folderId;
  final String? folderName;
  final List<TagEntity> tags;
  final DateTime? lastOpenedAt;

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
    bool? isFavorite,
    bool? isArchived,
    bool? isDeleted,
    bool? isPrivate,
    DateTime? Function()? deletedAt,
    String? Function()? folderId,
    String? Function()? folderName,
    List<TagEntity>? tags,
    DateTime? Function()? lastOpenedAt,
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
      isFavorite: isFavorite ?? this.isFavorite,
      isArchived: isArchived ?? this.isArchived,
      isDeleted: isDeleted ?? this.isDeleted,
      isPrivate: isPrivate ?? this.isPrivate,
      deletedAt: deletedAt != null ? deletedAt() : this.deletedAt,
      folderId: folderId != null ? folderId() : this.folderId,
      folderName: folderName != null ? folderName() : this.folderName,
      tags: tags ?? this.tags,
      lastOpenedAt: lastOpenedAt != null ? lastOpenedAt() : this.lastOpenedAt,
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
    isFavorite,
    isArchived,
    isDeleted,
    isPrivate,
    deletedAt,
    folderId,
    folderName,
    tags,
    lastOpenedAt,
  ];
}
