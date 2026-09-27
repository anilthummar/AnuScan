import 'package:equatable/equatable.dart';

/// Aggregated document counts for top-level tabs, folders, and tags (computed without N+1 queries).
class DocumentCounts extends Equatable {
  const DocumentCounts({
    this.activeCount = 0,
    this.favoriteCount = 0,
    this.archivedCount = 0,
    this.trashCount = 0,
    this.privateCount = 0,
    this.folderCounts = const {},
    this.tagCounts = const {},
    this.typeCounts = const {},
  });

  final int activeCount;
  final int favoriteCount;
  final int archivedCount;
  final int trashCount;
  final int privateCount;
  final Map<String, int> folderCounts;
  final Map<String, int> tagCounts;
  final Map<String, int> typeCounts;

  @override
  List<Object?> get props => [
    activeCount,
    favoriteCount,
    archivedCount,
    trashCount,
    privateCount,
    folderCounts,
    tagCounts,
    typeCounts,
  ];
}
