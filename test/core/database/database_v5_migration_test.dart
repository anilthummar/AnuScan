import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:anuscan/core/database/app_database.dart';

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

  group('Database v5 Migration & Schema Tests', () {
    test(
      'Migration from version 4 to 5 preserves data and adds all new columns and tables',
      () async {
        final db = await createTestDb();

        // 1. Setup v4 schema
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
        CREATE TABLE document_recognitions (
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

        // Insert pre-existing v4 document
        await db.insert('documents', {
          'id': 'doc_v4',
          'title': 'v4 Contract',
          'pdf_path': '/path/v4.pdf',
          'page_count': 3,
          'file_size_bytes': 10240,
          'created_at': 1700000000,
          'updated_at': 1700000000,
        });

        // 2. Perform v4 -> v5 migration step
        await db.execute(
          'ALTER TABLE documents ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE documents ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE documents ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0',
        );
        await db.execute('ALTER TABLE documents ADD COLUMN deleted_at INTEGER');
        await db.execute('ALTER TABLE documents ADD COLUMN folder_id TEXT');
        await db.execute(
          'ALTER TABLE documents ADD COLUMN last_opened_at INTEGER',
        );

        await db.execute('''
        CREATE TABLE IF NOT EXISTS folders (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL UNIQUE,
          color_value INTEGER,
          icon_name TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');

        await db.execute('''
        CREATE TABLE IF NOT EXISTS tags (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL UNIQUE,
          color_value INTEGER,
          created_at INTEGER NOT NULL
        )
      ''');

        await db.execute('''
        CREATE TABLE IF NOT EXISTS document_tags (
          document_id TEXT NOT NULL,
          tag_id TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          PRIMARY KEY (document_id, tag_id),
          FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE,
          FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
        )
      ''');

        await db.execute('''
        CREATE TABLE IF NOT EXISTS app_preferences (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');

        // Verify existing document has default values for new columns
        final result = await db.query(
          'documents',
          where: 'id = ?',
          whereArgs: ['doc_v4'],
        );
        expect(result.length, equals(1));
        final row = result.first;
        expect(row['title'], equals('v4 Contract'));
        expect(row['is_favorite'], equals(0));
        expect(row['is_archived'], equals(0));
        expect(row['is_deleted'], equals(0));
        expect(row['deleted_at'], isNull);
        expect(row['folder_id'], isNull);
        expect(row['last_opened_at'], isNull);

        await db.close();
      },
    );

    test(
      'Foreign key constraints: folder deletion sets document folder_id to NULL',
      () async {
        final db = await createTestDb();
        await AppDatabase.createSchema(db);

        // Create folder
        await db.insert('folders', {
          'id': 'f_work',
          'name': 'Work',
          'created_at': 1000,
          'updated_at': 1000,
        });

        // Create document in folder
        await db.insert('documents', {
          'id': 'doc_in_folder',
          'title': 'Work Doc',
          'pdf_path': '/work.pdf',
          'page_count': 1,
          'file_size_bytes': 500,
          'created_at': 1000,
          'updated_at': 1000,
          'folder_id': 'f_work',
        });

        // Verify document has folder_id
        var doc = (await db.query(
          'documents',
          where: 'id = ?',
          whereArgs: ['doc_in_folder'],
        )).first;
        expect(doc['folder_id'], equals('f_work'));

        // Delete folder (documents should NOT be deleted, folder_id becomes NULL)
        await db.delete('folders', where: 'id = ?', whereArgs: ['f_work']);

        doc = (await db.query(
          'documents',
          where: 'id = ?',
          whereArgs: ['doc_in_folder'],
        )).first;
        expect(doc, isNotNull);
        expect(doc['folder_id'], isNull);

        await db.close();
      },
    );

    test(
      'Foreign key constraints: document deletion cascades to document_tags',
      () async {
        final db = await createTestDb();
        await AppDatabase.createSchema(db);

        // Insert doc and tag
        await db.insert('documents', {
          'id': 'doc_tagged',
          'title': 'Receipt',
          'pdf_path': '/r.pdf',
          'page_count': 1,
          'file_size_bytes': 300,
          'created_at': 1000,
          'updated_at': 1000,
        });

        await db.insert('tags', {
          'id': 'tag_finance',
          'name': 'Finance',
          'color_value': 0xFF00FF00,
          'created_at': 1000,
        });

        await db.insert('document_tags', {
          'document_id': 'doc_tagged',
          'tag_id': 'tag_finance',
        });

        var tagLinks = await db.query(
          'document_tags',
          where: 'document_id = ?',
          whereArgs: ['doc_tagged'],
        );
        expect(tagLinks.length, equals(1));

        // Delete document
        await db.delete(
          'documents',
          where: 'id = ?',
          whereArgs: ['doc_tagged'],
        );

        // document_tags entry should be cascaded and deleted
        tagLinks = await db.query(
          'document_tags',
          where: 'document_id = ?',
          whereArgs: ['doc_tagged'],
        );
        expect(tagLinks, isEmpty);

        // The tag itself should still exist
        final tags = await db.query(
          'tags',
          where: 'id = ?',
          whereArgs: ['tag_finance'],
        );
        expect(tags.length, equals(1));

        await db.close();
      },
    );

    test(
      'Foreign key constraints: tag deletion cascades to document_tags',
      () async {
        final db = await createTestDb();
        await AppDatabase.createSchema(db);

        await db.insert('documents', {
          'id': 'doc_tagged_2',
          'title': 'Receipt 2',
          'pdf_path': '/r2.pdf',
          'page_count': 1,
          'file_size_bytes': 300,
          'created_at': 1000,
          'updated_at': 1000,
        });

        await db.insert('tags', {
          'id': 'tag_tax',
          'name': 'Tax',
          'color_value': 0xFFFF0000,
          'created_at': 1000,
        });

        await db.insert('document_tags', {
          'document_id': 'doc_tagged_2',
          'tag_id': 'tag_tax',
        });

        // Delete tag
        await db.delete('tags', where: 'id = ?', whereArgs: ['tag_tax']);

        final tagLinks = await db.query(
          'document_tags',
          where: 'document_id = ?',
          whereArgs: ['doc_tagged_2'],
        );
        expect(tagLinks, isEmpty);

        // The document itself should still exist
        final docs = await db.query(
          'documents',
          where: 'id = ?',
          whereArgs: ['doc_tagged_2'],
        );
        expect(docs.length, equals(1));

        await db.close();
      },
    );
  });
}
