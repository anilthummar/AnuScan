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

  group('Database v6 Migration Tests', () {
    test('Migration from v5 to v6 adds is_private column and index', () async {
      final db = await createTestDb();

      // Setup v5 schema
      await db.execute('''
        CREATE TABLE documents (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          pdf_path TEXT NOT NULL,
          thumbnail_path TEXT,
          page_count INTEGER NOT NULL DEFAULT 0,
          file_size_bytes INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          is_favorite INTEGER NOT NULL DEFAULT 0,
          is_archived INTEGER NOT NULL DEFAULT 0,
          is_deleted INTEGER NOT NULL DEFAULT 0,
          deleted_at INTEGER,
          folder_id TEXT,
          last_opened_at INTEGER
        )
      ''');

      await db.insert('documents', {
        'id': 'doc_v5',
        'title': 'Existing v5 Doc',
        'pdf_path': '/docs/doc_v5.pdf',
        'page_count': 2,
        'file_size_bytes': 2048,
        'created_at': 1700000000,
        'updated_at': 1700000000,
        'is_favorite': 1,
        'is_archived': 0,
        'is_deleted': 0,
      });

      // Run v6 migration
      await db.execute(
        'ALTER TABLE documents ADD COLUMN is_private INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_documents_is_private ON documents(is_private)',
      );

      // Verify row preserves previous data and has default is_private = 0
      final rows = await db.query('documents', where: 'id = ?', whereArgs: ['doc_v5']);
      expect(rows.length, 1);
      expect(rows.first['title'], 'Existing v5 Doc');
      expect(rows.first['is_favorite'], 1);
      expect(rows.first['is_private'], 0);

      // Verify updating is_private
      await db.update('documents', {'is_private': 1}, where: 'id = ?', whereArgs: ['doc_v5']);
      final updated = await db.query('documents', where: 'id = ?', whereArgs: ['doc_v5']);
      expect(updated.first['is_private'], 1);

      await db.close();
    });

    test('Full schema creation initializes v6 with is_private', () async {
      final db = await createTestDb();
      await AppDatabase.createSchema(db);

      await db.insert('documents', {
        'id': 'doc_v6',
        'title': 'New v6 Doc',
        'pdf_path': '/docs/doc_v6.pdf',
        'page_count': 1,
        'file_size_bytes': 1024,
        'created_at': 1700000000,
        'updated_at': 1700000000,
        'is_favorite': 0,
        'is_archived': 0,
        'is_deleted': 0,
        'is_private': 1,
      });

      final rows = await db.query('documents', where: 'id = ?', whereArgs: ['doc_v6']);
      expect(rows.length, 1);
      expect(rows.first['is_private'], 1);

      await db.close();
    });
  });
}
