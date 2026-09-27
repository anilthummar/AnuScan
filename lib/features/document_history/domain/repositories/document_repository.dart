import '../entities/document_counts.dart';
import '../entities/document_entity.dart';
import '../entities/document_query_filter.dart';
import '../entities/folder_entity.dart';
import '../entities/tag_entity.dart';

/// Repository contract for managing locally persisted scanned documents and their organization.
abstract class DocumentRepository {
  /// Retrieves all documents, ordered by recent modification.
  Future<List<DocumentEntity>> getAllDocuments();

  /// Retrieves a specific document by its ID along with all its pages, folder, and tags.
  Future<DocumentEntity?> getDocumentById(String id);

  /// Persists a document and its pages.
  Future<void> saveDocument(DocumentEntity document);

  /// Moves a document to trash (soft delete).
  Future<void> deleteDocument(String id);

  /// Renames a document and renames its PDF file.
  Future<void> renameDocument(String id, String newTitle);

  /// Searches saved documents by title, OCR, classification, and tag query.
  Future<List<DocumentEntity>> searchDocuments(String query);

  // Phase 13 Extensions
  /// Queries documents matching the given filter with pagination and database sorting.
  Future<List<DocumentEntity>> getFilteredDocuments(DocumentQueryFilter filter);

  /// Computes aggregated document counts without N+1 queries.
  Future<DocumentCounts> getDocumentCounts();

  /// Toggles favorite status.
  Future<void> toggleFavorite(String id, bool isFavorite);

  /// Toggles private status.
  Future<void> togglePrivate(String id, bool isPrivate);

  /// Sets archived status.
  Future<void> setArchived(String id, bool isArchived);

  /// Moves document to trash.
  Future<void> moveToTrash(String id);

  /// Restores document from trash.
  Future<void> restoreFromTrash(String id);

  /// Permanently removes document record, pages, and files from storage.
  Future<void> permanentDeleteDocument(String id);

  /// Records timestamp of document opening.
  Future<void> recordDocumentOpened(String id);

  // Folder Operations
  Future<List<FolderEntity>> getFolders();
  Future<FolderEntity?> getFolderById(String id);
  Future<void> createFolder(FolderEntity folder);
  Future<void> updateFolder(FolderEntity folder);
  Future<void> deleteFolder(String id);
  Future<void> moveDocumentToFolder(String documentId, String? folderId);

  // Tag Operations
  Future<List<TagEntity>> getTags();
  Future<TagEntity?> getTagById(String id);
  Future<void> createTag(TagEntity tag);
  Future<void> updateTag(TagEntity tag);
  Future<void> deleteTag(String id);
  Future<void> assignTag(String documentId, String tagId);
  Future<void> removeTag(String documentId, String tagId);
  Future<List<TagEntity>> getTagsForDocument(String documentId);

  // Bulk Operations
  Future<void> bulkArchive(List<String> ids, bool isArchived);
  Future<void> bulkFavorite(List<String> ids, bool isFavorite);
  Future<void> bulkSetPrivate(List<String> ids, bool isPrivate);
  Future<void> bulkMoveToTrash(List<String> ids);
  Future<void> bulkRestoreFromTrash(List<String> ids);
  Future<void> bulkMoveToFolder(List<String> ids, String? folderId);
  Future<void> bulkAssignTag(List<String> ids, String tagId);
  Future<void> bulkRemoveTag(List<String> ids, String tagId);
  Future<void> bulkPermanentDelete(List<String> ids);
}
