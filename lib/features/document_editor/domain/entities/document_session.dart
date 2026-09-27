import 'package:equatable/equatable.dart';
import '../../../../core/services/image_processing_service.dart';
import 'scanned_page.dart';

/// Represents a single page in a [DocumentSession].
class DocumentSessionPage extends Equatable {
  const DocumentSessionPage({
    required this.id,
    required this.imagePath,
    required this.order,
    this.rotation = 0,
    this.filter = ScanFilter.original,
    this.width = 0,
    this.height = 0,
    this.originalImagePath,
    this.corners,
    required this.createdAt,
  });

  final String id;
  final String imagePath;
  final int order;
  final int rotation;
  final ScanFilter filter;
  final int width;
  final int height;
  final String? originalImagePath;
  final CropCorners? corners;
  final DateTime createdAt;

  /// Creates a [DocumentSessionPage] from a [ScanPage].
  factory DocumentSessionPage.fromScanPage(ScanPage page) {
    return DocumentSessionPage(
      id: page.id,
      imagePath: page.processedImagePath,
      order: page.pageIndex,
      rotation: page.rotationDegrees,
      filter: page.filterType,
      width: page.width,
      height: page.height,
      originalImagePath: page.originalImagePath,
      corners: page.corners,
      createdAt: page.createdAt,
    );
  }

  /// Converts this [DocumentSessionPage] to a [ScanPage].
  ScanPage toScanPage({required String documentId}) {
    return ScanPage(
      id: id,
      documentId: documentId,
      pageIndex: order,
      originalImagePath: originalImagePath ?? imagePath,
      processedImagePath: imagePath,
      filterType: filter,
      rotationDegrees: rotation,
      corners: corners,
      width: width,
      height: height,
      createdAt: createdAt,
    );
  }

  DocumentSessionPage copyWith({
    String? id,
    String? imagePath,
    int? order,
    int? rotation,
    ScanFilter? filter,
    int? width,
    int? height,
    String? originalImagePath,
    CropCorners? corners,
    DateTime? createdAt,
  }) {
    return DocumentSessionPage(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      order: order ?? this.order,
      rotation: rotation ?? this.rotation,
      filter: filter ?? this.filter,
      width: width ?? this.width,
      height: height ?? this.height,
      originalImagePath: originalImagePath ?? this.originalImagePath,
      corners: corners ?? this.corners,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    imagePath,
    order,
    rotation,
    filter,
    width,
    height,
    originalImagePath,
    corners,
    createdAt,
  ];
}

/// Represents an active multi-page document scanning and editing session.
class DocumentSession extends Equatable {
  const DocumentSession({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.pages = const [],
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<DocumentSessionPage> pages;

  int get pageCount => pages.length;
  bool get isEmpty => pages.isEmpty;
  bool get isNotEmpty => pages.isNotEmpty;

  /// Creates a [DocumentSession] from a list of [ScanPage] items.
  factory DocumentSession.fromScanPages({
    required String id,
    required String name,
    required DateTime createdAt,
    required DateTime updatedAt,
    required List<ScanPage> scanPages,
  }) {
    return DocumentSession(
      id: id,
      name: name,
      createdAt: createdAt,
      updatedAt: updatedAt,
      pages: scanPages.map(DocumentSessionPage.fromScanPage).toList(),
    );
  }

  /// Converts this session's pages into a list of [ScanPage] objects.
  List<ScanPage> toScanPages() {
    return pages.map((p) => p.toScanPage(documentId: id)).toList();
  }

  DocumentSession copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<DocumentSessionPage>? pages,
  }) {
    return DocumentSession(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pages: pages ?? this.pages,
    );
  }

  @override
  List<Object?> get props => [id, name, createdAt, updatedAt, pages];
}
