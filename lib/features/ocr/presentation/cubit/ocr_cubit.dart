import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../document_editor/domain/entities/scanned_page.dart';
import '../../domain/repositories/ocr_repository.dart';
import '../../domain/usecases/ocr_usecases.dart';
import 'ocr_state.dart';

class OcrCubit extends Cubit<OcrState> {
  OcrCubit({
    required this.extractDocumentTextUseCase,
    required this.getDocumentOcrUseCase,
    required this.searchDocumentTextUseCase,
  }) : super(const OcrInitial());

  final ExtractDocumentTextUseCase extractDocumentTextUseCase;
  final GetDocumentOcrUseCase getDocumentOcrUseCase;
  final SearchDocumentTextUseCase searchDocumentTextUseCase;

  StreamSubscription<OcrProgressUpdate>? _progressSubscription;

  /// Loads cached OCR text if complete and valid; otherwise runs sequential OCR across [pages].
  Future<void> loadOrExtract({
    required String documentId,
    required List<ScannedPage> pages,
    bool force = false,
  }) async {
    await _progressSubscription?.cancel();
    _progressSubscription = null;

    if (pages.isEmpty) {
      emit(const OcrFailure(message: 'Document contains no pages to process'));
      return;
    }

    emit(const OcrLoading(message: 'Checking existing text cache...'));

    // 1. Check existing cached OCR result
    if (!force) {
      final cacheResult = await getDocumentOcrUseCase(documentId);
      final cached = cacheResult.fold(
        onFailure: (_) => null,
        onSuccess: (data) => data,
      );

      if (cached != null &&
          cached.pageResults.length == pages.length &&
          cached.pageResults.isNotEmpty) {
        // Verify all image paths match current processed pages
        final pageMap = {for (final p in pages) p.id: p};
        final isAllValid = cached.pageResults.every((ocrPage) {
          final currentPage = pageMap[ocrPage.pageId];
          return currentPage != null &&
              currentPage.processedImagePath == ocrPage.imagePath;
        });

        if (isAllValid) {
          emit(OcrSuccess(result: cached, isFromCache: true));
          return;
        }
      }
    }

    // 2. Start sequential extraction
    emit(
      OcrProgress(
        currentPageIndex: 0,
        totalPages: pages.length,
        progress: 0.0,
        statusMessage: 'Starting text extraction...',
      ),
    );

    final stream = extractDocumentTextUseCase(
      documentId: documentId,
      pages: pages,
      force: force,
    );

    _progressSubscription = stream.listen(
      (update) async {
        if (isClosed) return;

        if (update.isCancelled) {
          emit(OcrCancelled(partialResults: update.accumulatedResults));
        } else if (update.isCompleted) {
          // Fetch complete aggregated result
          final finalResult = await getDocumentOcrUseCase(documentId);
          if (isClosed) return;

          finalResult.fold(
            onFailure: (failure) {
              emit(
                OcrFailure(
                  message: failure.message,
                  partialResults: update.accumulatedResults,
                ),
              );
            },
            onSuccess: (docOcr) {
              emit(OcrSuccess(result: docOcr, isFromCache: false));
            },
          );
        } else {
          final msg = update.currentPageIndex > 0
              ? 'Extracting text from page ${update.currentPageIndex} of ${update.totalPages}...'
              : 'Processing document pages...';

          emit(
            OcrProgress(
              currentPageIndex: update.currentPageIndex,
              totalPages: update.totalPages,
              progress: update.progress,
              statusMessage: msg,
              partialResults: update.accumulatedResults,
            ),
          );
        }
      },
      onError: (e) {
        if (!isClosed) {
          emit(OcrFailure(message: 'OCR extraction encountered an error: $e'));
        }
      },
    );
  }

  /// Cancels any active sequential OCR processing stream.
  void cancel() {
    extractDocumentTextUseCase.cancel();
    _progressSubscription?.cancel();
    _progressSubscription = null;

    final currentState = state;
    if (currentState is OcrProgress) {
      emit(OcrCancelled(partialResults: currentState.partialResults));
    } else {
      emit(const OcrCancelled());
    }
  }

  /// Searches for occurrences of [query] within the active OCR result.
  Future<void> searchWithin(String query) async {
    final currentState = state;
    if (currentState is! OcrSuccess) return;

    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      clearSearch();
      return;
    }

    final searchResult = await searchDocumentTextUseCase(
      documentId: currentState.result.documentId,
      query: trimmed,
    );

    if (isClosed) return;

    searchResult.fold(
      onFailure: (_) {},
      onSuccess: (matches) {
        emit(
          currentState.copyWith(
            searchMatches: matches,
            activeSearchQuery: trimmed,
          ),
        );
      },
    );
  }

  /// Clears the active search query and highlights.
  void clearSearch() {
    final currentState = state;
    if (currentState is OcrSuccess) {
      emit(currentState.copyWith(clearSearch: true));
    }
  }

  @override
  Future<void> close() async {
    await _progressSubscription?.cancel();
    _progressSubscription = null;
    return super.close();
  }
}
