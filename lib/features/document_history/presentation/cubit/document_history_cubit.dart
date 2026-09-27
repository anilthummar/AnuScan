import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/preferences_service.dart';
import '../../domain/entities/document_counts.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/entities/document_query_filter.dart';
import '../../domain/entities/folder_entity.dart';
import '../../domain/entities/tag_entity.dart';
import '../../domain/usecases/document_usecases.dart';
import '../../domain/usecases/management_usecases.dart';
import 'document_history_state.dart';

class DocumentHistoryCubit extends Cubit<DocumentHistoryState> {
  DocumentHistoryCubit({
    required this.getDocumentsUseCase,
    required this.deleteDocumentUseCase,
    required this.renameDocumentUseCase,
    required this.searchDocumentsUseCase,
    this.getFilteredDocumentsUseCase,
    this.getDocumentCountsUseCase,
    this.toggleFavoriteUseCase,
    this.togglePrivateUseCase,
    this.archiveDocumentUseCase,
    this.trashDocumentUseCase,
    this.restoreFromTrashUseCase,
    this.permanentDeleteDocumentUseCase,
    this.recordDocumentOpenedUseCase,
    this.getFoldersUseCase,
    this.createFolderUseCase,
    this.renameFolderUseCase,
    this.deleteFolderUseCase,
    this.moveDocumentToFolderUseCase,
    this.getTagsUseCase,
    this.createTagUseCase,
    this.deleteTagUseCase,
    this.assignTagUseCase,
    this.removeTagUseCase,
    this.bulkDocumentActionUseCase,
    this.preferencesService,
  }) : super(const DocumentHistoryInitial());

  final GetDocumentsUseCase getDocumentsUseCase;
  final DeleteDocumentUseCase deleteDocumentUseCase;
  final RenameDocumentUseCase renameDocumentUseCase;
  final SearchDocumentsUseCase searchDocumentsUseCase;

  // Phase 13 Use Cases & Services
  final GetFilteredDocumentsUseCase? getFilteredDocumentsUseCase;
  final GetDocumentCountsUseCase? getDocumentCountsUseCase;
  final ToggleFavoriteUseCase? toggleFavoriteUseCase;
  final TogglePrivateUseCase? togglePrivateUseCase;
  final ArchiveDocumentUseCase? archiveDocumentUseCase;
  final TrashDocumentUseCase? trashDocumentUseCase;
  final RestoreFromTrashUseCase? restoreFromTrashUseCase;
  final PermanentDeleteDocumentUseCase? permanentDeleteDocumentUseCase;
  final RecordDocumentOpenedUseCase? recordDocumentOpenedUseCase;
  final GetFoldersUseCase? getFoldersUseCase;
  final CreateFolderUseCase? createFolderUseCase;
  final RenameFolderUseCase? renameFolderUseCase;
  final DeleteFolderUseCase? deleteFolderUseCase;
  final MoveDocumentToFolderUseCase? moveDocumentToFolderUseCase;
  final GetTagsUseCase? getTagsUseCase;
  final CreateTagUseCase? createTagUseCase;
  final DeleteTagUseCase? deleteTagUseCase;
  final AssignTagUseCase? assignTagUseCase;
  final RemoveTagUseCase? removeTagUseCase;
  final BulkDocumentActionUseCase? bulkDocumentActionUseCase;
  final PreferencesService? preferencesService;

  static const int _pageSize = 50;

  DocumentQueryFilter _buildFilterForTab(
    DocumentTab tab, {
    String? searchQuery,
    String? documentType,
    String? folderId,
    String? tagId,
    DocumentSortOption sortOption = DocumentSortOption.newestFirst,
  }) {
    switch (tab) {
      case DocumentTab.all:
        return DocumentQueryFilter(
          searchQuery: searchQuery,
          documentType: documentType,
          folderId: folderId,
          tagId: tagId,
          isArchived: false,
          isDeleted: false,
          sortOption: sortOption,
          limit: _pageSize,
          offset: 0,
        );
      case DocumentTab.favorites:
        return DocumentQueryFilter(
          searchQuery: searchQuery,
          documentType: documentType,
          folderId: folderId,
          tagId: tagId,
          isFavorite: true,
          isArchived: false,
          isDeleted: false,
          sortOption: sortOption,
          limit: _pageSize,
          offset: 0,
        );
      case DocumentTab.private:
        return DocumentQueryFilter(
          searchQuery: searchQuery,
          documentType: documentType,
          folderId: folderId,
          tagId: tagId,
          isPrivate: true,
          isArchived: false,
          isDeleted: false,
          sortOption: sortOption,
          limit: _pageSize,
          offset: 0,
        );
      case DocumentTab.folders:
        return DocumentQueryFilter(
          searchQuery: searchQuery,
          documentType: documentType,
          folderId: folderId,
          tagId: tagId,
          isArchived: false,
          isDeleted: false,
          sortOption: sortOption,
          limit: _pageSize,
          offset: 0,
        );
      case DocumentTab.archived:
        return DocumentQueryFilter(
          searchQuery: searchQuery,
          documentType: documentType,
          folderId: folderId,
          tagId: tagId,
          isArchived: true,
          isDeleted: false,
          sortOption: sortOption,
          limit: _pageSize,
          offset: 0,
        );
      case DocumentTab.trash:
        return DocumentQueryFilter(
          searchQuery: searchQuery,
          documentType: documentType,
          isDeleted: true,
          sortOption: sortOption,
          limit: _pageSize,
          offset: 0,
        );
    }
  }

  Future<void> loadDocuments({DocumentTab? targetTab}) async {
    final currentLoaded = state is DocumentHistoryLoaded
        ? state as DocumentHistoryLoaded
        : null;

    final tab = targetTab ?? currentLoaded?.activeTab ?? DocumentTab.all;
    var viewMode = currentLoaded?.viewMode ?? DocumentViewMode.list;
    var sortOption =
        currentLoaded?.sortOption ?? DocumentSortOption.newestFirst;

    if (preferencesService != null && currentLoaded == null) {
      final savedVm = await preferencesService!.getViewMode();
      viewMode = DocumentViewMode.fromString(savedVm);
      final savedSort = await preferencesService!.getSortOption();
      sortOption = DocumentSortOption.fromString(savedSort);
    }

    final filter = _buildFilterForTab(
      tab,
      searchQuery: currentLoaded?.filter.searchQuery,
      documentType: currentLoaded?.filter.documentType,
      folderId: currentLoaded?.filter.folderId,
      tagId: currentLoaded?.filter.tagId,
      sortOption: sortOption,
    );

    emit(const DocumentHistoryLoading());

    try {
      List<DocumentEntity> docs;
      if (getFilteredDocumentsUseCase != null) {
        docs = await getFilteredDocumentsUseCase!(filter);
      } else {
        docs = await getDocumentsUseCase();
      }

      DocumentCounts counts = const DocumentCounts();
      if (getDocumentCountsUseCase != null) {
        try {
          counts = await getDocumentCountsUseCase!();
        } catch (_) {}
      }

      List<FolderEntity> folders = const [];
      if (getFoldersUseCase != null) {
        try {
          folders = await getFoldersUseCase!();
        } catch (_) {}
      }

      List<TagEntity> tags = const [];
      if (getTagsUseCase != null) {
        try {
          tags = await getTagsUseCase!();
        } catch (_) {}
      }

      emit(
        DocumentHistoryLoaded(
          documents: docs,
          searchQuery: filter.searchQuery ?? '',
          filter: filter,
          counts: counts,
          folders: folders,
          tags: tags,
          viewMode: viewMode,
          sortOption: sortOption,
          activeTab: tab,
          hasMore: docs.length >= _pageSize,
          isLoadingMore: false,
          selectedDocumentIds: const {},
        ),
      );
    } catch (e) {
      emit(DocumentHistoryError('Failed to load documents: $e'));
    }
  }

  Future<void> loadNextPage() async {
    final current = state;
    if (current is! DocumentHistoryLoaded ||
        !current.hasMore ||
        current.isLoadingMore ||
        getFilteredDocumentsUseCase == null) {
      return;
    }

    emit(current.copyWith(isLoadingMore: true));

    try {
      final nextFilter = current.filter.copyWith(
        offset: current.documents.length,
        limit: _pageSize,
      );

      final nextDocs = await getFilteredDocumentsUseCase!(nextFilter);

      emit(
        current.copyWith(
          documents: [...current.documents, ...nextDocs],
          hasMore: nextDocs.length >= _pageSize,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      emit(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> searchDocuments(String query) async {
    final trimmed = query.trim();
    final current = state is DocumentHistoryLoaded
        ? state as DocumentHistoryLoaded
        : null;

    if (getFilteredDocumentsUseCase == null) {
      if (trimmed.isEmpty) {
        await loadDocuments();
        return;
      }
      emit(const DocumentHistoryLoading());
      try {
        final results = await searchDocumentsUseCase(trimmed);
        emit(DocumentHistoryLoaded(documents: results, searchQuery: trimmed));
      } catch (e) {
        emit(DocumentHistoryError('Failed to search documents: $e'));
      }
      return;
    }

    final newFilter = (current?.filter ?? const DocumentQueryFilter()).copyWith(
      searchQuery: trimmed.isEmpty ? null : trimmed,
      offset: 0,
    );

    emit(const DocumentHistoryLoading());
    try {
      final docs = await getFilteredDocumentsUseCase!(newFilter);
      emit(
        (current ?? const DocumentHistoryLoaded(documents: [])).copyWith(
          documents: docs,
          searchQuery: trimmed,
          filter: newFilter,
          hasMore: docs.length >= _pageSize,
          isLoadingMore: false,
        ),
      );
    } catch (e) {
      emit(DocumentHistoryError('Failed to search documents: $e'));
    }
  }

  Future<void> setDocumentTypeFilter(String? type) async {
    final current = state;
    if (current is! DocumentHistoryLoaded) return;

    final resolved = (type == null || type == 'All') ? null : type;
    final newFilter = current.filter.copyWith(
      documentType: () => resolved,
      offset: 0,
    );

    emit(const DocumentHistoryLoading());
    try {
      final docs = getFilteredDocumentsUseCase != null
          ? await getFilteredDocumentsUseCase!(newFilter)
          : await getDocumentsUseCase();

      emit(
        current.copyWith(
          documents: docs,
          filter: newFilter,
          hasMore: docs.length >= _pageSize,
        ),
      );
    } catch (e) {
      emit(DocumentHistoryError('Failed to filter by type: $e'));
    }
  }

  Future<void> setFolderFilter(String? folderId) async {
    final current = state;
    if (current is! DocumentHistoryLoaded) return;

    final newFilter = current.filter.copyWith(
      folderId: () => folderId,
      offset: 0,
    );

    emit(const DocumentHistoryLoading());
    try {
      final docs = getFilteredDocumentsUseCase != null
          ? await getFilteredDocumentsUseCase!(newFilter)
          : await getDocumentsUseCase();

      emit(
        current.copyWith(
          documents: docs,
          filter: newFilter,
          hasMore: docs.length >= _pageSize,
        ),
      );
    } catch (e) {
      emit(DocumentHistoryError('Failed to filter by folder: $e'));
    }
  }

  Future<void> setTagFilter(String? tagId) async {
    final current = state;
    if (current is! DocumentHistoryLoaded) return;

    final newFilter = current.filter.copyWith(tagId: () => tagId, offset: 0);

    emit(const DocumentHistoryLoading());
    try {
      final docs = getFilteredDocumentsUseCase != null
          ? await getFilteredDocumentsUseCase!(newFilter)
          : await getDocumentsUseCase();

      emit(
        current.copyWith(
          documents: docs,
          filter: newFilter,
          hasMore: docs.length >= _pageSize,
        ),
      );
    } catch (e) {
      emit(DocumentHistoryError('Failed to filter by tag: $e'));
    }
  }

  Future<void> setSortOption(DocumentSortOption sortOption) async {
    final current = state;
    if (current is! DocumentHistoryLoaded) return;

    if (preferencesService != null) {
      await preferencesService!.setSortOption(sortOption.name);
    }

    final newFilter = current.filter.copyWith(
      sortOption: sortOption,
      offset: 0,
    );

    emit(const DocumentHistoryLoading());
    try {
      final docs = getFilteredDocumentsUseCase != null
          ? await getFilteredDocumentsUseCase!(newFilter)
          : await getDocumentsUseCase();

      emit(
        current.copyWith(
          documents: docs,
          filter: newFilter,
          sortOption: sortOption,
          hasMore: docs.length >= _pageSize,
        ),
      );
    } catch (e) {
      emit(DocumentHistoryError('Failed to sort documents: $e'));
    }
  }

  Future<void> setViewMode(DocumentViewMode viewMode) async {
    final current = state;
    if (current is! DocumentHistoryLoaded) return;

    if (preferencesService != null) {
      await preferencesService!.setViewMode(viewMode.name);
    }

    emit(current.copyWith(viewMode: viewMode));
  }

  Future<void> setActiveTab(DocumentTab tab) async {
    await loadDocuments(targetTab: tab);
  }

  Future<void> clearFilters() async {
    final current = state;
    if (current is! DocumentHistoryLoaded) return;

    final resetFilter = _buildFilterForTab(
      current.activeTab,
      sortOption: current.sortOption,
    );

    emit(const DocumentHistoryLoading());
    try {
      final docs = getFilteredDocumentsUseCase != null
          ? await getFilteredDocumentsUseCase!(resetFilter)
          : await getDocumentsUseCase();

      emit(
        current.copyWith(
          documents: docs,
          searchQuery: '',
          filter: resetFilter,
          hasMore: docs.length >= _pageSize,
        ),
      );
    } catch (e) {
      emit(DocumentHistoryError('Failed to clear filters: $e'));
    }
  }

  // Selection Mode
  void toggleSelection(String id) {
    final current = state;
    if (current is! DocumentHistoryLoaded) return;

    final updated = Set<String>.from(current.selectedDocumentIds);
    if (updated.contains(id)) {
      updated.remove(id);
    } else {
      updated.add(id);
    }
    emit(current.copyWith(selectedDocumentIds: updated));
  }

  void selectAll() {
    final current = state;
    if (current is! DocumentHistoryLoaded) return;

    final allIds = current.documents.map((d) => d.id).toSet();
    emit(current.copyWith(selectedDocumentIds: allIds));
  }

  void clearSelection() {
    final current = state;
    if (current is! DocumentHistoryLoaded) return;

    emit(current.copyWith(selectedDocumentIds: const {}));
  }

  // Single Item Operations
  Future<void> deleteDocument(String id) async {
    try {
      if (trashDocumentUseCase != null) {
        await trashDocumentUseCase!(id);
      } else {
        await deleteDocumentUseCase(id);
      }
      await loadDocuments();
    } catch (e) {
      emit(DocumentHistoryError('Failed to delete document: $e'));
    }
  }

  Future<void> permanentDeleteDocument(String id) async {
    try {
      if (permanentDeleteDocumentUseCase != null) {
        await permanentDeleteDocumentUseCase!(id);
      } else {
        await deleteDocumentUseCase(id);
      }
      await loadDocuments();
    } catch (e) {
      emit(DocumentHistoryError('Failed to permanently delete document: $e'));
    }
  }

  Future<void> restoreFromTrash(String id) async {
    try {
      if (restoreFromTrashUseCase != null) {
        await restoreFromTrashUseCase!(id);
      }
      await loadDocuments();
    } catch (e) {
      emit(DocumentHistoryError('Failed to restore document: $e'));
    }
  }

  Future<void> toggleFavorite(String id, bool isFavorite) async {
    try {
      if (toggleFavoriteUseCase != null) {
        await toggleFavoriteUseCase!(id, isFavorite);
      }
      await loadDocuments();
    } catch (e) {
      emit(DocumentHistoryError('Failed to toggle favorite: $e'));
    }
  }

  Future<void> togglePrivate(String id, bool isPrivate) async {
    try {
      if (togglePrivateUseCase != null) {
        await togglePrivateUseCase!(id, isPrivate);
      }
      await loadDocuments();
    } catch (e) {
      emit(DocumentHistoryError('Failed to toggle private: $e'));
    }
  }

  Future<void> archiveDocument(String id, bool isArchived) async {
    try {
      if (archiveDocumentUseCase != null) {
        await archiveDocumentUseCase!(id, isArchived);
      }
      await loadDocuments();
    } catch (e) {
      emit(DocumentHistoryError('Failed to archive document: $e'));
    }
  }

  Future<void> renameDocument(String id, String newTitle) async {
    try {
      await renameDocumentUseCase(id, newTitle);
      await loadDocuments();
    } catch (e) {
      emit(DocumentHistoryError('Failed to rename document: $e'));
    }
  }

  Future<void> recordDocumentOpened(String id) async {
    if (recordDocumentOpenedUseCase != null) {
      await recordDocumentOpenedUseCase!(id);
    }
  }

  // Folder Operations
  Future<void> createFolder(
    String name, {
    int? colorValue,
    String? iconName,
  }) async {
    if (createFolderUseCase == null) return;
    try {
      final now = DateTime.now();
      final folder = FolderEntity(
        id: 'folder_${now.millisecondsSinceEpoch}',
        name: name.trim(),
        colorValue: colorValue,
        iconName: iconName,
        createdAt: now,
        updatedAt: now,
      );
      await createFolderUseCase!(folder);
      await loadDocuments();
    } catch (e) {
      emit(DocumentHistoryError('Failed to create folder: $e'));
    }
  }

  Future<void> renameFolder(String id, String newName) async {
    if (renameFolderUseCase == null) return;
    try {
      final currentFolders = (state is DocumentHistoryLoaded)
          ? (state as DocumentHistoryLoaded).folders
          : <FolderEntity>[];
      final existing = currentFolders.firstWhere((f) => f.id == id);
      final updated = existing.copyWith(
        name: newName.trim(),
        updatedAt: DateTime.now(),
      );
      await renameFolderUseCase!(updated);
      await loadDocuments();
    } catch (e) {
      emit(DocumentHistoryError('Failed to rename folder: $e'));
    }
  }

  Future<void> deleteFolder(String id) async {
    if (deleteFolderUseCase == null) return;
    try {
      await deleteFolderUseCase!(id);
      await loadDocuments();
    } catch (e) {
      emit(DocumentHistoryError('Failed to delete folder: $e'));
    }
  }

  Future<void> moveDocumentToFolder(String documentId, String? folderId) async {
    if (moveDocumentToFolderUseCase == null) return;
    try {
      await moveDocumentToFolderUseCase!(documentId, folderId);
      await loadDocuments();
    } catch (e) {
      emit(DocumentHistoryError('Failed to move document: $e'));
    }
  }

  // Tag Operations
  Future<void> createTag(String name, {int? colorValue}) async {
    if (createTagUseCase == null) return;
    try {
      final tag = TagEntity(
        id: 'tag_${DateTime.now().millisecondsSinceEpoch}',
        name: name.trim(),
        colorValue: colorValue,
        createdAt: DateTime.now(),
      );
      await createTagUseCase!(tag);
      await loadDocuments();
    } catch (e) {
      emit(DocumentHistoryError('Failed to create tag: $e'));
    }
  }

  Future<void> deleteTag(String id) async {
    if (deleteTagUseCase == null) return;
    try {
      await deleteTagUseCase!(id);
      await loadDocuments();
    } catch (e) {
      emit(DocumentHistoryError('Failed to delete tag: $e'));
    }
  }

  Future<void> assignTag(String documentId, String tagId) async {
    if (assignTagUseCase == null) return;
    try {
      await assignTagUseCase!(documentId, tagId);
      await loadDocuments();
    } catch (e) {
      emit(DocumentHistoryError('Failed to assign tag: $e'));
    }
  }

  Future<void> removeTag(String documentId, String tagId) async {
    if (removeTagUseCase == null) return;
    try {
      await removeTagUseCase!(documentId, tagId);
      await loadDocuments();
    } catch (e) {
      emit(DocumentHistoryError('Failed to remove tag: $e'));
    }
  }

  // Bulk Operations
  Future<void> bulkArchive(bool isArchived) async {
    final current = state;
    if (current is! DocumentHistoryLoaded ||
        current.selectedDocumentIds.isEmpty ||
        bulkDocumentActionUseCase == null) {
      return;
    }
    try {
      final ids = current.selectedDocumentIds.toList();
      await bulkDocumentActionUseCase!.archive(ids, isArchived);
      clearSelection();
      await loadDocuments();
    } catch (e) {
      emit(DocumentHistoryError('Failed to bulk archive documents: $e'));
    }
  }

  Future<void> bulkFavorite(bool isFavorite) async {
    final current = state;
    if (current is! DocumentHistoryLoaded ||
        current.selectedDocumentIds.isEmpty ||
        bulkDocumentActionUseCase == null) {
      return;
    }
    try {
      final ids = current.selectedDocumentIds.toList();
      await bulkDocumentActionUseCase!.favorite(ids, isFavorite);
      clearSelection();
      await loadDocuments();
    } catch (e) {
      emit(DocumentHistoryError('Failed to bulk favorite documents: $e'));
    }
  }

  Future<void> bulkSetPrivate(bool isPrivate) async {
    final current = state;
    if (current is! DocumentHistoryLoaded ||
        current.selectedDocumentIds.isEmpty ||
        bulkDocumentActionUseCase == null) {
      return;
    }
    try {
      final ids = current.selectedDocumentIds.toList();
      await bulkDocumentActionUseCase!.setPrivate(ids, isPrivate);
      clearSelection();
      await loadDocuments();
    } catch (e) {
      emit(DocumentHistoryError('Failed to bulk set private: $e'));
    }
  }

  Future<void> bulkMoveToTrash() async {
    final current = state;
    if (current is! DocumentHistoryLoaded ||
        current.selectedDocumentIds.isEmpty ||
        bulkDocumentActionUseCase == null) {
      return;
    }
    try {
      final ids = current.selectedDocumentIds.toList();
      await bulkDocumentActionUseCase!.moveToTrash(ids);
      clearSelection();
      await loadDocuments();
    } catch (e) {
      emit(DocumentHistoryError('Failed to bulk move documents to trash: $e'));
    }
  }

  Future<void> bulkRestoreFromTrash() async {
    final current = state;
    if (current is! DocumentHistoryLoaded ||
        current.selectedDocumentIds.isEmpty ||
        bulkDocumentActionUseCase == null) {
      return;
    }
    try {
      final ids = current.selectedDocumentIds.toList();
      await bulkDocumentActionUseCase!.restoreFromTrash(ids);
      clearSelection();
      await loadDocuments();
    } catch (e) {
      emit(
        DocumentHistoryError('Failed to bulk restore documents from trash: $e'),
      );
    }
  }

  Future<void> bulkMoveToFolder(String? folderId) async {
    final current = state;
    if (current is! DocumentHistoryLoaded ||
        current.selectedDocumentIds.isEmpty ||
        bulkDocumentActionUseCase == null) {
      return;
    }
    try {
      final ids = current.selectedDocumentIds.toList();
      await bulkDocumentActionUseCase!.moveToFolder(ids, folderId);
      clearSelection();
      await loadDocuments();
    } catch (e) {
      emit(DocumentHistoryError('Failed to bulk move documents to folder: $e'));
    }
  }

  Future<void> bulkAssignTag(String tagId) async {
    final current = state;
    if (current is! DocumentHistoryLoaded ||
        current.selectedDocumentIds.isEmpty ||
        bulkDocumentActionUseCase == null) {
      return;
    }
    try {
      final ids = current.selectedDocumentIds.toList();
      await bulkDocumentActionUseCase!.assignTag(ids, tagId);
      clearSelection();
      await loadDocuments();
    } catch (e) {
      emit(DocumentHistoryError('Failed to bulk assign tag: $e'));
    }
  }

  Future<void> bulkRemoveTag(String tagId) async {
    final current = state;
    if (current is! DocumentHistoryLoaded ||
        current.selectedDocumentIds.isEmpty ||
        bulkDocumentActionUseCase == null) {
      return;
    }
    try {
      final ids = current.selectedDocumentIds.toList();
      await bulkDocumentActionUseCase!.removeTag(ids, tagId);
      clearSelection();
      await loadDocuments();
    } catch (e) {
      emit(DocumentHistoryError('Failed to bulk remove tag: $e'));
    }
  }

  Future<void> bulkPermanentDelete() async {
    final current = state;
    if (current is! DocumentHistoryLoaded ||
        current.selectedDocumentIds.isEmpty ||
        bulkDocumentActionUseCase == null) {
      return;
    }
    try {
      final ids = current.selectedDocumentIds.toList();
      await bulkDocumentActionUseCase!.permanentDelete(ids);
      clearSelection();
      await loadDocuments();
    } catch (e) {
      emit(DocumentHistoryError('Failed to bulk permanently delete: $e'));
    }
  }
}
