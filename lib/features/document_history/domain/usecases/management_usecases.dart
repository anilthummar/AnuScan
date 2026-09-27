import '../entities/document_counts.dart';
import '../entities/document_entity.dart';
import '../entities/document_query_filter.dart';
import '../entities/folder_entity.dart';
import '../entities/tag_entity.dart';
import '../repositories/document_repository.dart';

class GetFilteredDocumentsUseCase {
  const GetFilteredDocumentsUseCase(this._repository);
  final DocumentRepository _repository;

  Future<List<DocumentEntity>> call(DocumentQueryFilter filter) =>
      _repository.getFilteredDocuments(filter);
}

class GetDocumentCountsUseCase {
  const GetDocumentCountsUseCase(this._repository);
  final DocumentRepository _repository;

  Future<DocumentCounts> call() => _repository.getDocumentCounts();
}

class ToggleFavoriteUseCase {
  const ToggleFavoriteUseCase(this._repository);
  final DocumentRepository _repository;

  Future<void> call(String id, bool isFavorite) =>
      _repository.toggleFavorite(id, isFavorite);
}

class TogglePrivateUseCase {
  const TogglePrivateUseCase(this._repository);
  final DocumentRepository _repository;

  Future<void> call(String id, bool isPrivate) =>
      _repository.togglePrivate(id, isPrivate);
}

class ArchiveDocumentUseCase {
  const ArchiveDocumentUseCase(this._repository);
  final DocumentRepository _repository;

  Future<void> call(String id, bool isArchived) =>
      _repository.setArchived(id, isArchived);
}

class TrashDocumentUseCase {
  const TrashDocumentUseCase(this._repository);
  final DocumentRepository _repository;

  Future<void> call(String id) => _repository.moveToTrash(id);
}

class RestoreFromTrashUseCase {
  const RestoreFromTrashUseCase(this._repository);
  final DocumentRepository _repository;

  Future<void> call(String id) => _repository.restoreFromTrash(id);
}

class PermanentDeleteDocumentUseCase {
  const PermanentDeleteDocumentUseCase(this._repository);
  final DocumentRepository _repository;

  Future<void> call(String id) => _repository.permanentDeleteDocument(id);
}

class RecordDocumentOpenedUseCase {
  const RecordDocumentOpenedUseCase(this._repository);
  final DocumentRepository _repository;

  Future<void> call(String id) => _repository.recordDocumentOpened(id);
}

// Folder Use Cases
class GetFoldersUseCase {
  const GetFoldersUseCase(this._repository);
  final DocumentRepository _repository;

  Future<List<FolderEntity>> call() => _repository.getFolders();
}

class CreateFolderUseCase {
  const CreateFolderUseCase(this._repository);
  final DocumentRepository _repository;

  Future<void> call(FolderEntity folder) => _repository.createFolder(folder);
}

class RenameFolderUseCase {
  const RenameFolderUseCase(this._repository);
  final DocumentRepository _repository;

  Future<void> call(FolderEntity folder) => _repository.updateFolder(folder);
}

class DeleteFolderUseCase {
  const DeleteFolderUseCase(this._repository);
  final DocumentRepository _repository;

  Future<void> call(String id) => _repository.deleteFolder(id);
}

class MoveDocumentToFolderUseCase {
  const MoveDocumentToFolderUseCase(this._repository);
  final DocumentRepository _repository;

  Future<void> call(String documentId, String? folderId) =>
      _repository.moveDocumentToFolder(documentId, folderId);
}

// Tag Use Cases
class GetTagsUseCase {
  const GetTagsUseCase(this._repository);
  final DocumentRepository _repository;

  Future<List<TagEntity>> call() => _repository.getTags();
}

class CreateTagUseCase {
  const CreateTagUseCase(this._repository);
  final DocumentRepository _repository;

  Future<void> call(TagEntity tag) => _repository.createTag(tag);
}

class RenameTagUseCase {
  const RenameTagUseCase(this._repository);
  final DocumentRepository _repository;

  Future<void> call(TagEntity tag) => _repository.updateTag(tag);
}

class DeleteTagUseCase {
  const DeleteTagUseCase(this._repository);
  final DocumentRepository _repository;

  Future<void> call(String id) => _repository.deleteTag(id);
}

class AssignTagUseCase {
  const AssignTagUseCase(this._repository);
  final DocumentRepository _repository;

  Future<void> call(String documentId, String tagId) =>
      _repository.assignTag(documentId, tagId);
}

class RemoveTagUseCase {
  const RemoveTagUseCase(this._repository);
  final DocumentRepository _repository;

  Future<void> call(String documentId, String tagId) =>
      _repository.removeTag(documentId, tagId);
}

// Bulk Actions Use Case
class BulkDocumentActionUseCase {
  const BulkDocumentActionUseCase(this._repository);
  final DocumentRepository _repository;

  Future<void> archive(List<String> ids, bool isArchived) =>
      _repository.bulkArchive(ids, isArchived);

  Future<void> favorite(List<String> ids, bool isFavorite) =>
      _repository.bulkFavorite(ids, isFavorite);

  Future<void> setPrivate(List<String> ids, bool isPrivate) =>
      _repository.bulkSetPrivate(ids, isPrivate);

  Future<void> moveToTrash(List<String> ids) =>
      _repository.bulkMoveToTrash(ids);

  Future<void> restoreFromTrash(List<String> ids) =>
      _repository.bulkRestoreFromTrash(ids);

  Future<void> moveToFolder(List<String> ids, String? folderId) =>
      _repository.bulkMoveToFolder(ids, folderId);

  Future<void> assignTag(List<String> ids, String tagId) =>
      _repository.bulkAssignTag(ids, tagId);

  Future<void> removeTag(List<String> ids, String tagId) =>
      _repository.bulkRemoveTag(ids, tagId);

  Future<void> permanentDelete(List<String> ids) =>
      _repository.bulkPermanentDelete(ids);
}
