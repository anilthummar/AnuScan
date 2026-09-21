import '../entities/scanned_page.dart';

/// Use case for reordering pages in a multi-page document.
class ReorderPagesUseCase {
  const ReorderPagesUseCase();

  List<ScannedPage> call({
    required List<ScannedPage> pages,
    required int oldIndex,
    required int newIndex,
  }) {
    final updated = List<ScannedPage>.from(pages);
    var targetIndex = newIndex;
    if (oldIndex < targetIndex) {
      targetIndex -= 1;
    }
    final item = updated.removeAt(oldIndex);
    updated.insert(targetIndex, item);

    // Re-index all pages
    return [
      for (int i = 0; i < updated.length; i++) updated[i].copyWith(pageIndex: i),
    ];
  }
}
