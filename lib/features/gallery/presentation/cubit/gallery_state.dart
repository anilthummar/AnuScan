import 'package:equatable/equatable.dart';
import '../../../document_editor/domain/entities/scanned_page.dart';

/// Sealed hierarchy of states for the gallery import feature.
sealed class GalleryState extends Equatable {
  const GalleryState();

  @override
  List<Object?> get props => [];
}

/// Initial resting state when gallery screen is loaded.
class GalleryInitial extends GalleryState {
  const GalleryInitial();
}

/// Gallery picker dialog/system sheet is currently open.
class GalleryPicking extends GalleryState {
  const GalleryPicking();
}

/// Actively processing selected images through the document processing pipeline.
class GalleryProcessing extends GalleryState {
  const GalleryProcessing({
    required this.current,
    required this.total,
    required this.progress,
    this.message,
  });

  final int current;
  final int total;
  final double progress;
  final String? message;

  @override
  List<Object?> get props => [current, total, progress, message];
}

/// Successfully processed imported images into unified [ScannedPage] domain models.
class GallerySuccess extends GalleryState {
  const GallerySuccess({required this.pages, this.corruptedCount = 0});

  final List<ScannedPage> pages;
  final int corruptedCount;

  @override
  List<Object?> get props => [pages, corruptedCount];
}

/// User cancelled the gallery picker.
class GalleryCancelled extends GalleryState {
  const GalleryCancelled();
}

/// Failure state for permissions, device errors, or unreadable files.
class GalleryFailure extends GalleryState {
  const GalleryFailure({
    required this.message,
    this.isPermissionDenied = false,
  });

  final String message;
  final bool isPermissionDenied;

  @override
  List<Object?> get props => [message, isPermissionDenied];
}
