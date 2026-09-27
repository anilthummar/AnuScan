import 'package:equatable/equatable.dart';
import '../../domain/entities/document_counts.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/entities/document_query_filter.dart';
import '../../domain/entities/folder_entity.dart';
import '../../domain/entities/tag_entity.dart';

abstract class DocumentHistoryState extends Equatable {
  const DocumentHistoryState();

  @override
  List<Object?> get props => [];
}

class DocumentHistoryInitial extends DocumentHistoryState {
  const DocumentHistoryInitial();
}

class DocumentHistoryLoading extends DocumentHistoryState {
  const DocumentHistoryLoading();
}

class DocumentHistoryLoaded extends DocumentHistoryState {
  const DocumentHistoryLoaded({
    required this.documents,
    this.searchQuery = '',
    this.filter = const DocumentQueryFilter(),
    this.counts = const DocumentCounts(),
    this.folders = const [],
    this.tags = const [],
    this.viewMode = DocumentViewMode.list,
    this.sortOption = DocumentSortOption.newestFirst,
    this.activeTab = DocumentTab.all,
    this.selectedDocumentIds = const {},
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  final List<DocumentEntity> documents;
  final String searchQuery;
  final DocumentQueryFilter filter;
  final DocumentCounts counts;
  final List<FolderEntity> folders;
  final List<TagEntity> tags;
  final DocumentViewMode viewMode;
  final DocumentSortOption sortOption;
  final DocumentTab activeTab;
  final Set<String> selectedDocumentIds;
  final bool hasMore;
  final bool isLoadingMore;

  bool get isSearching => searchQuery.isNotEmpty;
  bool get isSelectionMode => selectedDocumentIds.isNotEmpty;

  DocumentHistoryLoaded copyWith({
    List<DocumentEntity>? documents,
    String? searchQuery,
    DocumentQueryFilter? filter,
    DocumentCounts? counts,
    List<FolderEntity>? folders,
    List<TagEntity>? tags,
    DocumentViewMode? viewMode,
    DocumentSortOption? sortOption,
    DocumentTab? activeTab,
    Set<String>? selectedDocumentIds,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return DocumentHistoryLoaded(
      documents: documents ?? this.documents,
      searchQuery: searchQuery ?? this.searchQuery,
      filter: filter ?? this.filter,
      counts: counts ?? this.counts,
      folders: folders ?? this.folders,
      tags: tags ?? this.tags,
      viewMode: viewMode ?? this.viewMode,
      sortOption: sortOption ?? this.sortOption,
      activeTab: activeTab ?? this.activeTab,
      selectedDocumentIds: selectedDocumentIds ?? this.selectedDocumentIds,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [
    documents,
    searchQuery,
    filter,
    counts,
    folders,
    tags,
    viewMode,
    sortOption,
    activeTab,
    selectedDocumentIds,
    hasMore,
    isLoadingMore,
  ];
}

class DocumentHistoryError extends DocumentHistoryState {
  const DocumentHistoryError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
