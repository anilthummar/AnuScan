import '../entities/document_entity.dart';
import '../repositories/document_repository.dart';

class GetDocumentsUseCase {
  const GetDocumentsUseCase(this._repository);
  final DocumentRepository _repository;

  Future<List<DocumentEntity>> call() => _repository.getAllDocuments();
}

class GetDocumentByIdUseCase {
  const GetDocumentByIdUseCase(this._repository);
  final DocumentRepository _repository;

  Future<DocumentEntity?> call(String id) => _repository.getDocumentById(id);
}

class SaveDocumentUseCase {
  const SaveDocumentUseCase(this._repository);
  final DocumentRepository _repository;

  Future<void> call(DocumentEntity document) =>
      _repository.saveDocument(document);
}

class DeleteDocumentUseCase {
  const DeleteDocumentUseCase(this._repository);
  final DocumentRepository _repository;

  Future<void> call(String id) => _repository.deleteDocument(id);
}

class RenameDocumentUseCase {
  const RenameDocumentUseCase(this._repository);
  final DocumentRepository _repository;

  Future<void> call(String id, String newTitle) =>
      _repository.renameDocument(id, newTitle);
}

class SearchDocumentsUseCase {
  const SearchDocumentsUseCase(this._repository);
  final DocumentRepository _repository;

  Future<List<DocumentEntity>> call(String query) =>
      _repository.searchDocuments(query);
}
