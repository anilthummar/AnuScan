import 'package:equatable/equatable.dart';

/// Available sort criteria for document listing.
enum DocumentSortOption {
  newestFirst,
  oldestFirst,
  recentlyUpdated,
  nameAscending,
  nameDescending,
  largestFile,
  smallestFile,
  mostPages,
  leastPages,
  lastOpened;

  String get displayName {
    switch (this) {
      case DocumentSortOption.newestFirst:
        return 'Newest First';
      case DocumentSortOption.oldestFirst:
        return 'Oldest First';
      case DocumentSortOption.recentlyUpdated:
        return 'Recently Updated';
      case DocumentSortOption.nameAscending:
        return 'Name (A → Z)';
      case DocumentSortOption.nameDescending:
        return 'Name (Z → A)';
      case DocumentSortOption.largestFile:
        return 'Largest File';
      case DocumentSortOption.smallestFile:
        return 'Smallest File';
      case DocumentSortOption.mostPages:
        return 'Most Pages';
      case DocumentSortOption.leastPages:
        return 'Least Pages';
      case DocumentSortOption.lastOpened:
        return 'Recently Opened';
    }
  }

  static DocumentSortOption fromString(String? value) {
    if (value == null) return DocumentSortOption.newestFirst;
    return DocumentSortOption.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DocumentSortOption.newestFirst,
    );
  }
}

/// View presentation mode for documents.
enum DocumentViewMode {
  list,
  grid;

  static DocumentViewMode fromString(String? value) {
    if (value == 'grid') return DocumentViewMode.grid;
    return DocumentViewMode.list;
  }
}

/// Active top-level navigation tab for documents.
enum DocumentTab {
  all,
  favorites,
  private,
  folders,
  archived,
  trash;

  String get displayName {
    switch (this) {
      case DocumentTab.all:
        return 'All Documents';
      case DocumentTab.favorites:
        return 'Favorites';
      case DocumentTab.private:
        return 'Private';
      case DocumentTab.folders:
        return 'Folders';
      case DocumentTab.archived:
        return 'Archive';
      case DocumentTab.trash:
        return 'Trash';
    }
  }
}

/// Structured filter parameters passed down to database queries.
class DocumentQueryFilter extends Equatable {
  const DocumentQueryFilter({
    this.searchQuery,
    this.isFavorite,
    this.isPrivate,
    this.isArchived = false,
    this.isDeleted = false,
    this.folderId,
    this.tagId,
    this.documentType,
    this.sortOption = DocumentSortOption.newestFirst,
    this.limit = 50,
    this.offset = 0,
  });

  final String? searchQuery;
  final bool? isFavorite;
  final bool? isPrivate;
  final bool isArchived;
  final bool isDeleted;
  final String? folderId;
  final String? tagId;
  final String? documentType;
  final DocumentSortOption sortOption;
  final int limit;
  final int offset;

  bool get hasActiveFilters =>
      (searchQuery != null && searchQuery!.trim().isNotEmpty) ||
      isFavorite == true ||
      isPrivate == true ||
      folderId != null ||
      tagId != null ||
      documentType != null;

  DocumentQueryFilter copyWith({
    String? searchQuery,
    bool? Function()? isFavorite,
    bool? Function()? isPrivate,
    bool? isArchived,
    bool? isDeleted,
    String? Function()? folderId,
    String? Function()? tagId,
    String? Function()? documentType,
    DocumentSortOption? sortOption,
    int? limit,
    int? offset,
  }) {
    return DocumentQueryFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      isFavorite: isFavorite != null ? isFavorite() : this.isFavorite,
      isPrivate: isPrivate != null ? isPrivate() : this.isPrivate,
      isArchived: isArchived ?? this.isArchived,
      isDeleted: isDeleted ?? this.isDeleted,
      folderId: folderId != null ? folderId() : this.folderId,
      tagId: tagId != null ? tagId() : this.tagId,
      documentType: documentType != null ? documentType() : this.documentType,
      sortOption: sortOption ?? this.sortOption,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
    );
  }

  @override
  List<Object?> get props => [
    searchQuery,
    isFavorite,
    isPrivate,
    isArchived,
    isDeleted,
    folderId,
    tagId,
    documentType,
    sortOption,
    limit,
    offset,
  ];
}
