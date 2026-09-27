import 'package:sqflite/sqflite.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/recognition_dto.dart';

abstract class LocalRecognitionDataSource {
  Future<void> saveRecognition(DocumentRecognitionDto dto);
  Future<DocumentRecognitionDto?> getRecognition(String documentId);
  Future<void> updateManualClassification({
    required String documentId,
    required String documentType,
    required int updatedAt,
  });
  Future<void> updateManualMetadata(DocumentRecognitionDto dto);
  Future<void> deleteRecognition(String documentId);
}

class LocalRecognitionDataSourceImpl implements LocalRecognitionDataSource {
  const LocalRecognitionDataSourceImpl(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<void> saveRecognition(DocumentRecognitionDto dto) async {
    try {
      final db = await _appDatabase.database;
      await db.insert(
        'document_recognitions',
        dto.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw AppDatabaseException('Failed to save document recognition: $e', e);
    }
  }

  @override
  Future<DocumentRecognitionDto?> getRecognition(String documentId) async {
    try {
      final db = await _appDatabase.database;
      final rows = await db.query(
        'document_recognitions',
        where: 'document_id = ?',
        whereArgs: [documentId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return DocumentRecognitionDto.fromMap(rows.first);
    } catch (e) {
      throw AppDatabaseException('Failed to get document recognition: $e', e);
    }
  }

  @override
  Future<void> updateManualClassification({
    required String documentId,
    required String documentType,
    required int updatedAt,
  }) async {
    try {
      final db = await _appDatabase.database;
      await db.update(
        'document_recognitions',
        {
          'document_type': documentType,
          'classification_source': 'manual',
          'confidence': 1.0,
          'updated_at': updatedAt,
        },
        where: 'document_id = ?',
        whereArgs: [documentId],
      );
    } catch (e) {
      throw AppDatabaseException(
        'Failed to update manual classification: $e',
        e,
      );
    }
  }

  @override
  Future<void> updateManualMetadata(DocumentRecognitionDto dto) async {
    try {
      final db = await _appDatabase.database;
      await db.update(
        'document_recognitions',
        {
          'person_name': dto.personName,
          'company_name': dto.companyName,
          'document_number': dto.documentNumber,
          'date_text': dto.dateText,
          'due_date_text': dto.dueDateText,
          'amount_text': dto.amountText,
          'amount': dto.amount,
          'currency': dto.currency,
          'email': dto.email,
          'phone': dto.phone,
          'website': dto.website,
          'metadata_json': dto.metadataJson,
          'suggested_filename': dto.suggestedFilename,
          'classification_source': 'manual',
          'updated_at': dto.updatedAt,
        },
        where: 'document_id = ?',
        whereArgs: [dto.documentId],
      );
    } catch (e) {
      throw AppDatabaseException('Failed to update manual metadata: $e', e);
    }
  }

  @override
  Future<void> deleteRecognition(String documentId) async {
    try {
      final db = await _appDatabase.database;
      await db.delete(
        'document_recognitions',
        where: 'document_id = ?',
        whereArgs: [documentId],
      );
    } catch (e) {
      throw AppDatabaseException(
        'Failed to delete document recognition: $e',
        e,
      );
    }
  }
}
