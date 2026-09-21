import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../errors/exceptions.dart';

/// SQLite database manager for AnuScan.
class AppDatabase {
  AppDatabase({Database? initialDatabase}) : _database = initialDatabase;

  static const String databaseName = 'anuscan.db';
  static const int databaseVersion = 1;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = p.join(databasesPath, databaseName);

      return await openDatabase(
        path,
        version: databaseVersion,
        onCreate: _onCreate,
        onConfigure: _onConfigure,
      );
    } catch (e) {
      throw AppDatabaseException('Failed to initialize local database: $e', e);
    }
  }

  static Future<void> _onConfigure(Database db) async {
    // Enable foreign keys
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _onCreate(Database db, int version) async {
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
        created_at INTEGER NOT NULL,
        FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_document_pages_doc_id ON document_pages(document_id)
    ''');
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
