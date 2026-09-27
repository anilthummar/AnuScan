import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../../core/services/file_storage_service.dart';
import '../../../../core/utils/file_utils.dart';
import '../../domain/entities/document_counts.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/entities/document_query_filter.dart';
import '../../domain/entities/folder_entity.dart';
import '../../domain/entities/tag_entity.dart';
import '../../domain/repositories/document_repository.dart';
import '../datasources/local_document_datasource.dart';
import '../models/document_dto.dart';
import '../models/folder_dto.dart';
import '../models/tag_dto.dart';

class DocumentRepositoryImpl implements DocumentRepository {
  const DocumentRepositoryImpl({
    required this.localDataSource,
    required this.fileStorageService,
  });

  final LocalDocumentDataSource localDataSource;
  final FileStorageService fileStorageService;

  @override
  Future<List<DocumentEntity>> getAllDocuments() async {
    final dtos = await localDataSource.getAllDocuments();
    return dtos.map((d) => d.toEntity()).toList();
  }

  @override
  Future<DocumentEntity?> getDocumentById(String id) async {
    final dto = await localDataSource.getDocumentById(id);
    if (dto == null) return null;

    final pageDtos = await localDataSource.getPagesForDocument(id);
    final pages = pageDtos.map((p) => p.toEntity()).toList();

    return dto.toEntity(pages: pages);
  }

  @override
  Future<void> saveDocument(DocumentEntity document) async {
    var docToSave = document;
    if ((docToSave.thumbnailPath == null || docToSave.thumbnailPath!.isEmpty) &&
        docToSave.pages.isNotEmpty) {
      docToSave = docToSave.copyWith(
        thumbnailPath: docToSave.pages.first.processedImagePath,
      );
    }
    final docDto = DocumentDto.fromEntity(docToSave);
    final pageDtos = docToSave.pages
        .map((p) => DocumentPageDto.fromEntity(p))
        .toList();

    await localDataSource.insertOrUpdateDocument(docDto, pageDtos);
  }

  @override
  Future<void> deleteDocument(String id) async {
    // Soft-delete to trash
    await localDataSource.moveToTrash(id);
  }

  @override
  Future<void> permanentDeleteDocument(String id) async {
    final existing = await localDataSource.getDocumentById(id);
    if (existing != null) {
      final pdfFile = File(existing.pdfPath);
      if (await pdfFile.exists()) {
        try {
          await pdfFile.delete();
        } catch (_) {}
      }
    }
    await localDataSource.permanentDeleteDocument(id);
    await fileStorageService.deleteDocumentDirectory(id);
    await fileStorageService.clearTempFiles();
  }

  @override
  Future<void> renameDocument(String id, String newTitle) async {
    final existing = await localDataSource.getDocumentById(id);
    if (existing == null) return;

    var newPdfPath = existing.pdfPath;
    final oldPdfFile = File(existing.pdfPath);

    if (await oldPdfFile.exists()) {
      final sanitized = FileUtils.sanitizeFileName(newTitle);
      final dir = oldPdfFile.parent.path;
      final targetPath = p.join(dir, '$sanitized.pdf');

      if (targetPath != existing.pdfPath) {
        await oldPdfFile.rename(targetPath);
        newPdfPath = targetPath;
      }
    }

    await localDataSource.updateDocumentTitle(id, newTitle, newPdfPath);
  }

  @override
  Future<List<DocumentEntity>> searchDocuments(String query) async {
    final dtos = await localDataSource.searchDocuments(query);
    return dtos.map((d) => d.toEntity()).toList();
  }

  @override
  Future<List<DocumentEntity>> getFilteredDocuments(
    DocumentQueryFilter filter,
  ) async {
    final dtos = await localDataSource.getFilteredDocuments(filter);
    return dtos.map((d) => d.toEntity()).toList();
  }

  @override
  Future<DocumentCounts> getDocumentCounts() {
    return localDataSource.getDocumentCounts();
  }

  @override
  Future<void> toggleFavorite(String id, bool isFavorite) {
    return localDataSource.toggleFavorite(id, isFavorite);
  }

  @override
  Future<void> togglePrivate(String id, bool isPrivate) {
    return localDataSource.togglePrivate(id, isPrivate);
  }

  @override
  Future<void> setArchived(String id, bool isArchived) {
    return localDataSource.setArchived(id, isArchived);
  }

  @override
  Future<void> moveToTrash(String id) {
    return localDataSource.moveToTrash(id);
  }

  @override
  Future<void> restoreFromTrash(String id) {
    return localDataSource.restoreFromTrash(id);
  }

  @override
  Future<void> recordDocumentOpened(String id) {
    return localDataSource.recordDocumentOpened(id);
  }

  // Folder Operations
  @override
  Future<List<FolderEntity>> getFolders() async {
    final dtos = await localDataSource.getAllFolders();
    return dtos.map((f) => f.toEntity()).toList();
  }

  @override
  Future<FolderEntity?> getFolderById(String id) async {
    final dto = await localDataSource.getFolderById(id);
    return dto?.toEntity();
  }

  @override
  Future<void> createFolder(FolderEntity folder) {
    return localDataSource.insertFolder(FolderDto.fromEntity(folder));
  }

  @override
  Future<void> updateFolder(FolderEntity folder) {
    return localDataSource.updateFolder(FolderDto.fromEntity(folder));
  }

  @override
  Future<void> deleteFolder(String id) {
    return localDataSource.deleteFolder(id);
  }

  @override
  Future<void> moveDocumentToFolder(String documentId, String? folderId) {
    return localDataSource.moveDocumentToFolder(documentId, folderId);
  }

  // Tag Operations
  @override
  Future<List<TagEntity>> getTags() async {
    final dtos = await localDataSource.getAllTags();
    return dtos.map((t) => t.toEntity()).toList();
  }

  @override
  Future<TagEntity?> getTagById(String id) async {
    final dto = await localDataSource.getTagById(id);
    return dto?.toEntity();
  }

  @override
  Future<void> createTag(TagEntity tag) {
    return localDataSource.insertTag(TagDto.fromEntity(tag));
  }

  @override
  Future<void> updateTag(TagEntity tag) {
    return localDataSource.updateTag(TagDto.fromEntity(tag));
  }

  @override
  Future<void> deleteTag(String id) {
    return localDataSource.deleteTag(id);
  }

  @override
  Future<void> assignTag(String documentId, String tagId) {
    return localDataSource.assignTag(documentId, tagId);
  }

  @override
  Future<void> removeTag(String documentId, String tagId) {
    return localDataSource.removeTag(documentId, tagId);
  }

  @override
  Future<List<TagEntity>> getTagsForDocument(String documentId) async {
    final dtos = await localDataSource.getTagsForDocument(documentId);
    return dtos.map((t) => t.toEntity()).toList();
  }

  // Bulk Operations
  @override
  Future<void> bulkArchive(List<String> ids, bool isArchived) {
    return localDataSource.bulkArchive(ids, isArchived);
  }

  @override
  Future<void> bulkFavorite(List<String> ids, bool isFavorite) {
    return localDataSource.bulkFavorite(ids, isFavorite);
  }

  @override
  Future<void> bulkSetPrivate(List<String> ids, bool isPrivate) {
    return localDataSource.bulkSetPrivate(ids, isPrivate);
  }

  @override
  Future<void> bulkMoveToTrash(List<String> ids) {
    return localDataSource.bulkMoveToTrash(ids);
  }

  @override
  Future<void> bulkRestoreFromTrash(List<String> ids) {
    return localDataSource.bulkRestoreFromTrash(ids);
  }

  @override
  Future<void> bulkMoveToFolder(List<String> ids, String? folderId) {
    return localDataSource.bulkMoveToFolder(ids, folderId);
  }

  @override
  Future<void> bulkAssignTag(List<String> ids, String tagId) {
    return localDataSource.bulkAssignTag(ids, tagId);
  }

  @override
  Future<void> bulkRemoveTag(List<String> ids, String tagId) {
    return localDataSource.bulkRemoveTag(ids, tagId);
  }

  @override
  Future<void> bulkPermanentDelete(List<String> ids) async {
    for (final id in ids) {
      final existing = await localDataSource.getDocumentById(id);
      if (existing != null) {
        final pdfFile = File(existing.pdfPath);
        if (await pdfFile.exists()) {
          try {
            await pdfFile.delete();
          } catch (_) {}
        }
      }
      await fileStorageService.deleteDocumentDirectory(id);
    }
    await localDataSource.bulkPermanentDelete(ids);
    await fileStorageService.clearTempFiles();
  }
}
