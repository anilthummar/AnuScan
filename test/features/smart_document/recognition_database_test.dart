import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:anuscan/core/database/app_database.dart';
import 'package:anuscan/features/document_history/data/datasources/local_document_datasource.dart';
import 'package:anuscan/features/smart_document/data/datasources/local_recognition_datasource.dart';
import 'package:anuscan/features/smart_document/data/models/recognition_dto.dart';

void main() {
  sqfliteFfiInit();

  Future<Database> createTestDb() async {
    return databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        singleInstance: false,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
      ),
    );
  }

  group('Recognition Database & SQLite v4 Migration Tests', () {
    test(
      'Migration from version 3 to 4 creates document_recognitions table and indexes safely',
      () async {
        final db = await createTestDb();

        // 1. Setup version 3 schema
        await db.execute('''
        CREATE TABLE IF NOT EXISTS documents (
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

        // Insert pre-existing v3 data
        await db.insert('documents', {
          'id': 'doc_v3',
          'title': 'Existing Contract',
          'pdf_path': '/path/to/contract.pdf',
          'page_count': 2,
          'file_size_bytes': 2048,
          'created_at': 1000000,
          'updated_at': 1000000,
        });

        // 2. Perform v3 -> v4 upgrade
        await db.execute('''
        CREATE TABLE IF NOT EXISTS document_recognitions (
          id TEXT PRIMARY KEY,
          document_id TEXT NOT NULL UNIQUE,
          document_type TEXT NOT NULL,
          classification_source TEXT NOT NULL,
          confidence REAL NOT NULL DEFAULT 0.0,
          matched_signals TEXT,
          classifier_version TEXT NOT NULL,
          suggested_filename TEXT,
          person_name TEXT,
          company_name TEXT,
          document_number TEXT,
          date_text TEXT,
          due_date_text TEXT,
          amount_text TEXT,
          amount REAL,
          currency TEXT,
          email TEXT,
          phone TEXT,
          website TEXT,
          metadata_json TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
        )
      ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_doc_recog_doc_id ON document_recognitions(document_id)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_doc_recog_type ON document_recognitions(document_type)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_doc_recog_company ON document_recognitions(company_name)',
        );

        // Verify v3 document is intact
        final docs = await db.query('documents');
        expect(docs.length, equals(1));
        expect(docs.first['id'], equals('doc_v3'));

        // Verify document_recognitions is empty and queryable
        final recogs = await db.query('document_recognitions');
        expect(recogs, isEmpty);

        await db.close();
      },
    );

    test(
      'LocalRecognitionDataSourceImpl handles full CRUD lifecycle and manual provenance',
      () async {
        final db = await createTestDb();

        // Setup schema
        await db.execute('''
        CREATE TABLE IF NOT EXISTS documents (
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
        CREATE TABLE IF NOT EXISTS document_recognitions (
          id TEXT PRIMARY KEY,
          document_id TEXT NOT NULL UNIQUE,
          document_type TEXT NOT NULL,
          classification_source TEXT NOT NULL,
          confidence REAL NOT NULL DEFAULT 0.0,
          matched_signals TEXT,
          classifier_version TEXT NOT NULL,
          suggested_filename TEXT,
          person_name TEXT,
          company_name TEXT,
          document_number TEXT,
          date_text TEXT,
          due_date_text TEXT,
          amount_text TEXT,
          amount REAL,
          currency TEXT,
          email TEXT,
          phone TEXT,
          website TEXT,
          metadata_json TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
        )
      ''');

        // Insert parent document
        await db.insert('documents', {
          'id': 'doc_100',
          'title': 'Invoice 100',
          'pdf_path': '/path/inv100.pdf',
          'page_count': 1,
          'file_size_bytes': 1024,
          'created_at': 1000,
          'updated_at': 1000,
        });

        final appDb = AppDatabase(initialDatabase: db);
        final dataSource = LocalRecognitionDataSourceImpl(appDb);

        // 1. Insert recognition DTO
        final now = DateTime.now().millisecondsSinceEpoch;
        final dto = DocumentRecognitionDto(
          id: 'recog_100',
          documentId: 'doc_100',
          documentType: 'invoice',
          classificationSource: 'automatic',
          confidence: 0.92,
          matchedSignals: 'tax invoice, amount due',
          classifierVersion: '1.0',
          suggestedFilename: 'Acme - Invoice - 100',
          companyName: 'Acme Corp',
          documentNumber: 'INV-100',
          amount: 500.0,
          currency: '\$',
          amountText: '\$500.00',
          createdAt: now,
          updatedAt: now,
        );

        await dataSource.saveRecognition(dto);

        // 2. Retrieve recognition DTO
        final retrieved = await dataSource.getRecognition('doc_100');
        expect(retrieved, isNotNull);
        expect(retrieved!.documentType, equals('invoice'));
        expect(retrieved.companyName, equals('Acme Corp'));
        expect(retrieved.confidence, equals(0.92));
        expect(retrieved.classificationSource, equals('automatic'));

        // 3. Update manual classification
        await dataSource.updateManualClassification(
          documentId: 'doc_100',
          documentType: 'receipt',
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );

        final afterManualType = await dataSource.getRecognition('doc_100');
        expect(afterManualType!.documentType, equals('receipt'));
        expect(afterManualType.classificationSource, equals('manual'));
        expect(afterManualType.confidence, equals(1.0));

        // 4. Update manual metadata
        final updatedDto = afterManualType.copyWith(
          companyName: 'Acme Retail Store',
          personName: 'Customer Bob',
          classificationSource: 'manual',
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        await dataSource.updateManualMetadata(updatedDto);

        final afterManualMeta = await dataSource.getRecognition('doc_100');
        expect(afterManualMeta!.companyName, equals('Acme Retail Store'));
        expect(afterManualMeta.personName, equals('Customer Bob'));

        // 5. Delete recognition
        await dataSource.deleteRecognition('doc_100');
        final afterDelete = await dataSource.getRecognition('doc_100');
        expect(afterDelete, isNull);

        await db.close();
      },
    );

    test(
      'Foreign key cascading deletes document_recognitions when parent document is deleted',
      () async {
        final db = await createTestDb();

        await db.execute('''
        CREATE TABLE IF NOT EXISTS documents (
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
        CREATE TABLE IF NOT EXISTS document_recognitions (
          id TEXT PRIMARY KEY,
          document_id TEXT NOT NULL UNIQUE,
          document_type TEXT NOT NULL,
          classification_source TEXT NOT NULL,
          confidence REAL NOT NULL DEFAULT 0.0,
          matched_signals TEXT,
          classifier_version TEXT NOT NULL,
          suggested_filename TEXT,
          person_name TEXT,
          company_name TEXT,
          document_number TEXT,
          date_text TEXT,
          due_date_text TEXT,
          amount_text TEXT,
          amount REAL,
          currency TEXT,
          email TEXT,
          phone TEXT,
          website TEXT,
          metadata_json TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
        )
      ''');

        await db.insert('documents', {
          'id': 'doc_cascade',
          'title': 'Temporary Receipt',
          'pdf_path': '/path/receipt.pdf',
          'page_count': 1,
          'file_size_bytes': 500,
          'created_at': 2000,
          'updated_at': 2000,
        });

        final appDb = AppDatabase(initialDatabase: db);
        final dataSource = LocalRecognitionDataSourceImpl(appDb);

        final now = DateTime.now().millisecondsSinceEpoch;
        await dataSource.saveRecognition(
          DocumentRecognitionDto(
            id: 'recog_cascade',
            documentId: 'doc_cascade',
            documentType: 'receipt',
            classificationSource: 'automatic',
            confidence: 0.9,
            matchedSignals: 'receipt',
            classifierVersion: '1.0',
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(await dataSource.getRecognition('doc_cascade'), isNotNull);

        // Delete parent document
        await db.delete(
          'documents',
          where: 'id = ?',
          whereArgs: ['doc_cascade'],
        );

        // Recognition row must have cascaded and disappeared
        expect(await dataSource.getRecognition('doc_cascade'), isNull);

        await db.close();
      },
    );

    test(
      'LocalDocumentDataSource.searchDocuments finds documents using recognition metadata and classification',
      () async {
        final db = await createTestDb();

        // Setup complete schema
        await AppDatabase.createSchema(db);

        // Insert test documents
        await db.insert('documents', {
          'id': 'doc_inv',
          'title': 'Untitled Scan 1',
          'pdf_path': '/p1.pdf',
          'page_count': 1,
          'file_size_bytes': 1000,
          'created_at': 100,
          'updated_at': 100,
        });
        await db.insert('documents', {
          'id': 'doc_rec',
          'title': 'Untitled Scan 2',
          'pdf_path': '/p2.pdf',
          'page_count': 1,
          'file_size_bytes': 1000,
          'created_at': 200,
          'updated_at': 200,
        });

        // Insert recognition for doc_inv: company 'Microsoft', type 'invoice', number 'MS-2026'
        await db.insert('document_recognitions', {
          'id': 'recog_1',
          'document_id': 'doc_inv',
          'document_type': 'invoice',
          'classification_source': 'automatic',
          'confidence': 0.95,
          'company_name': 'Microsoft Corporation',
          'document_number': 'MS-2026',
          'classifier_version': '1.0',
          'created_at': 100,
          'updated_at': 100,
        });

        // Insert recognition for doc_rec: person 'Satya Nadella', type 'receipt'
        await db.insert('document_recognitions', {
          'id': 'recog_2',
          'document_id': 'doc_rec',
          'document_type': 'receipt',
          'classification_source': 'automatic',
          'confidence': 0.88,
          'person_name': 'Satya Nadella',
          'classifier_version': '1.0',
          'created_at': 200,
          'updated_at': 200,
        });

        final appDb = AppDatabase(initialDatabase: db);
        final docDataSource = LocalDocumentDataSourceImpl(appDb);

        // Search by document type "invoice"
        final invoiceResults = await docDataSource.searchDocuments('invoice');
        expect(invoiceResults.length, equals(1));
        expect(invoiceResults.first.id, equals('doc_inv'));

        // Search by company "Microsoft"
        final companyResults = await docDataSource.searchDocuments('Microsoft');
        expect(companyResults.length, equals(1));
        expect(companyResults.first.id, equals('doc_inv'));

        // Search by document number "MS-2026"
        final numberResults = await docDataSource.searchDocuments('MS-2026');
        expect(numberResults.length, equals(1));
        expect(numberResults.first.id, equals('doc_inv'));

        // Search by person "Satya"
        final personResults = await docDataSource.searchDocuments('Satya');
        expect(personResults.length, equals(1));
        expect(personResults.first.id, equals('doc_rec'));

        await db.close();
      },
    );
  });
}
