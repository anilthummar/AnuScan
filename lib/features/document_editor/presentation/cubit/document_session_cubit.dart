import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/file_storage_service.dart';
import '../../../../core/services/image_processing_service.dart';
import '../../domain/entities/document_session.dart';
import '../../domain/entities/scanned_page.dart';
import '../../domain/usecases/edit_scan_page_usecase.dart';
import '../../domain/usecases/reorder_pages_usecase.dart';
import 'document_session_state.dart';

/// Cubit managing a multi-page document session lifecycle.
class DocumentSessionCubit extends Cubit<DocumentSessionState> {
  DocumentSessionCubit({
    required this.fileStorageService,
    required this.imageProcessingService,
    required this.editScanPageUseCase,
    required this.reorderPagesUseCase,
    required DocumentSession initialSession,
  }) : super(DocumentSessionState(session: initialSession));

  final FileStorageService fileStorageService;
  final ImageProcessingService imageProcessingService;
  final EditScanPageUseCase editScanPageUseCase;
  final ReorderPagesUseCase reorderPagesUseCase;

  /// Ingests camera-scanned image paths into the session.
  Future<void> addScannedPages(List<String> rawPaths) async {
    await _ingestImagePaths(rawPaths, processingLabel: 'Importing scan...');
  }

  /// Ingests gallery-imported image paths into the session.
  Future<void> addGalleryPages(List<String> rawPaths) async {
    await _ingestImagePaths(
      rawPaths,
      processingLabel: 'Importing gallery images...',
    );
  }

  Future<void> _ingestImagePaths(
    List<String> rawPaths, {
    required String processingLabel,
  }) async {
    if (rawPaths.isEmpty) return;

    emit(
      state.copyWith(isProcessing: true, processingMessage: processingLabel),
    );

    try {
      final newPages = <DocumentSessionPage>[];
      var startIndex = state.session.pages.length;

      for (final rawPath in rawPaths) {
        final pageId = const Uuid().v4();
        // Persist original image into dedicated document storage folder
        final storedOriginal = await fileStorageService.copyImageFile(
          state.session.id,
          rawPath,
          filename: 'orig_$pageId.jpg',
        );

        // Initially, processed image is identical to original
        final storedProcessed = await fileStorageService.copyImageFile(
          state.session.id,
          rawPath,
          filename: 'proc_$pageId.jpg',
        );

        final (w, h) = await imageProcessingService.getImageDimensions(
          storedProcessed,
        );

        newPages.add(
          DocumentSessionPage(
            id: pageId,
            imagePath: storedProcessed,
            originalImagePath: storedOriginal,
            order: startIndex++,
            rotation: 0,
            filter: ScanFilter.original,
            width: w,
            height: h,
            createdAt: DateTime.now(),
          ),
        );
      }

      final updatedPages = List<DocumentSessionPage>.from(state.session.pages)
        ..addAll(newPages);

      final updatedSession = state.session.copyWith(
        pages: updatedPages,
        updatedAt: DateTime.now(),
      );

      emit(
        state.copyWith(
          session: updatedSession,
          isProcessing: false,
          processingMessage: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isProcessing: false,
          errorMessage: 'Failed to import images: $e',
        ),
      );
    }
  }

  /// Appends pre-processed [DocumentSessionPage] items.
  void addPages(List<DocumentSessionPage> newPages) {
    if (newPages.isEmpty) return;
    var orderIndex = state.session.pages.length;
    final indexedPages = [
      for (final p in newPages) p.copyWith(order: orderIndex++),
    ];
    final updatedPages = List<DocumentSessionPage>.from(state.session.pages)
      ..addAll(indexedPages);

    emit(
      state.copyWith(
        session: state.session.copyWith(
          pages: updatedPages,
          updatedAt: DateTime.now(),
        ),
      ),
    );
  }

  /// Appends pre-processed [ScanPage] items.
  void addScanPages(List<ScanPage> scanPages) {
    addPages(scanPages.map(DocumentSessionPage.fromScanPage).toList());
  }

  /// Reorders pages when dragged and dropped in the UI.
  void reorderPages(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.session.pages.length) return;
    if (newIndex < 0) return;

    final pagesList = List<DocumentSessionPage>.from(state.session.pages);
    var targetIndex = newIndex;
    if (oldIndex < targetIndex) {
      targetIndex -= 1;
    }
    if (targetIndex >= pagesList.length) {
      targetIndex = pagesList.length - 1;
    }

    final item = pagesList.removeAt(oldIndex);
    pagesList.insert(targetIndex, item);

    // Re-index order
    final reindexed = [
      for (int i = 0; i < pagesList.length; i++)
        pagesList[i].copyWith(order: i),
    ];

    emit(
      state.copyWith(
        session: state.session.copyWith(
          pages: reindexed,
          updatedAt: DateTime.now(),
        ),
      ),
    );
  }

  /// Deletes a page at [index] and re-indexes subsequent pages.
  void deletePage(int index) {
    if (index < 0 || index >= state.session.pages.length) return;

    final updated = List<DocumentSessionPage>.from(state.session.pages)
      ..removeAt(index);

    // Re-index remaining pages
    final reindexed = [
      for (int i = 0; i < updated.length; i++) updated[i].copyWith(order: i),
    ];

    var newSelectedIndex = state.selectedPageIndex;
    if (newSelectedIndex >= reindexed.length) {
      newSelectedIndex = reindexed.isEmpty ? 0 : reindexed.length - 1;
    }

    emit(
      state.copyWith(
        session: state.session.copyWith(
          pages: reindexed,
          updatedAt: DateTime.now(),
        ),
        selectedPageIndex: newSelectedIndex,
      ),
    );
  }

  /// Duplicates a page at [index], creating independent file copies.
  Future<void> duplicatePage(int index) async {
    if (index < 0 || index >= state.session.pages.length) return;

    emit(
      state.copyWith(
        isProcessing: true,
        processingMessage: 'Duplicating page...',
      ),
    );

    try {
      final source = state.session.pages[index];
      final newPageId = const Uuid().v4();

      final dupOriginal = await fileStorageService.copyImageFile(
        state.session.id,
        source.originalImagePath ?? source.imagePath,
        filename: 'orig_$newPageId.jpg',
      );

      final dupProcessed = await fileStorageService.copyImageFile(
        state.session.id,
        source.imagePath,
        filename: 'proc_$newPageId.jpg',
      );

      final duplicatePage = source.copyWith(
        id: newPageId,
        imagePath: dupProcessed,
        originalImagePath: dupOriginal,
        createdAt: DateTime.now(),
      );

      final pagesList = List<DocumentSessionPage>.from(state.session.pages);
      // Insert immediately following the source page
      pagesList.insert(index + 1, duplicatePage);

      // Re-index order sequence
      final reindexed = [
        for (int i = 0; i < pagesList.length; i++)
          pagesList[i].copyWith(order: i),
      ];

      emit(
        state.copyWith(
          session: state.session.copyWith(
            pages: reindexed,
            updatedAt: DateTime.now(),
          ),
          isProcessing: false,
          processingMessage: null,
          selectedPageIndex: index + 1,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isProcessing: false,
          errorMessage: 'Failed to duplicate page: $e',
        ),
      );
    }
  }

  /// Updates an existing page after editing in [PageEditorScreen].
  void editPage(DocumentSessionPage updatedPage) {
    final index = state.session.pages.indexWhere((p) => p.id == updatedPage.id);
    if (index != -1) {
      final updatedList = List<DocumentSessionPage>.from(state.session.pages);
      updatedList[index] = updatedPage.copyWith(order: index);

      emit(
        state.copyWith(
          session: state.session.copyWith(
            pages: updatedList,
            updatedAt: DateTime.now(),
          ),
        ),
      );
    }
  }

  /// Interoperability method accepting [ScanPage].
  void updatePage(ScanPage updatedScanPage) {
    editPage(DocumentSessionPage.fromScanPage(updatedScanPage));
  }

  /// Rotates a page at [index] by 90 degrees clockwise.
  Future<void> rotatePage(int index) async {
    if (index < 0 || index >= state.session.pages.length) return;

    final targetPage = state.session.pages[index];
    final nextRotation = (targetPage.rotation + 90) % 360;

    emit(
      state.copyWith(isProcessing: true, processingMessage: 'Rotating page...'),
    );

    try {
      final scanPage = targetPage.toScanPage(documentId: state.session.id);
      final processed = await editScanPageUseCase(
        page: scanPage,
        rotationDegrees: nextRotation,
      );

      final updatedPages = List<DocumentSessionPage>.from(state.session.pages);
      updatedPages[index] = DocumentSessionPage.fromScanPage(
        processed,
      ).copyWith(order: index);

      emit(
        state.copyWith(
          session: state.session.copyWith(
            pages: updatedPages,
            updatedAt: DateTime.now(),
          ),
          isProcessing: false,
          processingMessage: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isProcessing: false,
          errorMessage: 'Failed to rotate page: $e',
        ),
      );
    }
  }

  /// Updates session name.
  void updateSessionName(String newName) {
    final sanitized = newName.trim();
    if (sanitized.isNotEmpty) {
      emit(
        state.copyWith(
          session: state.session.copyWith(
            name: sanitized,
            updatedAt: DateTime.now(),
          ),
        ),
      );
    }
  }

  void selectPage(int index) {
    if (index >= 0 && index < state.session.pages.length) {
      emit(state.copyWith(selectedPageIndex: index));
    }
  }
}
