import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../errors/exceptions.dart';

/// SQLite database manager for AnuScan.
class AppDatabase {
  AppDatabase({Database? initialDatabase}) : _database = initialDatabase;

  static const String databaseName = 'anuscan.db';
  static const int databaseVersion = 6;

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
        onUpgrade: _onUpgrade,
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

  /// Helper for test fixtures and in-memory databases to initialize the full schema.
  static Future<void> createSchema(Database db) =>
      _onCreate(db, databaseVersion);

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
        updated_at INTEGER NOT NULL,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        is_private INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        folder_id TEXT,
        last_opened_at INTEGER,
        FOREIGN KEY (folder_id) REFERENCES folders(id) ON DELETE SET NULL
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

    await db.execute('''
      CREATE INDEX idx_document_pages_doc_id ON document_pages(document_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_documents_updated_at ON documents(updated_at DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_documents_title ON documents(title)
    ''');

    await db.execute('''
      CREATE INDEX idx_documents_favorite ON documents(is_favorite)
    ''');

    await db.execute('''
      CREATE INDEX idx_documents_archived ON documents(is_archived)
    ''');

    await db.execute('''
      CREATE INDEX idx_documents_deleted ON documents(is_deleted)
    ''');

    await db.execute('''
      CREATE INDEX idx_documents_folder_id ON documents(folder_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_documents_last_opened ON documents(last_opened_at)
    ''');

    await db.execute('''
      CREATE INDEX idx_documents_is_private ON documents(is_private)
    ''');

    await db.execute('''
      CREATE INDEX idx_ocr_page_results_doc_id ON ocr_page_results(document_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_ocr_page_results_page_id ON ocr_page_results(page_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_ocr_page_results_text ON ocr_page_results(extracted_text)
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

    await db.execute('''
      CREATE INDEX idx_doc_recog_doc_id ON document_recognitions(document_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_doc_recog_type ON document_recognitions(document_type)
    ''');

    await db.execute('''
      CREATE INDEX idx_doc_recog_company ON document_recognitions(company_name)
    ''');

    await db.execute('''
      CREATE TABLE folders (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        color_value INTEGER,
        icon_name TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_folders_name ON folders(name)
    ''');

    await db.execute('''
      CREATE TABLE tags (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        color_value INTEGER,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_tags_name ON tags(name)
    ''');

    await db.execute('''
      CREATE TABLE document_tags (
        document_id TEXT NOT NULL,
        tag_id TEXT NOT NULL,
        PRIMARY KEY (document_id, tag_id),
        FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_doc_tags_doc ON document_tags(document_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_doc_tags_tag ON document_tags(tag_id)
    ''');

    await db.execute('''
      CREATE TABLE app_preferences (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_documents_updated_at ON documents(updated_at DESC)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_documents_title ON documents(title)
      ''');
    }

    if (oldVersion < 3) {
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
    }

    if (oldVersion < 4) {
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
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_doc_recog_doc_id ON document_recognitions(document_id)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_doc_recog_type ON document_recognitions(document_type)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_doc_recog_company ON document_recognitions(company_name)
      ''');
    }

    if (oldVersion < 5) {
      // Add new management columns to documents table
      final columns = [
        'ALTER TABLE documents ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0',
        'ALTER TABLE documents ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0',
        'ALTER TABLE documents ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0',
        'ALTER TABLE documents ADD COLUMN deleted_at INTEGER',
        'ALTER TABLE documents ADD COLUMN folder_id TEXT',
        'ALTER TABLE documents ADD COLUMN last_opened_at INTEGER',
      ];

      for (final sql in columns) {
        try {
          await db.execute(sql);
        } catch (_) {
          // Column may already exist if partially upgraded
        }
      }

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
        CREATE INDEX IF NOT EXISTS idx_folders_name ON folders(name)
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
        CREATE INDEX IF NOT EXISTS idx_tags_name ON tags(name)
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS document_tags (
          document_id TEXT NOT NULL,
          tag_id TEXT NOT NULL,
          PRIMARY KEY (document_id, tag_id),
          FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE,
          FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_doc_tags_doc ON document_tags(document_id)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_doc_tags_tag ON document_tags(tag_id)
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_preferences (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_documents_favorite ON documents(is_favorite)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_documents_archived ON documents(is_archived)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_documents_deleted ON documents(is_deleted)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_documents_folder_id ON documents(folder_id)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_documents_last_opened ON documents(last_opened_at)
      ''');
    }

    if (oldVersion < 6) {
      try {
        await db.execute(
          'ALTER TABLE documents ADD COLUMN is_private INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {
        // Column may already exist if partially upgraded
      }

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_documents_is_private ON documents(is_private)
      ''');
    }
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
