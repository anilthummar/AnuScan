import '../../domain/entities/document_entity.dart';
import '../../domain/entities/tag_entity.dart';
import '../../../document_editor/domain/entities/scanned_page.dart';
import '../../../../core/services/image_processing_service.dart';
import 'tag_dto.dart';

class DocumentDto {
  const DocumentDto({
    required this.id,
    required this.title,
    required this.pdfPath,
    this.thumbnailPath,
    required this.pageCount,
    this.fileSizeBytes = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isFavorite = false,
    this.isArchived = false,
    this.isDeleted = false,
    this.isPrivate = false,
    this.deletedAt,
    this.folderId,
    this.folderName,
    this.lastOpenedAt,
    this.tags = const [],
  });

  final String id;
  final String title;
  final String pdfPath;
  final String? thumbnailPath;
  final int pageCount;
  final int fileSizeBytes;
  final int createdAt; // epoch ms
  final int updatedAt; // epoch ms
  final bool isFavorite;
  final bool isArchived;
  final bool isDeleted;
  final bool isPrivate;
  final int? deletedAt; // epoch ms
  final String? folderId;
  final String? folderName;
  final int? lastOpenedAt; // epoch ms
  final List<TagDto> tags;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'pdf_path': pdfPath,
      'thumbnail_path': thumbnailPath,
      'page_count': pageCount,
      'file_size_bytes': fileSizeBytes,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_favorite': isFavorite ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
      'is_private': isPrivate ? 1 : 0,
      'deleted_at': deletedAt,
      'folder_id': folderId,
      'last_opened_at': lastOpenedAt,
    };
  }

  factory DocumentDto.fromMap(
    Map<String, dynamic> map, {
    String? folderName,
    List<TagDto> tags = const [],
  }) {
    return DocumentDto(
      id: map['id'] as String,
      title: map['title'] as String,
      pdfPath: map['pdf_path'] as String,
      thumbnailPath: map['thumbnail_path'] as String?,
      pageCount: (map['page_count'] as num?)?.toInt() ?? 0,
      fileSizeBytes: (map['file_size_bytes'] as num?)?.toInt() ?? 0,
      createdAt: (map['created_at'] as num).toInt(),
      updatedAt: (map['updated_at'] as num).toInt(),
      isFavorite: (map['is_favorite'] as num?)?.toInt() == 1,
      isArchived: (map['is_archived'] as num?)?.toInt() == 1,
      isDeleted: (map['is_deleted'] as num?)?.toInt() == 1,
      isPrivate: (map['is_private'] as num?)?.toInt() == 1,
      deletedAt: (map['deleted_at'] as num?)?.toInt(),
      folderId: map['folder_id'] as String?,
      folderName: folderName ?? map['folder_name'] as String?,
      lastOpenedAt: (map['last_opened_at'] as num?)?.toInt(),
      tags: tags,
    );
  }

  factory DocumentDto.fromEntity(DocumentEntity entity) {
    return DocumentDto(
      id: entity.id,
      title: entity.title,
      pdfPath: entity.pdfPath,
      thumbnailPath: entity.thumbnailPath,
      pageCount: entity.pageCount,
      fileSizeBytes: entity.fileSizeBytes,
      createdAt: entity.createdAt.millisecondsSinceEpoch,
      updatedAt: entity.updatedAt.millisecondsSinceEpoch,
      isFavorite: entity.isFavorite,
      isArchived: entity.isArchived,
      isDeleted: entity.isDeleted,
      isPrivate: entity.isPrivate,
      deletedAt: entity.deletedAt?.millisecondsSinceEpoch,
      folderId: entity.folderId,
      folderName: entity.folderName,
      lastOpenedAt: entity.lastOpenedAt?.millisecondsSinceEpoch,
      tags: entity.tags.map((t) => TagDto.fromEntity(t)).toList(),
    );
  }

  DocumentEntity toEntity({
    List<ScannedPage> pages = const [],
    List<TagEntity>? overrideTags,
  }) {
    return DocumentEntity(
      id: id,
      title: title,
      pdfPath: pdfPath,
      thumbnailPath: thumbnailPath,
      pageCount: pageCount,
      fileSizeBytes: fileSizeBytes,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
      pages: pages,
      isFavorite: isFavorite,
      isArchived: isArchived,
      isDeleted: isDeleted,
      isPrivate: isPrivate,
      deletedAt: deletedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(deletedAt!)
          : null,
      folderId: folderId,
      folderName: folderName,
      lastOpenedAt: lastOpenedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(lastOpenedAt!)
          : null,
      tags: overrideTags ?? tags.map((t) => t.toEntity()).toList(),
    );
  }
}

class DocumentPageDto {
  const DocumentPageDto({
    required this.id,
    required this.documentId,
    required this.pageIndex,
    required this.originalImagePath,
    required this.processedImagePath,
    required this.filterType,
    required this.rotationDegrees,
    required this.width,
    required this.height,
    required this.createdAt,
  });

  final String id;
  final String documentId;
  final int pageIndex;
  final String originalImagePath;
  final String processedImagePath;
  final String filterType;
  final int rotationDegrees;
  final int width;
  final int height;
  final int createdAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'document_id': documentId,
      'page_index': pageIndex,
      'original_image_path': originalImagePath,
      'processed_image_path': processedImagePath,
      'filter_type': filterType,
      'rotation_degrees': rotationDegrees,
      'width': width,
      'height': height,
      'created_at': createdAt,
    };
  }

  factory DocumentPageDto.fromMap(Map<String, dynamic> map) {
    return DocumentPageDto(
      id: map['id'] as String,
      documentId: map['document_id'] as String,
      pageIndex: (map['page_index'] as num).toInt(),
      originalImagePath: map['original_image_path'] as String,
      processedImagePath: map['processed_image_path'] as String,
      filterType: map['filter_type'] as String? ?? 'original',
      rotationDegrees: (map['rotation_degrees'] as num?)?.toInt() ?? 0,
      width: (map['width'] as num?)?.toInt() ?? 0,
      height: (map['height'] as num?)?.toInt() ?? 0,
      createdAt: (map['created_at'] as num).toInt(),
    );
  }

  factory DocumentPageDto.fromEntity(ScannedPage entity) {
    return DocumentPageDto(
      id: entity.id,
      documentId: entity.documentId,
      pageIndex: entity.pageIndex,
      originalImagePath: entity.originalImagePath,
      processedImagePath: entity.processedImagePath,
      filterType: entity.filterType.name,
      rotationDegrees: entity.rotationDegrees,
      width: entity.width,
      height: entity.height,
      createdAt: entity.createdAt.millisecondsSinceEpoch,
    );
  }

  ScannedPage toEntity() {
    return ScannedPage(
      id: id,
      documentId: documentId,
      pageIndex: pageIndex,
      originalImagePath: originalImagePath,
      processedImagePath: processedImagePath,
      filterType: DocumentFilterTypeExtension.fromString(filterType),
      rotationDegrees: rotationDegrees,
      width: width,
      height: height,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
    );
  }
}
