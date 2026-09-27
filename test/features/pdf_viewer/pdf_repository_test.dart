import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:anuscan/core/services/file_storage_service.dart';
import 'package:anuscan/core/services/pdf_generator_service.dart';
import 'package:anuscan/features/document_editor/domain/entities/document_session.dart';
import 'package:anuscan/features/document_editor/domain/entities/scanned_page.dart';
import 'package:anuscan/features/pdf_viewer/data/repositories/pdf_repository_impl.dart';

class MockPdfGeneratorService extends Mock implements PdfGeneratorService {}

class MockFileStorageService extends Mock implements FileStorageService {}

void main() {
  late MockPdfGeneratorService mockGenerator;
  late MockFileStorageService mockStorage;
  late PdfRepositoryImpl repository;
  late Directory tempDocDir;

  setUpAll(() {
    registerFallbackValue(PdfPageSizeOption.a4);
    registerFallbackValue(PdfQualityOption.standard);
  });

  setUp(() async {
    mockGenerator = MockPdfGeneratorService();
    mockStorage = MockFileStorageService();
    tempDocDir = await Directory.systemTemp.createTemp('anuscan_repo_test_');

    when(
      () => mockStorage.getOrCreateDocumentDirectory(any()),
    ).thenAnswer((_) async => tempDocDir);

    repository = PdfRepositoryImpl(
      pdfGeneratorService: mockGenerator,
      fileStorageService: mockStorage,
    );
  });

  tearDown(() async {
    if (await tempDocDir.exists()) {
      await tempDocDir.delete(recursive: true);
    }
  });

  group('generatePdfFromSession', () {
    test(
      'orders pages by order index, creates PDF in app storage, and returns success',
      () async {
        // Session with out-of-order pages (mixed camera & gallery)
        final session = DocumentSession(
          id: 'session_123',
          name: 'Report: March 2026',
          createdAt: DateTime(2026, 3, 22),
          updatedAt: DateTime(2026, 3, 22),
          pages: [
            DocumentSessionPage(
              id: 'p2',
              imagePath: '/storage/gallery_page2.jpg',
              order: 1,
              createdAt: DateTime.now(),
            ),
            DocumentSessionPage(
              id: 'p1',
              imagePath: '/storage/camera_page1.jpg',
              order: 0,
              createdAt: DateTime.now(),
            ),
          ],
        );

        when(
          () => mockGenerator.generatePdf(
            imagePaths: any(named: 'imagePaths'),
            outputPath: any(named: 'outputPath'),
            pageSize: any(named: 'pageSize'),
            quality: any(named: 'quality'),
            title: any(named: 'title'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer(
          (invocation) async =>
              invocation.namedArguments[#outputPath] as String,
        );

        final result = await repository.generatePdfFromSession(
          session: session,
          pageSize: PdfPageSizeOption.letter,
          quality: PdfQualityOption.high,
        );

        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull, contains('Report_ March 2026.pdf'));

        // Verify that pages were sorted by order: camera_page1 first, gallery_page2 second
        verify(
          () => mockGenerator.generatePdf(
            imagePaths: [
              '/storage/camera_page1.jpg',
              '/storage/gallery_page2.jpg',
            ],
            outputPath: any(named: 'outputPath'),
            pageSize: PdfPageSizeOption.letter,
            quality: PdfQualityOption.high,
            title: 'Report: March 2026',
            onProgress: any(named: 'onProgress'),
          ),
        ).called(1);
      },
    );

    test('returns failure on empty session pages', () async {
      final emptySession = DocumentSession(
        id: 'empty_sess',
        name: 'Empty',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        pages: const [],
      );

      final result = await repository.generatePdfFromSession(
        session: emptySession,
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.message, contains('empty document session'));
    });

    test('returns failure when generator throws exception', () async {
      final session = DocumentSession(
        id: 's1',
        name: 'Failed Doc',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        pages: [
          DocumentSessionPage(
            id: 'p1',
            imagePath: '/img.jpg',
            order: 0,
            createdAt: DateTime.now(),
          ),
        ],
      );

      when(
        () => mockGenerator.generatePdf(
          imagePaths: any(named: 'imagePaths'),
          outputPath: any(named: 'outputPath'),
          pageSize: any(named: 'pageSize'),
          quality: any(named: 'quality'),
          title: any(named: 'title'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenThrow(Exception('Disk read failed'));

      final result = await repository.generatePdfFromSession(session: session);

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.message, contains('Disk read failed'));
    });
  });

  group('generatePdfFromPages', () {
    test('compiles ScanPages and returns success', () async {
      final pages = [
        ScanPage(
          id: 'p1',
          documentId: 'doc_1',
          pageIndex: 0,
          originalImagePath: '/orig1.jpg',
          processedImagePath: '/proc1.jpg',
          createdAt: DateTime.now(),
        ),
      ];

      when(
        () => mockGenerator.generatePdf(
          imagePaths: any(named: 'imagePaths'),
          outputPath: any(named: 'outputPath'),
          pageSize: any(named: 'pageSize'),
          quality: any(named: 'quality'),
          title: any(named: 'title'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer(
        (invocation) async => invocation.namedArguments[#outputPath] as String,
      );

      final result = await repository.generatePdfFromPages(
        documentId: 'doc_1',
        title: 'Invoice',
        pages: pages,
      );

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, contains('Invoice.pdf'));
    });

    test('returns failure when pages list is empty', () async {
      final result = await repository.generatePdfFromPages(
        documentId: 'doc_1',
        title: 'Empty',
        pages: const [],
      );

      expect(result.isFailure, isTrue);
    });
  });
}
