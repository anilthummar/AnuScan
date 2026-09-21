import '../../domain/entities/document_entity.dart';
import '../../../document_editor/domain/entities/scanned_page.dart';
import '../../../../core/services/image_processing_service.dart';

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
  });

  final String id;
  final String title;
  final String pdfPath;
  final String? thumbnailPath;
  final int pageCount;
  final int fileSizeBytes;
  final int createdAt; // epoch ms
  final int updatedAt; // epoch ms

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
    };
  }

  factory DocumentDto.fromMap(Map<String, dynamic> map) {
    return DocumentDto(
      id: map['id'] as String,
      title: map['title'] as String,
      pdfPath: map['pdf_path'] as String,
      thumbnailPath: map['thumbnail_path'] as String?,
      pageCount: (map['page_count'] as num?)?.toInt() ?? 0,
      fileSizeBytes: (map['file_size_bytes'] as num?)?.toInt() ?? 0,
      createdAt: (map['created_at'] as num).toInt(),
      updatedAt: (map['updated_at'] as num).toInt(),
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
    );
  }

  DocumentEntity toEntity({List<ScannedPage> pages = const []}) {
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
