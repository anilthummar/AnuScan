import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/usecases/import_gallery_images_usecase.dart';
import 'gallery_state.dart';

/// Cubit managing gallery image picking, permission handling, and pipeline progress.
class GalleryCubit extends Cubit<GalleryState> {
  GalleryCubit({required this.importGalleryImagesUseCase})
    : super(const GalleryInitial());

  final ImportGalleryImagesUseCase importGalleryImagesUseCase;
  bool _isCancelled = false;

  /// Launches the device photo picker, handles permission, and runs selected images through the pipeline.
  Future<void> pickAndProcessImages({
    required String documentId,
    int startIndex = 0,
  }) async {
    _isCancelled = false;
    emit(const GalleryPicking());

    final result = await importGalleryImagesUseCase(
      documentId: documentId,
      startIndex: startIndex,
      onProgress: (current, total) {
        if (!_isCancelled && !isClosed) {
          final progress = total > 0 ? current / total : 0.0;
          emit(
            GalleryProcessing(
              current: current,
              total: total,
              progress: progress,
              message: 'Processing image $current of $total...',
            ),
          );
        }
      },
    );

    if (_isCancelled || isClosed) return;

    result.fold(
      onSuccess: (pages) {
        if (pages.isEmpty) {
          emit(const GalleryCancelled());
        } else {
          emit(GallerySuccess(pages: pages));
        }
      },
      onFailure: (failure) {
        final isPerm = failure is PermissionFailure;
        emit(
          GalleryFailure(message: failure.message, isPermissionDenied: isPerm),
        );
      },
    );
  }

  /// Ingests a pre-selected list of [paths] through the document processing pipeline.
  Future<void> processRawPaths({
    required List<String> paths,
    required String documentId,
    int startIndex = 0,
  }) async {
    _isCancelled = false;
    if (paths.isEmpty) {
      emit(const GalleryCancelled());
      return;
    }

    emit(
      GalleryProcessing(
        current: 0,
        total: paths.length,
        progress: 0.0,
        message: 'Importing ${paths.length} images...',
      ),
    );

    final result = await importGalleryImagesUseCase(
      documentId: documentId,
      rawPaths: paths,
      startIndex: startIndex,
      onProgress: (current, total) {
        if (!_isCancelled && !isClosed) {
          final progress = total > 0 ? current / total : 0.0;
          emit(
            GalleryProcessing(
              current: current,
              total: total,
              progress: progress,
              message: 'Processing image $current of $total...',
            ),
          );
        }
      },
    );

    if (_isCancelled || isClosed) return;

    result.fold(
      onSuccess: (pages) {
        emit(GallerySuccess(pages: pages));
      },
      onFailure: (failure) {
        emit(
          GalleryFailure(
            message: failure.message,
            isPermissionDenied: failure is PermissionFailure,
          ),
        );
      },
    );
  }

  /// Cancels the ongoing operation and emits [GalleryCancelled].
  void cancel() {
    _isCancelled = true;
    emit(const GalleryCancelled());
  }

  /// Resets state back to [GalleryInitial].
  void reset() {
    _isCancelled = false;
    emit(const GalleryInitial());
  }
}
