import 'dart:async';
import 'dart:math' as math;
import 'package:uuid/uuid.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/ocr_service.dart';
import '../../../../core/utils/result.dart';
import '../../../document_editor/domain/entities/scanned_page.dart';
import '../../../document_history/data/datasources/local_document_datasource.dart';
import '../../domain/entities/ocr_entities.dart';
import '../../domain/repositories/ocr_repository.dart';
import '../datasources/local_ocr_datasource.dart';
import '../models/ocr_dto.dart';

class OcrRepositoryImpl implements OcrRepository {
  OcrRepositoryImpl({
    required this.ocrService,
    required this.localOcrDataSource,
    required this.localDocumentDataSource,
  });

  final OcrService ocrService;
  final LocalOcrDataSource localOcrDataSource;
  final LocalDocumentDataSource localDocumentDataSource;

  bool _isCancelled = false;

  @override
  void cancelCurrentOperation() {
    _isCancelled = true;
  }

  @override
  Future<Result<OcrPageResult>> extractPageText({
    required String documentId,
    required ScannedPage page,
    bool force = false,
  }) async {
    try {
      // 1. Check existing cache
      if (!force) {
        final cachedDto = await localOcrDataSource.getPageOcrResult(page.id);
        if (cachedDto != null &&
            cachedDto.imagePath == page.processedImagePath &&
            cachedDto.status == OcrStatus.completed.name) {
          return Result.success(_mapDtoToEntity(cachedDto));
        }
      }

      // 2. Perform fresh extraction
      final ocrResult = await ocrService.extractText(page.processedImagePath);

      final now = DateTime.now();
      final pageResult = OcrPageResult(
        id: const Uuid().v4(),
        documentId: documentId,
        pageId: page.id,
        pageIndex: page.pageIndex,
        extractedText: ocrResult.fullText,
        blocks: ocrResult.blocks
            .map(
              (b) => OcrTextBlockEntity(
                text: b.text,
                confidence: b.confidence,
                boundingBox: b.boundingBox,
              ),
            )
            .toList(),
        status: OcrStatus.completed,
        language: ocrResult.language ?? 'en',
        processingDurationMs: ocrResult.processingDurationMs,
        imagePath: page.processedImagePath,
        createdAt: now,
        updatedAt: now,
      );

      // 3. Persist locally
      await localOcrDataSource.savePageOcrResult(_mapEntityToDto(pageResult));

      return Result.success(pageResult);
    } catch (e) {
      return Result.failure(StorageFailure('OCR extraction failed: $e'));
    }
  }

  @override
  Stream<OcrProgressUpdate> extractDocumentText({
    required String documentId,
    required List<ScannedPage> pages,
    bool force = false,
  }) async* {
    _isCancelled = false;

    if (pages.isEmpty) {
      yield const OcrProgressUpdate(
        currentPageIndex: 0,
        totalPages: 0,
        progress: 1.0,
        accumulatedResults: [],
        isCompleted: true,
      );
      return;
    }

    final accumulated = <OcrPageResult>[];
    final total = pages.length;

    for (int i = 0; i < total; i++) {
      if (_isCancelled) {
        yield OcrProgressUpdate(
          currentPageIndex: i,
          totalPages: total,
          progress: i / total,
          accumulatedResults: List.unmodifiable(accumulated),
          isCancelled: true,
        );
        return;
      }

      final page = pages[i];

      // Yield start of page processing
      yield OcrProgressUpdate(
        currentPageIndex: i + 1,
        totalPages: total,
        progress: i / total,
        accumulatedResults: List.unmodifiable(accumulated),
      );

      try {
        final result = await extractPageText(
          documentId: documentId,
          page: page,
          force: force,
        );

        result.fold(
          onFailure: (failure) {
            final failedResult = OcrPageResult(
              id: const Uuid().v4(),
              documentId: documentId,
              pageId: page.id,
              pageIndex: page.pageIndex,
              extractedText: '',
              status: OcrStatus.failed,
              imagePath: page.processedImagePath,
              errorMessage: failure.message,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            accumulated.add(failedResult);
          },
          onSuccess: (pageResult) {
            accumulated.add(pageResult);
          },
        );
      } catch (e) {
        final failedResult = OcrPageResult(
          id: const Uuid().v4(),
          documentId: documentId,
          pageId: page.id,
          pageIndex: page.pageIndex,
          extractedText: '',
          status: OcrStatus.failed,
          imagePath: page.processedImagePath,
          errorMessage: e.toString(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        accumulated.add(failedResult);
      }

      yield OcrProgressUpdate(
        currentPageIndex: i + 1,
        totalPages: total,
        progress: (i + 1) / total,
        currentResult: accumulated.last,
        accumulatedResults: List.unmodifiable(accumulated),
        isCompleted: (i + 1) == total,
      );
    }
  }

  @override
  Future<Result<DocumentOcrResult>> getDocumentOcr(String documentId) async {
    try {
      final dtos = await localOcrDataSource.getDocumentOcrResults(documentId);
      final pageResults = dtos.map(_mapDtoToEntity).toList();

      final combinedTextBuffer = StringBuffer();
      for (int i = 0; i < pageResults.length; i++) {
        final p = pageResults[i];
        if (i > 0) {
          combinedTextBuffer.writeln('\n---\n');
        }
        combinedTextBuffer.writeln('Page ${p.pageIndex + 1}');
        if (p.hasText) {
          combinedTextBuffer.writeln(p.extractedText.trim());
        } else {
          combinedTextBuffer.writeln('[No text detected]');
        }
      }

      final overallStatus = pageResults.isEmpty
          ? OcrStatus.notProcessed
          : (pageResults.every((p) => p.status == OcrStatus.completed)
                ? OcrStatus.completed
                : (pageResults.any((p) => p.status == OcrStatus.completed)
                      ? OcrStatus.completed
                      : OcrStatus.failed));

      final docOcrResult = DocumentOcrResult(
        documentId: documentId,
        pageResults: pageResults,
        combinedText: combinedTextBuffer.toString(),
        status: overallStatus,
        lastProcessedAt: pageResults.isNotEmpty
            ? pageResults
                  .map((p) => p.updatedAt)
                  .reduce((a, b) => a.isAfter(b) ? a : b)
            : DateTime.now(),
      );

      return Result.success(docOcrResult);
    } catch (e) {
      return Result.failure(StorageFailure('Failed to load document OCR: $e'));
    }
  }

  @override
  Future<Result<OcrPageResult?>> getPageOcr(String pageId) async {
    try {
      final dto = await localOcrDataSource.getPageOcrResult(pageId);
      if (dto == null) return const Result.success(null);
      return Result.success(_mapDtoToEntity(dto));
    } catch (e) {
      return Result.failure(StorageFailure('Failed to load page OCR: $e'));
    }
  }

  @override
  Future<Result<List<OcrSearchMatch>>> searchInDocument({
    required String documentId,
    required String query,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const Result.success([]);

    try {
      final dtos = await localOcrDataSource.searchDocumentText(
        documentId: documentId,
        query: trimmed,
      );

      final matches = <OcrSearchMatch>[];
      for (final dto in dtos) {
        final snippet = _extractSnippet(dto.extractedText, trimmed);
        final matchCount = _countOccurrences(dto.extractedText, trimmed);

        matches.add(
          OcrSearchMatch(
            documentId: dto.documentId,
            documentTitle: '',
            pageId: dto.pageId,
            pageIndex: dto.pageIndex,
            snippet: snippet,
            matchCount: matchCount,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(dto.updatedAt),
          ),
        );
      }

      return Result.success(matches);
    } catch (e) {
      return Result.failure(
        StorageFailure('Failed to search document OCR: $e'),
      );
    }
  }

  @override
  Future<Result<List<OcrSearchMatch>>> searchAcrossDocuments(
    String query,
  ) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const Result.success([]);

    try {
      final dtos = await localOcrDataSource.searchAllDocuments(trimmed);
      final allDocs = await localDocumentDataSource.getAllDocuments();
      final docTitles = {for (final d in allDocs) d.id: d.title};

      final matches = <OcrSearchMatch>[];
      for (final dto in dtos) {
        final snippet = _extractSnippet(dto.extractedText, trimmed);
        final matchCount = _countOccurrences(dto.extractedText, trimmed);

        matches.add(
          OcrSearchMatch(
            documentId: dto.documentId,
            documentTitle: docTitles[dto.documentId] ?? 'Untitled Document',
            pageId: dto.pageId,
            pageIndex: dto.pageIndex,
            snippet: snippet,
            matchCount: matchCount,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(dto.updatedAt),
          ),
        );
      }

      return Result.success(matches);
    } catch (e) {
      return Result.failure(
        StorageFailure('Failed to search across documents: $e'),
      );
    }
  }

  @override
  Future<Result<void>> invalidatePageOcr(String pageId) async {
    try {
      await localOcrDataSource.deletePageOcrResult(pageId);
      return const Result.success(null);
    } catch (e) {
      return Result.failure(
        StorageFailure('Failed to invalidate page OCR: $e'),
      );
    }
  }

  @override
  Future<Result<void>> deleteDocumentOcr(String documentId) async {
    try {
      await localOcrDataSource.deleteDocumentOcrResults(documentId);
      return const Result.success(null);
    } catch (e) {
      return Result.failure(
        StorageFailure('Failed to delete document OCR: $e'),
      );
    }
  }

  // --- Helper Methods ---

  OcrPageResult _mapDtoToEntity(OcrPageResultDto dto) {
    return OcrPageResult(
      id: dto.id,
      documentId: dto.documentId,
      pageId: dto.pageId,
      pageIndex: dto.pageIndex,
      extractedText: dto.extractedText,
      status: OcrStatus.values.firstWhere(
        (s) => s.name == dto.status,
        orElse: () => OcrStatus.completed,
      ),
      language: dto.language,
      processingDurationMs: dto.processingDurationMs,
      imagePath: dto.imagePath,
      createdAt: DateTime.fromMillisecondsSinceEpoch(dto.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(dto.updatedAt),
    );
  }

  OcrPageResultDto _mapEntityToDto(OcrPageResult entity) {
    return OcrPageResultDto(
      id: entity.id,
      documentId: entity.documentId,
      pageId: entity.pageId,
      pageIndex: entity.pageIndex,
      extractedText: entity.extractedText,
      status: entity.status.name,
      language: entity.language,
      processingDurationMs: entity.processingDurationMs,
      imagePath: entity.imagePath,
      createdAt: entity.createdAt.millisecondsSinceEpoch,
      updatedAt: entity.updatedAt.millisecondsSinceEpoch,
    );
  }

  String _extractSnippet(String text, String query) {
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerText.indexOf(lowerQuery);
    if (index == -1) {
      return text.length > 80 ? '${text.substring(0, 80)}...' : text;
    }

    final start = math.max(0, index - 30);
    final end = math.min(text.length, index + query.length + 30);

    final prefix = start > 0 ? '...' : '';
    final suffix = end < text.length ? '...' : '';

    return '$prefix${text.substring(start, end).replaceAll('\n', ' ')}$suffix';
  }

  int _countOccurrences(String text, String query) {
    if (query.isEmpty) return 0;
    int count = 0;
    int index = 0;
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    while ((index = lowerText.indexOf(lowerQuery, index)) != -1) {
      count++;
      index += lowerQuery.length;
    }
    return count;
  }
}
