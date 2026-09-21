import '../entities/document_entity.dart';

/// Repository contract for managing locally persisted scanned documents.
abstract class DocumentRepository {
  /// Retrieves all documents, ordered by recent modification.
  Future<List<DocumentEntity>> getAllDocuments();

  /// Retrieves a specific document by its ID along with all its pages.
  Future<DocumentEntity?> getDocumentById(String id);

  /// Persists a document and its pages.
  Future<void> saveDocument(DocumentEntity document);

  /// Deletes a document from database and purges its files from storage.
  Future<void> deleteDocument(String id);

  /// Renames a document and renames its PDF file.
  Future<void> renameDocument(String id, String newTitle);

  /// Searches saved documents by title query.
  Future<List<DocumentEntity>> searchDocuments(String query);
}
