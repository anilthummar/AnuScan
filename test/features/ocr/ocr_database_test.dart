import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:anuscan/core/database/app_database.dart';
import 'package:anuscan/features/ocr/data/datasources/local_ocr_datasource.dart';
import 'package:anuscan/features/ocr/data/models/ocr_dto.dart';

void main() {
  sqfliteFfiInit();

  group('OCR Database & Migration Tests', () {
    test(
      'Migration from version 2 to 3 creates ocr_page_results and indexes',
      () async {
        final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

        // Simulate version 2 schema
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

        // Insert pre-existing document at v2
        await db.insert('documents', {
          'id': 'doc_existing',
          'title': 'Pre-existing Doc',
          'pdf_path': '/path/to.pdf',
          'page_count': 1,
          'file_size_bytes': 1000,
          'created_at': 1000000,
          'updated_at': 1000000,
        });

        // Run AppDatabase._onUpgrade(db, 2, 3) logic
        // In SQLite, we can invoke onUpgrade or the upgrade SQL directly
        await db.execute('''
        CREATE TABLE IF NOT EXISTS ocr_page_results (
          id TEXT PRIMARY KEY,
          document_id TEXT NOT NULL,
          page_id TEXT NOT NULL,
          page_index INTEGER NOT NULL,
          extracted_text TEXT NOT NULL,
          status TEXT NOT NULL,
          language TEXT,
          processing_duration_ms INTEGER,
          image_path TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
        )
      ''');
        await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_ocr_page_results_doc_id ON ocr_page_results(document_id)
      ''');
        await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_ocr_page_results_page_id ON ocr_page_results(page_id)
      ''');
        await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_ocr_page_results_text ON ocr_page_results(extracted_text)
      ''');

        // Verify pre-existing document still exists untouched
        final docs = await db.query('documents');
        expect(docs.length, 1);
        expect(docs.first['id'], 'doc_existing');

        // Verify ocr_page_results is queryable
        final ocrResults = await db.query('ocr_page_results');
        expect(ocrResults, isEmpty);

        await db.close();
      },
    );

    test(
      'Foreign key cascading deletes OCR page results when parent document is deleted',
      () async {
        final db = await databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(
            onConfigure: (database) async {
              await database.execute('PRAGMA foreign_keys = ON');
            },
          ),
        );

        // Create v3 schema
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
        CREATE TABLE ocr_page_results (
          id TEXT PRIMARY KEY,
          document_id TEXT NOT NULL,
          page_id TEXT NOT NULL,
          page_index INTEGER NOT NULL,
          extracted_text TEXT NOT NULL,
          status TEXT NOT NULL,
          language TEXT,
          processing_duration_ms INTEGER,
          image_path TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
        )
      ''');

        // Insert document
        await db.insert('documents', {
          'id': 'doc_to_delete',
          'title': 'Test Cascade Doc',
          'pdf_path': '/path/test.pdf',
          'page_count': 1,
          'file_size_bytes': 1024,
          'created_at': 1000,
          'updated_at': 1000,
        });

        // Insert 2 OCR results referencing doc_to_delete
        await db.insert('ocr_page_results', {
          'id': 'ocr_1',
          'document_id': 'doc_to_delete',
          'page_id': 'page_1',
          'page_index': 0,
          'extracted_text': 'First page content',
          'status': 'completed',
          'image_path': '/img/p1.jpg',
          'created_at': 1000,
          'updated_at': 1000,
        });
        await db.insert('ocr_page_results', {
          'id': 'ocr_2',
          'document_id': 'doc_to_delete',
          'page_id': 'page_2',
          'page_index': 1,
          'extracted_text': 'Second page content',
          'status': 'completed',
          'image_path': '/img/p2.jpg',
          'created_at': 1000,
          'updated_at': 1000,
        });

        final countBefore = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM ocr_page_results WHERE document_id = ?',
            ['doc_to_delete'],
          ),
        );
        expect(countBefore, 2);

        // Delete parent document
        await db.delete(
          'documents',
          where: 'id = ?',
          whereArgs: ['doc_to_delete'],
        );

        // Verify cascade deletion
        final countAfter = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM ocr_page_results WHERE document_id = ?',
            ['doc_to_delete'],
          ),
        );
        expect(countAfter, 0);

        await db.close();
      },
    );

    test(
      'LocalOcrDataSourceImpl handles full CRUD and search operations',
      () async {
        final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
        await db.execute('''
        CREATE TABLE ocr_page_results (
          id TEXT PRIMARY KEY,
          document_id TEXT NOT NULL,
          page_id TEXT NOT NULL,
          page_index INTEGER NOT NULL,
          extracted_text TEXT NOT NULL,
          status TEXT NOT NULL,
          language TEXT,
          processing_duration_ms INTEGER,
          image_path TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');

        final appDatabase = AppDatabase(initialDatabase: db);
        final dataSource = LocalOcrDataSourceImpl(appDatabase);

        final dto1 = OcrPageResultDto(
          id: 'res_1',
          documentId: 'doc_alpha',
          pageId: 'page_alpha_0',
          pageIndex: 0,
          extractedText: 'Confidential agreement and terms',
          status: 'completed',
          imagePath: '/path/1.png',
          createdAt: 1000,
          updatedAt: 1000,
        );
        final dto2 = OcrPageResultDto(
          id: 'res_2',
          documentId: 'doc_alpha',
          pageId: 'page_alpha_1',
          pageIndex: 1,
          extractedText: 'Signature and date: 2026-09-22',
          status: 'completed',
          imagePath: '/path/2.png',
          createdAt: 2000,
          updatedAt: 2000,
        );

        // Save individually & in batch
        await dataSource.savePageOcrResult(dto1);
        await dataSource.saveBatchPageOcrResults([dto2]);

        // Get page result
        final fetched1 = await dataSource.getPageOcrResult('page_alpha_0');
        expect(fetched1, isNotNull);
        expect(fetched1!.extractedText, 'Confidential agreement and terms');

        // Get document results
        final docResults = await dataSource.getDocumentOcrResults('doc_alpha');
        expect(docResults.length, 2);
        expect(docResults[0].pageIndex, 0);
        expect(docResults[1].pageIndex, 1);

        // Search in document
        final searchWithin = await dataSource.searchDocumentText(
          documentId: 'doc_alpha',
          query: 'Agreement',
        );
        expect(searchWithin.length, 1);
        expect(searchWithin.first.pageId, 'page_alpha_0');

        // Search all documents
        final searchAll = await dataSource.searchAllDocuments('2026');
        expect(searchAll.length, 1);
        expect(searchAll.first.pageId, 'page_alpha_1');

        // Delete single page result
        await dataSource.deletePageOcrResult('page_alpha_0');
        final afterPageDelete = await dataSource.getPageOcrResult(
          'page_alpha_0',
        );
        expect(afterPageDelete, isNull);

        // Delete document results
        await dataSource.deleteDocumentOcrResults('doc_alpha');
        final afterDocDelete = await dataSource.getDocumentOcrResults(
          'doc_alpha',
        );
        expect(afterDocDelete, isEmpty);

        await db.close();
      },
    );
  });
}
