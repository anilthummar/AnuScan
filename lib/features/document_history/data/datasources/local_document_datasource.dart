import 'package:sqflite/sqflite.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/document_dto.dart';

abstract class LocalDocumentDataSource {
  Future<List<DocumentDto>> getAllDocuments();
  Future<DocumentDto?> getDocumentById(String id);
  Future<List<DocumentPageDto>> getPagesForDocument(String documentId);
  Future<void> insertOrUpdateDocument(DocumentDto document, List<DocumentPageDto> pages);
  Future<void> deleteDocument(String id);
  Future<void> updateDocumentTitle(String id, String newTitle, String newPdfPath);
  Future<List<DocumentDto>> searchDocuments(String query);
}

class LocalDocumentDataSourceImpl implements LocalDocumentDataSource {
  const LocalDocumentDataSourceImpl(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<List<DocumentDto>> getAllDocuments() async {
    try {
      final db = await _appDatabase.database;
      final results = await db.query(
        'documents',
        orderBy: 'updated_at DESC',
      );
      return results.map((m) => DocumentDto.fromMap(m)).toList();
    } catch (e) {
      throw AppDatabaseException('Failed to query all documents: $e', e);
    }
  }

  @override
  Future<DocumentDto?> getDocumentById(String id) async {
    try {
      final db = await _appDatabase.database;
      final results = await db.query(
        'documents',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (results.isEmpty) return null;
      return DocumentDto.fromMap(results.first);
    } catch (e) {
      throw AppDatabaseException('Failed to query document by id: $e', e);
    }
  }

  @override
  Future<List<DocumentPageDto>> getPagesForDocument(String documentId) async {
    try {
      final db = await _appDatabase.database;
      final results = await db.query(
        'document_pages',
        where: 'document_id = ?',
        whereArgs: [documentId],
        orderBy: 'page_index ASC',
      );
      return results.map((m) => DocumentPageDto.fromMap(m)).toList();
    } catch (e) {
      throw AppDatabaseException('Failed to query document pages: $e', e);
    }
  }

  @override
  Future<void> insertOrUpdateDocument(DocumentDto document, List<DocumentPageDto> pages) async {
    try {
      final db = await _appDatabase.database;
      await db.transaction((txn) async {
        await txn.insert(
          'documents',
          document.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Delete old pages and re-insert updated page ordering
        await txn.delete(
          'document_pages',
          where: 'document_id = ?',
          whereArgs: [document.id],
        );

        for (final page in pages) {
          await txn.insert(
            'document_pages',
            page.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    } catch (e) {
      throw AppDatabaseException('Failed to save document: $e', e);
    }
  }

  @override
  Future<void> deleteDocument(String id) async {
    try {
      final db = await _appDatabase.database;
      await db.transaction((txn) async {
        await txn.delete(
          'document_pages',
          where: 'document_id = ?',
          whereArgs: [id],
        );
        await txn.delete(
          'documents',
          where: 'id = ?',
          whereArgs: [id],
        );
      });
    } catch (e) {
      throw AppDatabaseException('Failed to delete document: $e', e);
    }
  }

  @override
  Future<void> updateDocumentTitle(String id, String newTitle, String newPdfPath) async {
    try {
      final db = await _appDatabase.database;
      await db.update(
        'documents',
        {
          'title': newTitle,
          'pdf_path': newPdfPath,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw AppDatabaseException('Failed to rename document: $e', e);
    }
  }

  @override
  Future<List<DocumentDto>> searchDocuments(String query) async {
    try {
      final db = await _appDatabase.database;
      final results = await db.query(
        'documents',
        where: 'title LIKE ?',
        whereArgs: ['%$query%'],
        orderBy: 'updated_at DESC',
      );
      return results.map((m) => DocumentDto.fromMap(m)).toList();
    } catch (e) {
      throw AppDatabaseException('Failed to search documents: $e', e);
    }
  }
}
