import 'package:flutter_test/flutter_test.dart';
import 'package:anuscan/core/errors/failures.dart';
import 'package:anuscan/core/utils/result.dart';
import 'package:anuscan/features/document_editor/domain/entities/scanned_page.dart';
import 'package:anuscan/features/ocr/domain/entities/ocr_entities.dart';
import 'package:anuscan/features/ocr/domain/repositories/ocr_repository.dart';
import 'package:anuscan/features/ocr/domain/usecases/ocr_usecases.dart';
import 'package:anuscan/features/ocr/presentation/cubit/ocr_cubit.dart';
import 'package:anuscan/features/ocr/presentation/cubit/ocr_state.dart';

class FakeOcrRepository implements OcrRepository {
  DocumentOcrResult? cachedResult;
  DocumentOcrResult? finalResultToCache;
  List<OcrProgressUpdate> updatesToEmit = [];
  List<OcrSearchMatch> searchMatches = [];
  bool shouldFail = false;
  bool isCancelled = false;

  @override
  void cancelCurrentOperation() {
    isCancelled = true;
  }

  @override
  Future<Result<DocumentOcrResult>> getDocumentOcr(String documentId) async {
    if (shouldFail) {
      return Result.failure(const StorageFailure('Failed to read'));
    }
    if (cachedResult != null) return Result.success(cachedResult!);
    return Result.success(
      DocumentOcrResult(
        documentId: documentId,
        pageResults: const [],
        combinedText: '',
        status: OcrStatus.notProcessed,
        lastProcessedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<Result<OcrPageResult?>> getPageOcr(String pageId) async {
    return Result.success(null);
  }

  @override
  Stream<OcrProgressUpdate> extractDocumentText({
    required String documentId,
    required List<ScannedPage> pages,
    bool force = false,
  }) async* {
    for (final update in updatesToEmit) {
      if (isCancelled) {
        yield OcrProgressUpdate(
          currentPageIndex: update.currentPageIndex,
          totalPages: update.totalPages,
          progress: update.progress,
          isCancelled: true,
          accumulatedResults: update.accumulatedResults,
        );
        return;
      }
      if (update.isCompleted && finalResultToCache != null) {
        cachedResult = finalResultToCache;
      }
      yield update;
    }
  }

  @override
  Future<Result<OcrPageResult>> extractPageText({
    required String documentId,
    required ScannedPage page,
    bool force = false,
  }) async {
    final now = DateTime.now();
    return Result.success(
      OcrPageResult(
        id: 'ocr_${page.id}',
        documentId: documentId,
        pageId: page.id,
        pageIndex: page.pageIndex,
        imagePath: page.processedImagePath,
        extractedText: 'Page text',
        status: OcrStatus.completed,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  @override
  Future<Result<List<OcrSearchMatch>>> searchInDocument({
    required String documentId,
    required String query,
  }) async {
    return Result.success(searchMatches);
  }

  @override
  Future<Result<List<OcrSearchMatch>>> searchAcrossDocuments(
    String query,
  ) async {
    return Result.success(const []);
  }

  @override
  Future<Result<void>> invalidatePageOcr(String pageId) async {
    return Result.success(null);
  }

  @override
  Future<Result<void>> deleteDocumentOcr(String documentId) async {
    return Result.success(null);
  }
}

void main() {
  late FakeOcrRepository repository;
  late ExtractDocumentTextUseCase extractDocumentTextUseCase;
  late GetDocumentOcrUseCase getDocumentOcrUseCase;
  late SearchDocumentTextUseCase searchDocumentTextUseCase;
  late OcrCubit cubit;

  final samplePage = ScannedPage(
    id: 'page_1',
    documentId: 'doc_1',
    pageIndex: 0,
    originalImagePath: '/tmp/orig.jpg',
    processedImagePath: '/tmp/proc.jpg',
    rotationDegrees: 0,
    width: 100,
    height: 100,
    createdAt: DateTime.now(),
  );

  setUp(() {
    repository = FakeOcrRepository();
    extractDocumentTextUseCase = ExtractDocumentTextUseCase(repository);
    getDocumentOcrUseCase = GetDocumentOcrUseCase(repository);
    searchDocumentTextUseCase = SearchDocumentTextUseCase(repository);

    cubit = OcrCubit(
      extractDocumentTextUseCase: extractDocumentTextUseCase,
      getDocumentOcrUseCase: getDocumentOcrUseCase,
      searchDocumentTextUseCase: searchDocumentTextUseCase,
    );
  });

  tearDown(() {
    cubit.close();
  });

  group('OcrCubit Tests', () {
    test('initial state is OcrInitial', () {
      expect(cubit.state, const OcrInitial());
    });

    test('loadOrExtract with empty pages emits OcrFailure', () async {
      await cubit.loadOrExtract(documentId: 'doc_1', pages: const []);
      expect(cubit.state, isA<OcrFailure>());
    });

    test('loadOrExtract loads cached complete OCR result', () async {
      final now = DateTime.now();
      repository.cachedResult = DocumentOcrResult(
        documentId: 'doc_1',
        pageResults: [
          OcrPageResult(
            id: 'ocr_p1',
            documentId: 'doc_1',
            pageId: 'page_1',
            pageIndex: 0,
            imagePath: '/tmp/proc.jpg',
            extractedText: 'Pre-existing cached invoice',
            status: OcrStatus.completed,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        combinedText: 'Pre-existing cached invoice',
        status: OcrStatus.completed,
        lastProcessedAt: now,
      );

      await cubit.loadOrExtract(documentId: 'doc_1', pages: [samplePage]);

      expect(cubit.state, isA<OcrSuccess>());
      final success = cubit.state as OcrSuccess;
      expect(success.isFromCache, isTrue);
      expect(
        success.result.combinedText,
        contains('Pre-existing cached invoice'),
      );
    });

    test('loadOrExtract runs extraction stream when cache is absent', () async {
      final now = DateTime.now();
      final pageResult = OcrPageResult(
        id: 'ocr_p1',
        documentId: 'doc_1',
        pageId: 'page_1',
        pageIndex: 0,
        imagePath: '/tmp/proc.jpg',
        extractedText: 'Newly extracted text',
        status: OcrStatus.completed,
        createdAt: now,
        updatedAt: now,
      );

      final finalResult = DocumentOcrResult(
        documentId: 'doc_1',
        pageResults: [pageResult],
        combinedText: 'Newly extracted text',
        status: OcrStatus.completed,
        lastProcessedAt: now,
      );

      repository.updatesToEmit = [
        OcrProgressUpdate(
          currentPageIndex: 1,
          totalPages: 1,
          progress: 0.5,
          accumulatedResults: [pageResult],
        ),
        OcrProgressUpdate(
          currentPageIndex: 1,
          totalPages: 1,
          progress: 1.0,
          isCompleted: true,
          accumulatedResults: [pageResult],
        ),
      ];

      // Cache is absent initially, will be populated on completion
      repository.cachedResult = null;
      repository.finalResultToCache = finalResult;

      final states = <OcrState>[];
      final subscription = cubit.stream.listen(states.add);

      await cubit.loadOrExtract(documentId: 'doc_1', pages: [samplePage]);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(states.any((s) => s is OcrLoading), isTrue);
      expect(states.any((s) => s is OcrProgress), isTrue);
      expect(states.last, isA<OcrSuccess>());
      final success = states.last as OcrSuccess;
      expect(success.isFromCache, isFalse);
      expect(success.result.combinedText, contains('Newly extracted text'));

      await subscription.cancel();
    });

    test('searchWithin filters text and updates activeSearchQuery', () async {
      final now = DateTime.now();
      repository.cachedResult = DocumentOcrResult(
        documentId: 'doc_1',
        pageResults: [
          OcrPageResult(
            id: 'ocr_p1',
            documentId: 'doc_1',
            pageId: 'page_1',
            pageIndex: 0,
            imagePath: '/tmp/proc.jpg',
            extractedText: 'Tax invoice total: \$120.00',
            status: OcrStatus.completed,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        combinedText: 'Tax invoice total: \$120.00',
        status: OcrStatus.completed,
        lastProcessedAt: now,
      );

      repository.searchMatches = [
        const OcrSearchMatch(
          documentId: 'doc_1',
          documentTitle: 'Invoice',
          pageId: 'page_1',
          pageIndex: 0,
          matchCount: 1,
          snippet: 'total: \$120.00',
        ),
      ];

      await cubit.loadOrExtract(documentId: 'doc_1', pages: [samplePage]);
      expect(cubit.state, isA<OcrSuccess>());

      await cubit.searchWithin('total');

      final success = cubit.state as OcrSuccess;
      expect(success.activeSearchQuery, 'total');
      expect(success.searchMatches.length, 1);
      expect(success.searchMatches.first.matchCount, 1);

      // Clear search
      cubit.clearSearch();
      final cleared = cubit.state as OcrSuccess;
      expect(cleared.activeSearchQuery, isNull);
      expect(cleared.searchMatches, isEmpty);
    });
  });
}
