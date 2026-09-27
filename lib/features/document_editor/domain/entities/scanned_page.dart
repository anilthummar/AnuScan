import 'package:equatable/equatable.dart';
import '../../../../core/services/image_processing_service.dart';

/// Represents a single page in a document scan session or stored document.
class ScannedPage extends Equatable {
  const ScannedPage({
    required this.id,
    required this.documentId,
    required this.pageIndex,
    required this.originalImagePath,
    required this.processedImagePath,
    this.filterType = DocumentFilterType.original,
    this.rotationDegrees = 0,
    this.corners,
    this.width = 0,
    this.height = 0,
    required this.createdAt,
  });

  final String id;
  final String documentId;
  final int pageIndex;
  final String originalImagePath;
  final String processedImagePath;
  final DocumentFilterType filterType;
  final int rotationDegrees;
  final DocumentCornerPoints? corners;
  final int width;
  final int height;
  final DateTime createdAt;

  int get order => pageIndex;
  int get rotation => rotationDegrees;
  DocumentFilterType get filter => filterType;
  String get imagePath => processedImagePath;

  ScannedPage copyWith({
    String? id,
    String? documentId,
    int? pageIndex,
    String? originalImagePath,
    String? processedImagePath,
    DocumentFilterType? filterType,
    int? rotationDegrees,
    DocumentCornerPoints? corners,
    int? width,
    int? height,
    DateTime? createdAt,
  }) {
    return ScannedPage(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      pageIndex: pageIndex ?? this.pageIndex,
      originalImagePath: originalImagePath ?? this.originalImagePath,
      processedImagePath: processedImagePath ?? this.processedImagePath,
      filterType: filterType ?? this.filterType,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      corners: corners ?? this.corners,
      width: width ?? this.width,
      height: height ?? this.height,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    documentId,
    pageIndex,
    originalImagePath,
    processedImagePath,
    filterType,
    rotationDegrees,
    corners,
    width,
    height,
    createdAt,
  ];
}

/// Domain model alias for [ScannedPage] satisfying ScanPage specification.
typedef ScanPage = ScannedPage;
