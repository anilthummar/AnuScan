import 'package:flutter_test/flutter_test.dart';
import 'package:anuscan/core/services/image_processing_service.dart';
import 'package:anuscan/core/services/ocr_service.dart';
import 'package:anuscan/features/document_editor/domain/entities/scanned_page.dart';
import 'package:anuscan/features/document_history/data/datasources/local_document_datasource.dart';
import 'package:anuscan/features/document_history/data/models/document_dto.dart';
import 'package:anuscan/features/ocr/data/datasources/local_ocr_datasource.dart';
import 'package:anuscan/features/ocr/data/models/ocr_dto.dart';
import 'package:anuscan/features/ocr/data/repositories/ocr_repository_impl.dart';
import 'package:anuscan/features/ocr/domain/entities/ocr_entities.dart';
import 'package:anuscan/features/ocr/domain/repositories/ocr_repository.dart';

class FakeOcrService implements OcrService {
  String textToReturn = 'Sample invoice text';
  Duration delay = Duration.zero;
  bool shouldThrow = false;
  int processCount = 0;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<OcrResult> extractText(String imagePath) async {
    processCount++;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (shouldThrow) {
      throw Exception('OCR extraction failed');
    }
    return OcrResult(
      fullText: textToReturn,
      blocks: [
        OcrTextBlock(
          text: textToReturn,
          confidence: 0.95,
          boundingBox: const [0, 0, 100, 50],
        ),
      ],
      processingDurationMs: 50,
      language: 'en',
    );
  }

  @override
  Future<String?> generateTitleFromContent(String imagePath) async => null;

  @override
  Future<void> dispose() async {}
}

class FakeLocalOcrDataSource implements LocalOcrDataSource {
  final Map<String, OcrPageResultDto> _cache = {};

  @override
  Future<void> savePageOcrResult(OcrPageResultDto result) async {
    _cache[result.pageId] = result;
  }

  @override
  Future<void> saveBatchPageOcrResults(List<OcrPageResultDto> results) async {
    for (final dto in results) {
      _cache[dto.pageId] = dto;
    }
  }

  @override
  Future<OcrPageResultDto?> getPageOcrResult(String pageId) async {
    return _cache[pageId];
  }

  @override
  Future<List<OcrPageResultDto>> getDocumentOcrResults(
    String documentId,
  ) async {
    return _cache.values.where((dto) => dto.documentId == documentId).toList();
  }

  @override
  Future<void> deletePageOcrResult(String pageId) async {
    _cache.remove(pageId);
  }

  @override
  Future<void> deleteDocumentOcrResults(String documentId) async {
    _cache.removeWhere((_, dto) => dto.documentId == documentId);
  }

  @override
  Future<List<OcrPageResultDto>> searchDocumentText({
    required String documentId,
    required String query,
  }) async {
    return _cache.values
        .where(
          (dto) =>
              dto.documentId == documentId &&
              dto.extractedText.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }

  @override
  Future<List<OcrPageResultDto>> searchAllDocuments(String query) async {
    return _cache.values
        .where(
          (dto) =>
              dto.extractedText.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }
}

class FakeLocalDocumentDataSource implements LocalDocumentDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  final List<DocumentDto> documents = [];

  @override
  Future<List<DocumentDto>> getAllDocuments() async => documents;

  @override
  Future<DocumentDto?> getDocumentById(String id) async {
    try {
      return documents.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<DocumentPageDto>> getPagesForDocument(String documentId) async =>
      [];

  @override
  Future<void> insertOrUpdateDocument(
    DocumentDto document,
    List<DocumentPageDto> pages,
  ) async {
    documents.removeWhere((d) => d.id == document.id);
    documents.add(document);
  }

  @override
  Future<void> deleteDocument(String id) async {
    documents.removeWhere((d) => d.id == id);
  }

  @override
  Future<void> updateDocumentTitle(
    String id,
    String newTitle,
    String newPdfPath,
  ) async {}

  @override
  Future<List<DocumentDto>> searchDocuments(String query) async => documents;
}

void main() {
  late FakeOcrService ocrService;
  late FakeLocalOcrDataSource localOcrDataSource;
  late FakeLocalDocumentDataSource localDocumentDataSource;
  late OcrRepositoryImpl repository;

  final testPage = ScannedPage(
    id: 'page_1',
    documentId: 'doc_1',
    pageIndex: 0,
    originalImagePath: '/tmp/orig_1.jpg',
    processedImagePath: '/tmp/proc_1.jpg',
    filterType: DocumentFilterType.original,
    rotationDegrees: 0,
    width: 1000,
    height: 1400,
    createdAt: DateTime.now(),
  );

  setUp(() {
    ocrService = FakeOcrService();
    localOcrDataSource = FakeLocalOcrDataSource();
    localDocumentDataSource = FakeLocalDocumentDataSource();
    repository = OcrRepositoryImpl(
      ocrService: ocrService,
      localOcrDataSource: localOcrDataSource,
      localDocumentDataSource: localDocumentDataSource,
    );
  });

  group('OcrRepositoryImpl Tests', () {
    test('extractPageText processes image and saves result in DB', () async {
      final result = await repository.extractPageText(
        documentId: 'doc_1',
        page: testPage,
      );

      expect(result.isSuccess, isTrue);
      final pageResult = result.fold(
        onFailure: (f) => throw Exception(f.message),
        onSuccess: (d) => d,
      );

      expect(pageResult.extractedText, 'Sample invoice text');
      expect(pageResult.status, OcrStatus.completed);
      expect(ocrService.processCount, 1);

      // Verify cached in DB
      final cached = await localOcrDataSource.getPageOcrResult('page_1');
      expect(cached, isNotNull);
      expect(cached!.extractedText, 'Sample invoice text');
    });

    test(
      'extractPageText uses cache when imagePath matches and force is false',
      () async {
        // Pre-populate DB
        await localOcrDataSource.savePageOcrResult(
          OcrPageResultDto(
            id: 'ocr_res_1',
            pageId: 'page_1',
            documentId: 'doc_1',
            pageIndex: 0,
            imagePath: '/tmp/proc_1.jpg',
            extractedText: 'Cached invoice text',
            status: 'completed',
            processingDurationMs: 40,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );

        final result = await repository.extractPageText(
          documentId: 'doc_1',
          page: testPage,
          force: false,
        );

        expect(result.isSuccess, isTrue);
        final pageResult = result.fold(
          onFailure: (f) => throw Exception(f.message),
          onSuccess: (d) => d,
        );

        expect(pageResult.extractedText, 'Cached invoice text');
        // OCR service should NOT have been called
        expect(ocrService.processCount, 0);
      },
    );

    test('extractPageText re-runs OCR when force is true', () async {
      // Pre-populate DB
      await localOcrDataSource.savePageOcrResult(
        OcrPageResultDto(
          id: 'ocr_res_1',
          pageId: 'page_1',
          documentId: 'doc_1',
          pageIndex: 0,
          imagePath: '/tmp/proc_1.jpg',
          extractedText: 'Old text',
          status: 'completed',
          processingDurationMs: 40,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      final result = await repository.extractPageText(
        documentId: 'doc_1',
        page: testPage,
        force: true,
      );

      expect(result.isSuccess, isTrue);
      expect(ocrService.processCount, 1);
    });

    test(
      'extractDocumentText processes multiple pages sequentially with progress updates',
      () async {
        final page2 = testPage.copyWith(
          id: 'page_2',
          pageIndex: 1,
          processedImagePath: '/tmp/proc_2.jpg',
        );

        final updates = <OcrProgressUpdate>[];
        final stream = repository.extractDocumentText(
          documentId: 'doc_1',
          pages: [testPage, page2],
        );

        await for (final update in stream) {
          updates.add(update);
        }

        expect(updates.isNotEmpty, isTrue);
        final lastUpdate = updates.last;
        expect(lastUpdate.progress, 1.0);
        expect(lastUpdate.accumulatedResults.length, 2);
        expect(lastUpdate.isCompleted, isTrue);
        expect(ocrService.processCount, 2);
      },
    );

    test('searchInDocument finds query within page text', () async {
      await localOcrDataSource.savePageOcrResult(
        OcrPageResultDto(
          id: 'ocr_res_1',
          pageId: 'page_1',
          documentId: 'doc_1',
          pageIndex: 0,
          imagePath: '/tmp/proc_1.jpg',
          extractedText:
              'Payment receipt for Services rendered.\nTotal due: \$50.00',
          status: 'completed',
          processingDurationMs: 50,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      final searchResult = await repository.searchInDocument(
        documentId: 'doc_1',
        query: 'total due',
      );

      expect(searchResult.isSuccess, isTrue);
      final matches = searchResult.fold(
        onFailure: (_) => throw Exception(),
        onSuccess: (m) => m,
      );

      expect(matches.length, 1);
      expect(matches.first.matchCount, 1);
      expect(matches.first.snippet, contains('Total due'));
    });

    test('invalidatePageOcr removes entry from database', () async {
      await localOcrDataSource.savePageOcrResult(
        OcrPageResultDto(
          id: 'ocr_res_1',
          pageId: 'page_to_delete',
          documentId: 'doc_1',
          pageIndex: 0,
          imagePath: '/tmp/p.jpg',
          extractedText: 'To be removed',
          status: 'completed',
          processingDurationMs: 30,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      final invalidateResult = await repository.invalidatePageOcr(
        'page_to_delete',
      );
      expect(invalidateResult.isSuccess, isTrue);

      final cached = await localOcrDataSource.getPageOcrResult(
        'page_to_delete',
      );
      expect(cached, isNull);
    });
  });
}
