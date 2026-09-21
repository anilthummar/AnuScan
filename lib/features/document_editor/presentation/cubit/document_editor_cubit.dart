import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/file_storage_service.dart';
import '../../../../core/services/image_processing_service.dart';
import '../../domain/entities/scanned_page.dart';
import '../../domain/usecases/process_page_usecase.dart';
import '../../domain/usecases/reorder_pages_usecase.dart';
import 'document_editor_state.dart';

class DocumentEditorCubit extends Cubit<DocumentEditorState> {
  DocumentEditorCubit({
    required this.fileStorageService,
    required this.imageProcessingService,
    required this.processPageUseCase,
    required this.reorderPagesUseCase,
    required String documentId,
    required String initialTitle,
  }) : super(DocumentEditorState(
          documentId: documentId,
          title: initialTitle,
        ));

  final FileStorageService fileStorageService;
  final ImageProcessingService imageProcessingService;
  final ProcessPageUseCase processPageUseCase;
  final ReorderPagesUseCase reorderPagesUseCase;

  /// Ingests a list of newly scanned or imported image file paths.
  Future<void> addImages(List<String> rawPaths) async {
    if (rawPaths.isEmpty) return;

    emit(state.copyWith(
      isProcessing: true,
      processingMessage: 'Importing pages...',
    ));

    try {
      final newPages = <ScannedPage>[];
      var startIndex = state.pages.length;

      for (final rawPath in rawPaths) {
        final pageId = const Uuid().v4();
        // Persist original image into dedicated document storage folder
        final storedOriginal = await fileStorageService.copyImageFile(
          state.documentId,
          rawPath,
          filename: 'orig_$pageId.jpg',
        );

        // Initially, processed image is identical to original
        final storedProcessed = await fileStorageService.copyImageFile(
          state.documentId,
          rawPath,
          filename: 'proc_$pageId.jpg',
        );

        final (w, h) = await imageProcessingService.getImageDimensions(storedProcessed);

        newPages.add(ScannedPage(
          id: pageId,
          documentId: state.documentId,
          pageIndex: startIndex++,
          originalImagePath: storedOriginal,
          processedImagePath: storedProcessed,
          filterType: DocumentFilterType.original,
          rotationDegrees: 0,
          width: w,
          height: h,
          createdAt: DateTime.now(),
        ));
      }

      final updatedPages = List<ScannedPage>.from(state.pages)..addAll(newPages);

      emit(state.copyWith(
        pages: updatedPages,
        isProcessing: false,
        processingMessage: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        isProcessing: false,
        errorMessage: 'Failed to import images: $e',
      ));
    }
  }

  void selectPage(int index) {
    if (index >= 0 && index < state.pages.length) {
      emit(state.copyWith(selectedPageIndex: index));
    }
  }

  void reorderPages(int oldIndex, int newIndex) {
    final reordered = reorderPagesUseCase(
      pages: state.pages,
      oldIndex: oldIndex,
      newIndex: newIndex,
    );
    emit(state.copyWith(pages: reordered));
  }

  void deletePage(int index) {
    if (index < 0 || index >= state.pages.length) return;

    final updated = List<ScannedPage>.from(state.pages)..removeAt(index);
    // Re-index remaining pages
    final reindexed = [
      for (int i = 0; i < updated.length; i++) updated[i].copyWith(pageIndex: i),
    ];

    var newSelectedIndex = state.selectedPageIndex;
    if (newSelectedIndex >= reindexed.length) {
      newSelectedIndex = reindexed.isEmpty ? 0 : reindexed.length - 1;
    }

    emit(state.copyWith(
      pages: reindexed,
      selectedPageIndex: newSelectedIndex,
    ));
  }

  Future<void> rotatePage(int index) async {
    if (index < 0 || index >= state.pages.length) return;

    final targetPage = state.pages[index];
    final nextRotation = (targetPage.rotationDegrees + 90) % 360;

    emit(state.copyWith(
      isProcessing: true,
      processingMessage: 'Rotating page...',
    ));

    try {
      final processed = await processPageUseCase(
        page: targetPage,
        rotationDegrees: nextRotation,
      );

      final updatedPages = List<ScannedPage>.from(state.pages);
      updatedPages[index] = processed;

      emit(state.copyWith(
        pages: updatedPages,
        isProcessing: false,
        processingMessage: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        isProcessing: false,
        errorMessage: 'Failed to rotate page: $e',
      ));
    }
  }

  void updatePage(ScannedPage updatedPage) {
    final index = state.pages.indexWhere((p) => p.id == updatedPage.id);
    if (index != -1) {
      final updatedList = List<ScannedPage>.from(state.pages);
      updatedList[index] = updatedPage;
      emit(state.copyWith(pages: updatedList));
    }
  }

  void updateTitle(String newTitle) {
    final sanitized = newTitle.trim();
    if (sanitized.isNotEmpty) {
      emit(state.copyWith(title: sanitized));
    }
  }
}
