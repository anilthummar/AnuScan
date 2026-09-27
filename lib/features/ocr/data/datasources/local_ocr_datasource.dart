import 'package:sqflite/sqflite.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/ocr_dto.dart';

abstract class LocalOcrDataSource {
  Future<void> savePageOcrResult(OcrPageResultDto result);
  Future<void> saveBatchPageOcrResults(List<OcrPageResultDto> results);
  Future<OcrPageResultDto?> getPageOcrResult(String pageId);
  Future<List<OcrPageResultDto>> getDocumentOcrResults(String documentId);
  Future<void> deletePageOcrResult(String pageId);
  Future<void> deleteDocumentOcrResults(String documentId);
  Future<List<OcrPageResultDto>> searchDocumentText({
    required String documentId,
    required String query,
  });
  Future<List<OcrPageResultDto>> searchAllDocuments(String query);
}

class LocalOcrDataSourceImpl implements LocalOcrDataSource {
  const LocalOcrDataSourceImpl(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<void> savePageOcrResult(OcrPageResultDto result) async {
    try {
      final db = await _appDatabase.database;
      await db.insert(
        'ocr_page_results',
        result.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw AppDatabaseException('Failed to save page OCR result: $e', e);
    }
  }

  @override
  Future<void> saveBatchPageOcrResults(List<OcrPageResultDto> results) async {
    try {
      final db = await _appDatabase.database;
      await db.transaction((txn) async {
        for (final result in results) {
          await txn.insert(
            'ocr_page_results',
            result.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    } catch (e) {
      throw AppDatabaseException('Failed to batch save OCR results: $e', e);
    }
  }

  @override
  Future<OcrPageResultDto?> getPageOcrResult(String pageId) async {
    try {
      final db = await _appDatabase.database;
      final rows = await db.query(
        'ocr_page_results',
        where: 'page_id = ?',
        whereArgs: [pageId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return OcrPageResultDto.fromMap(rows.first);
    } catch (e) {
      throw AppDatabaseException('Failed to query page OCR result: $e', e);
    }
  }

  @override
  Future<List<OcrPageResultDto>> getDocumentOcrResults(
    String documentId,
  ) async {
    try {
      final db = await _appDatabase.database;
      final rows = await db.query(
        'ocr_page_results',
        where: 'document_id = ?',
        whereArgs: [documentId],
        orderBy: 'page_index ASC',
      );
      return rows.map((m) => OcrPageResultDto.fromMap(m)).toList();
    } catch (e) {
      throw AppDatabaseException('Failed to query document OCR results: $e', e);
    }
  }

  @override
  Future<void> deletePageOcrResult(String pageId) async {
    try {
      final db = await _appDatabase.database;
      await db.delete(
        'ocr_page_results',
        where: 'page_id = ?',
        whereArgs: [pageId],
      );
    } catch (e) {
      throw AppDatabaseException('Failed to delete page OCR result: $e', e);
    }
  }

  @override
  Future<void> deleteDocumentOcrResults(String documentId) async {
    try {
      final db = await _appDatabase.database;
      await db.delete(
        'ocr_page_results',
        where: 'document_id = ?',
        whereArgs: [documentId],
      );
    } catch (e) {
      throw AppDatabaseException(
        'Failed to delete document OCR results: $e',
        e,
      );
    }
  }

  @override
  Future<List<OcrPageResultDto>> searchDocumentText({
    required String documentId,
    required String query,
  }) async {
    try {
      final db = await _appDatabase.database;
      final rows = await db.query(
        'ocr_page_results',
        where: 'document_id = ? AND extracted_text LIKE ?',
        whereArgs: [documentId, '%$query%'],
        orderBy: 'page_index ASC',
      );
      return rows.map((m) => OcrPageResultDto.fromMap(m)).toList();
    } catch (e) {
      throw AppDatabaseException('Failed to search document text: $e', e);
    }
  }

  @override
  Future<List<OcrPageResultDto>> searchAllDocuments(String query) async {
    try {
      final db = await _appDatabase.database;
      final rows = await db.query(
        'ocr_page_results',
        where: 'extracted_text LIKE ?',
        whereArgs: ['%$query%'],
        orderBy: 'updated_at DESC',
      );
      return rows.map((m) => OcrPageResultDto.fromMap(m)).toList();
    } catch (e) {
      throw AppDatabaseException('Failed to search all documents text: $e', e);
    }
  }
}
