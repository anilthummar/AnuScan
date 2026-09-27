import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/image_processing_service.dart';
import '../../domain/entities/scanned_page.dart';
import '../../domain/usecases/edit_scan_page_usecase.dart';
import 'page_editor_state.dart';

/// Cubit managing the editing lifecycle of an individual [ScanPage].
///
/// Dispatches all heavy operations (crop/perspective rectification, rotation, visual filtering)
/// to [EditScanPageUseCase] and background isolates, ensuring the UI thread remains 100% responsive.
class PageEditorCubit extends Cubit<PageEditorState> {
  PageEditorCubit({
    required ScanPage initialPage,
    required this.editScanPageUseCase,
  }) : _initialPage = initialPage,
       super(
         PageEditorState(
           currentPage: initialPage,
           selectedFilter: initialPage.filterType,
           currentRotation: initialPage.rotationDegrees,
           currentCorners: initialPage.corners,
         ),
       );

  final EditScanPageUseCase editScanPageUseCase;
  final ScanPage _initialPage;

  EditScanPageUseCase get processPageUseCase => editScanPageUseCase;

  /// Applies one of the 5 visual filters: Original, Color, Grayscale, B&W, Enhanced.
  Future<void> setFilter(ScanFilter filter, {BwIntensity? bwIntensity}) async {
    final effectiveIntensity = bwIntensity ?? state.bwIntensity;
    if (state.selectedFilter == filter &&
        state.bwIntensity == effectiveIntensity &&
        !state.hasUnsavedChanges) {
      return;
    }

    emit(
      state.copyWith(
        isProcessing: true,
        selectedFilter: filter,
        bwIntensity: effectiveIntensity,
      ),
    );

    try {
      final processed = await editScanPageUseCase(
        page: state.currentPage,
        filterType: filter,
        rotationDegrees: state.currentRotation,
        corners: state.currentCorners,
        bwIntensity: effectiveIntensity,
      );

      emit(
        state.copyWith(
          currentPage: processed,
          selectedFilter: filter,
          bwIntensity: effectiveIntensity,
          isProcessing: false,
          hasUnsavedChanges: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isProcessing: false,
          errorMessage: 'Failed to apply filter: $e',
        ),
      );
    }
  }

  /// Sets intensity level (Low / Medium / High) for Black & White filter.
  Future<void> setBwIntensity(BwIntensity intensity) async {
    return setFilter(ScanFilter.blackAndWhite, bwIntensity: intensity);
  }

  /// Rotates the page 90 degrees clockwise (0° -> 90° -> 180° -> 270° -> 0°).
  Future<void> rotateClockwise() async {
    final nextRotation = (state.currentRotation + 90) % 360;

    emit(state.copyWith(isProcessing: true, currentRotation: nextRotation));

    try {
      final processed = await editScanPageUseCase(
        page: state.currentPage,
        filterType: state.selectedFilter,
        rotationDegrees: nextRotation,
        corners: state.currentCorners,
        bwIntensity: state.bwIntensity,
      );

      emit(
        state.copyWith(
          currentPage: processed,
          currentRotation: nextRotation,
          isProcessing: false,
          hasUnsavedChanges: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isProcessing: false,
          errorMessage: 'Failed to rotate image: $e',
        ),
      );
    }
  }

  /// Rotates the page 90 degrees counter-clockwise.
  Future<void> rotateCounterClockwise() async {
    final nextRotation = (state.currentRotation - 90 + 360) % 360;

    emit(state.copyWith(isProcessing: true, currentRotation: nextRotation));

    try {
      final processed = await editScanPageUseCase(
        page: state.currentPage,
        filterType: state.selectedFilter,
        rotationDegrees: nextRotation,
        corners: state.currentCorners,
        bwIntensity: state.bwIntensity,
      );

      emit(
        state.copyWith(
          currentPage: processed,
          currentRotation: nextRotation,
          isProcessing: false,
          hasUnsavedChanges: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isProcessing: false,
          errorMessage: 'Failed to rotate image: $e',
        ),
      );
    }
  }

  /// Updates the 4 corner coordinates and applies perspective correction / cropping.
  Future<void> setCorners(CropCorners corners) async {
    emit(state.copyWith(isProcessing: true, currentCorners: corners));

    try {
      final processed = await editScanPageUseCase(
        page: state.currentPage,
        filterType: state.selectedFilter,
        rotationDegrees: state.currentRotation,
        corners: corners,
        bwIntensity: state.bwIntensity,
      );

      emit(
        state.copyWith(
          currentPage: processed,
          currentCorners: corners,
          isProcessing: false,
          hasUnsavedChanges: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isProcessing: false,
          errorMessage: 'Failed to rectify perspective: $e',
        ),
      );
    }
  }

  /// Resets crop corners back to full bounds without altering rotation or filter.
  Future<void> resetCrop() async {
    emit(state.copyWith(isProcessing: true));

    try {
      final processed = await editScanPageUseCase(
        page: state.currentPage,
        filterType: state.selectedFilter,
        rotationDegrees: state.currentRotation,
        corners: CropCorners.fullBounds(),
        bwIntensity: state.bwIntensity,
      );

      emit(
        state.copyWith(
          currentPage: processed,
          clearCorners: true,
          isProcessing: false,
          hasUnsavedChanges: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isProcessing: false,
          errorMessage: 'Failed to reset crop: $e',
        ),
      );
    }
  }

  /// Reverts all modifications back to the original source image and initial state.
  Future<void> resetToOriginal() async {
    emit(state.copyWith(isProcessing: true));

    try {
      final processed = await editScanPageUseCase(
        page: _initialPage,
        filterType: ScanFilter.original,
        rotationDegrees: 0,
        corners: CropCorners.fullBounds(),
      );

      emit(
        PageEditorState(
          currentPage: processed,
          selectedFilter: ScanFilter.original,
          currentRotation: 0,
          currentCorners: null,
          isProcessing: false,
          hasUnsavedChanges: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isProcessing: false,
          errorMessage: 'Failed to reset: $e',
        ),
      );
    }
  }

  /// Returns the current edited [ScanPage].
  ScanPage save() => state.currentPage;
}
