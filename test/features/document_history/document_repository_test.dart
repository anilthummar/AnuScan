import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:anuscan/core/database/app_database.dart';
import 'package:anuscan/core/services/file_storage_service.dart';
import 'package:anuscan/features/document_history/data/datasources/local_document_datasource.dart';
import 'package:anuscan/features/document_history/data/repositories/document_repository_impl.dart';
import 'package:anuscan/features/document_history/domain/entities/document_entity.dart';
import 'package:anuscan/features/document_editor/domain/entities/scanned_page.dart';

class MockFileStorageService extends Mock implements FileStorageService {}

void main() {
  sqfliteFfiInit();

  late Database db;
  late AppDatabase appDatabase;
  late LocalDocumentDataSource dataSource;
  late MockFileStorageService mockStorageService;
  late DocumentRepositoryImpl repository;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE documents (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        pdf_path TEXT NOT NULL,
        thumbnail_path TEXT,
        page_count INTEGER NOT NULL DEFAULT 0,
        file_size_bytes INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE document_pages (
        id TEXT PRIMARY KEY,
        document_id TEXT NOT NULL,
        page_index INTEGER NOT NULL,
        original_image_path TEXT NOT NULL,
        processed_image_path TEXT NOT NULL,
        filter_type TEXT NOT NULL DEFAULT 'original',
        rotation_degrees INTEGER NOT NULL DEFAULT 0,
        width INTEGER NOT NULL DEFAULT 0,
        height INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE ocr_page_results (
        id TEXT PRIMARY KEY,
        document_id TEXT NOT NULL,
        page_id TEXT NOT NULL UNIQUE,
        page_index INTEGER NOT NULL,
        image_path TEXT NOT NULL,
        extracted_text TEXT NOT NULL,
        status TEXT NOT NULL,
        confidence REAL NOT NULL DEFAULT 0.0,
        blocks_json TEXT,
        processing_duration_ms INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    appDatabase = AppDatabase(initialDatabase: db);
    dataSource = LocalDocumentDataSourceImpl(appDatabase);
    mockStorageService = MockFileStorageService();
    when(
      () => mockStorageService.deleteDocumentDirectory(any()),
    ).thenAnswer((_) async {});
    when(() => mockStorageService.clearTempFiles()).thenAnswer((_) async {});

    repository = DocumentRepositoryImpl(
      localDataSource: dataSource,
      fileStorageService: mockStorageService,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('saves and retrieves document with pages from SQLite', () async {
    final now = DateTime.now();
    final doc = DocumentEntity(
      id: 'doc_123',
      title: 'Tax Invoice',
      pdfPath: '/docs/doc_123/invoice.pdf',
      thumbnailPath: '/docs/doc_123/thumb.jpg',
      pageCount: 1,
      fileSizeBytes: 204800,
      createdAt: now,
      updatedAt: now,
      pages: [
        ScannedPage(
          id: 'page_1',
          documentId: 'doc_123',
          pageIndex: 0,
          originalImagePath: '/docs/doc_123/orig_1.jpg',
          processedImagePath: '/docs/doc_123/proc_1.jpg',
          createdAt: now,
        ),
      ],
    );

    await repository.saveDocument(doc);

    final retrieved = await repository.getDocumentById('doc_123');
    expect(retrieved, isNotNull);
    expect(retrieved!.title, equals('Tax Invoice'));
    expect(retrieved.pageCount, equals(1));
    expect(retrieved.pages.length, equals(1));
    expect(retrieved.pages.first.id, equals('page_1'));
  });

  test('getAllDocuments returns saved documents', () async {
    final now = DateTime.now();
    final doc1 = DocumentEntity(
      id: 'd1',
      title: 'Doc One',
      pdfPath: '/p1.pdf',
      pageCount: 1,
      createdAt: now,
      updatedAt: now,
    );
    final doc2 = DocumentEntity(
      id: 'd2',
      title: 'Doc Two',
      pdfPath: '/p2.pdf',
      pageCount: 2,
      createdAt: now,
      updatedAt: now,
    );

    await repository.saveDocument(doc1);
    await repository.saveDocument(doc2);

    final all = await repository.getAllDocuments();
    expect(all.length, equals(2));
  });

  test('searchDocuments filters by title', () async {
    final now = DateTime.now();
    final doc1 = DocumentEntity(
      id: 'd1',
      title: 'Passport Scan',
      pdfPath: '/p1.pdf',
      pageCount: 1,
      createdAt: now,
      updatedAt: now,
    );
    final doc2 = DocumentEntity(
      id: 'd2',
      title: 'Electricity Bill',
      pdfPath: '/p2.pdf',
      pageCount: 1,
      createdAt: now,
      updatedAt: now,
    );

    await repository.saveDocument(doc1);
    await repository.saveDocument(doc2);

    final searchResults = await repository.searchDocuments('Pass');
    expect(searchResults.length, equals(1));
    expect(searchResults.first.title, equals('Passport Scan'));
  });

  test(
    'deleteDocument removes from SQLite and calls storage cleanup',
    () async {
      final now = DateTime.now();
      final doc = DocumentEntity(
        id: 'to_delete',
        title: 'Draft',
        pdfPath: '/draft.pdf',
        pageCount: 1,
        createdAt: now,
        updatedAt: now,
      );

      await repository.saveDocument(doc);
      expect(await repository.getDocumentById('to_delete'), isNotNull);

      await repository.deleteDocument('to_delete');
      expect(await repository.getDocumentById('to_delete'), isNull);
      verify(
        () => mockStorageService.deleteDocumentDirectory('to_delete'),
      ).called(1);
    },
  );
}
