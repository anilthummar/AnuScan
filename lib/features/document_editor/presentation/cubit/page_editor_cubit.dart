import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/image_processing_service.dart';
import '../../domain/entities/scanned_page.dart';
import '../../domain/usecases/process_page_usecase.dart';
import 'page_editor_state.dart';

class PageEditorCubit extends Cubit<PageEditorState> {
  PageEditorCubit({
    required ScannedPage initialPage,
    required this.processPageUseCase,
  })  : _initialPage = initialPage,
        super(PageEditorState(
          currentPage: initialPage,
          selectedFilter: initialPage.filterType,
          currentRotation: initialPage.rotationDegrees,
          currentCorners: initialPage.corners,
        ));

  final ProcessPageUseCase processPageUseCase;
  final ScannedPage _initialPage;

  Future<void> setFilter(DocumentFilterType filter) async {
    if (state.selectedFilter == filter && !state.hasUnsavedChanges) return;

    emit(state.copyWith(
      isProcessing: true,
      selectedFilter: filter,
    ));

    try {
      final processed = await processPageUseCase(
        page: state.currentPage,
        filterType: filter,
        rotationDegrees: state.currentRotation,
        corners: state.currentCorners,
      );

      emit(state.copyWith(
        currentPage: processed,
        selectedFilter: filter,
        isProcessing: false,
        hasUnsavedChanges: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        isProcessing: false,
        errorMessage: 'Failed to apply filter: $e',
      ));
    }
  }

  Future<void> rotateClockwise() async {
    final nextRotation = (state.currentRotation + 90) % 360;

    emit(state.copyWith(
      isProcessing: true,
      currentRotation: nextRotation,
    ));

    try {
      final processed = await processPageUseCase(
        page: state.currentPage,
        filterType: state.selectedFilter,
        rotationDegrees: nextRotation,
        corners: state.currentCorners,
      );

      emit(state.copyWith(
        currentPage: processed,
        currentRotation: nextRotation,
        isProcessing: false,
        hasUnsavedChanges: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        isProcessing: false,
        errorMessage: 'Failed to rotate image: $e',
      ));
    }
  }

  Future<void> setCorners(DocumentCornerPoints corners) async {
    emit(state.copyWith(
      isProcessing: true,
      currentCorners: corners,
    ));

    try {
      final processed = await processPageUseCase(
        page: state.currentPage,
        filterType: state.selectedFilter,
        rotationDegrees: state.currentRotation,
        corners: corners,
      );

      emit(state.copyWith(
        currentPage: processed,
        currentCorners: corners,
        isProcessing: false,
        hasUnsavedChanges: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        isProcessing: false,
        errorMessage: 'Failed to rectify perspective: $e',
      ));
    }
  }

  Future<void> resetToOriginal() async {
    emit(state.copyWith(
      isProcessing: true,
    ));

    try {
      final processed = await processPageUseCase(
        page: _initialPage,
        filterType: DocumentFilterType.original,
        rotationDegrees: 0,
        corners: null,
      );

      emit(PageEditorState(
        currentPage: processed,
        selectedFilter: DocumentFilterType.original,
        currentRotation: 0,
        currentCorners: null,
        isProcessing: false,
        hasUnsavedChanges: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isProcessing: false,
        errorMessage: 'Failed to reset: $e',
      ));
    }
  }
}
