import 'package:flutter_test/flutter_test.dart';
import 'package:anuscan/core/services/ocr_service.dart';
import 'package:anuscan/features/document_editor/domain/entities/scanned_page.dart';
import 'package:anuscan/features/document_history/data/datasources/local_document_datasource.dart';
import 'package:anuscan/features/document_history/data/models/document_dto.dart';
import 'package:anuscan/features/ocr/data/datasources/local_ocr_datasource.dart';
import 'package:anuscan/features/ocr/data/models/ocr_dto.dart';
import 'package:anuscan/features/ocr/data/repositories/ocr_repository_impl.dart';
import 'package:anuscan/features/ocr/domain/repositories/ocr_repository.dart';

class MockBatchOcrService implements OcrService {
  int extractCount = 0;
  Duration delay = const Duration(milliseconds: 1);

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<OcrResult> extractText(String imagePath) async {
    extractCount++;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return OcrResult(
      fullText: 'Page $extractCount extracted text with keyword searchable',
      blocks: [OcrTextBlock(text: 'Page $extractCount', confidence: 0.98)],
      processingDurationMs: 10,
    );
  }

  @override
  Future<String?> generateTitleFromContent(String imagePath) async => null;

  @override
  Future<void> dispose() async {}
}

class InMemoryOcrDataSource implements LocalOcrDataSource {
  final Map<String, OcrPageResultDto> storage = {};

  @override
  Future<void> savePageOcrResult(OcrPageResultDto result) async {
    storage[result.pageId] = result;
  }

  @override
  Future<void> saveBatchPageOcrResults(List<OcrPageResultDto> results) async {
    for (final r in results) {
      storage[r.pageId] = r;
    }
  }

  @override
  Future<OcrPageResultDto?> getPageOcrResult(String pageId) async =>
      storage[pageId];

  @override
  Future<List<OcrPageResultDto>> getDocumentOcrResults(
    String documentId,
  ) async =>
      storage.values.where((dto) => dto.documentId == documentId).toList();

  @override
  Future<void> deletePageOcrResult(String pageId) async {
    storage.remove(pageId);
  }

  @override
  Future<void> deleteDocumentOcrResults(String documentId) async {
    storage.removeWhere((_, dto) => dto.documentId == documentId);
  }

  @override
  Future<List<OcrPageResultDto>> searchDocumentText({
    required String documentId,
    required String query,
  }) async {
    return storage.values
        .where(
          (d) =>
              d.documentId == documentId &&
              d.extractedText.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }

  @override
  Future<List<OcrPageResultDto>> searchAllDocuments(String query) async {
    return storage.values
        .where(
          (d) => d.extractedText.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }
}

class InMemoryDocumentDataSource implements LocalDocumentDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  @override
  Future<List<DocumentDto>> getAllDocuments() async => [];

  @override
  Future<DocumentDto?> getDocumentById(String id) async => null;

  @override
  Future<List<DocumentPageDto>> getPagesForDocument(String documentId) async =>
      [];

  @override
  Future<void> insertOrUpdateDocument(
    DocumentDto document,
    List<DocumentPageDto> pages,
  ) async {}

  @override
  Future<void> deleteDocument(String id) async {}

  @override
  Future<void> updateDocumentTitle(
    String id,
    String newTitle,
    String newPdfPath,
  ) async {}

  @override
  Future<List<DocumentDto>> searchDocuments(String query) async => [];
}

void main() {
  late MockBatchOcrService ocrService;
  late InMemoryOcrDataSource ocrDataSource;
  late InMemoryDocumentDataSource docDataSource;
  late OcrRepositoryImpl repository;

  setUp(() {
    ocrService = MockBatchOcrService();
    ocrDataSource = InMemoryOcrDataSource();
    docDataSource = InMemoryDocumentDataSource();
    repository = OcrRepositoryImpl(
      ocrService: ocrService,
      localOcrDataSource: ocrDataSource,
      localDocumentDataSource: docDataSource,
    );
  });

  group('OCR Stress & Large-Batch Tests', () {
    test(
      'successfully processes a 10-page document with monotonic progress updates',
      () async {
        final pages = List.generate(
          10,
          (i) => ScannedPage(
            id: 'page_$i',
            documentId: 'doc_10',
            pageIndex: i,
            originalImagePath: '/tmp/orig_$i.jpg',
            processedImagePath: '/tmp/proc_$i.jpg',
            createdAt: DateTime.now(),
          ),
        );

        final progressList = <double>[];
        final updates = <OcrProgressUpdate>[];

        final stream = repository.extractDocumentText(
          documentId: 'doc_10',
          pages: pages,
        );

        await for (final update in stream) {
          updates.add(update);
          progressList.add(update.progress);
        }

        // Assert monotonic progress progression
        for (int i = 1; i < progressList.length; i++) {
          expect(progressList[i], greaterThanOrEqualTo(progressList[i - 1]));
        }

        final last = updates.last;
        expect(last.isCompleted, isTrue);
        expect(last.progress, equals(1.0));
        expect(last.accumulatedResults.length, equals(10));
        expect(ocrService.extractCount, equals(10));

        // Check results were all cached
        final docResults = await repository.getDocumentOcr('doc_10');
        expect(docResults.isSuccess, isTrue);
        final docOcr = docResults.fold(
          onFailure: (f) => null,
          onSuccess: (d) => d,
        );
        expect(docOcr!.pageResults.length, equals(10));
        expect(docOcr.combinedText, contains('Page 10'));
      },
    );

    test('processes a 20-page document under load without failure', () async {
      final pages = List.generate(
        20,
        (i) => ScannedPage(
          id: 'stress_page_$i',
          documentId: 'doc_20',
          pageIndex: i,
          originalImagePath: '/tmp/orig_$i.jpg',
          processedImagePath: '/tmp/proc_$i.jpg',
          createdAt: DateTime.now(),
        ),
      );

      final stream = repository.extractDocumentText(
        documentId: 'doc_20',
        pages: pages,
      );

      OcrProgressUpdate? finalUpdate;
      await for (final update in stream) {
        finalUpdate = update;
      }

      expect(finalUpdate, isNotNull);
      expect(finalUpdate!.isCompleted, isTrue);
      expect(finalUpdate.accumulatedResults.length, equals(20));
      expect(ocrService.extractCount, equals(20));
    });

    test(
      'cancels multi-page processing cleanly when requested mid-stream',
      () async {
        final pages = List.generate(
          15,
          (i) => ScannedPage(
            id: 'cancel_page_$i',
            documentId: 'doc_cancel',
            pageIndex: i,
            originalImagePath: '/tmp/orig_$i.jpg',
            processedImagePath: '/tmp/proc_$i.jpg',
            createdAt: DateTime.now(),
          ),
        );

        final stream = repository.extractDocumentText(
          documentId: 'doc_cancel',
          pages: pages,
        );

        int receivedEvents = 0;
        bool wasCancelled = false;

        await for (final update in stream) {
          receivedEvents++;
          if (update.currentPageIndex == 4) {
            repository.cancelCurrentOperation();
          }
          if (update.isCancelled) {
            wasCancelled = true;
            break;
          }
        }

        expect(wasCancelled, isTrue);
        expect(receivedEvents, greaterThan(0));
        expect(ocrService.extractCount, lessThan(15));
      },
    );
  });
}
