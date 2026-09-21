import 'package:flutter_test/flutter_test.dart';
import 'package:anuscan/features/document_editor/domain/entities/scanned_page.dart';
import 'package:anuscan/features/document_editor/domain/usecases/reorder_pages_usecase.dart';

void main() {
  late ReorderPagesUseCase useCase;

  setUp(() {
    useCase = const ReorderPagesUseCase();
  });

  ScannedPage createPage(String id, int index) {
    return ScannedPage(
      id: id,
      documentId: 'doc_1',
      pageIndex: index,
      originalImagePath: '/path/$id.jpg',
      processedImagePath: '/path/proc_$id.jpg',
      createdAt: DateTime.now(),
    );
  }

  test('reorders pages forward correctly and updates pageIndex', () {
    final pages = [
      createPage('p1', 0),
      createPage('p2', 1),
      createPage('p3', 2),
    ];

    // Move p1 (index 0) to index 2
    final result = useCase(pages: pages, oldIndex: 0, newIndex: 3);

    expect(result.map((p) => p.id).toList(), equals(['p2', 'p3', 'p1']));
    expect(result[0].pageIndex, equals(0));
    expect(result[1].pageIndex, equals(1));
    expect(result[2].pageIndex, equals(2));
  });

  test('reorders pages backward correctly and updates pageIndex', () {
    final pages = [
      createPage('p1', 0),
      createPage('p2', 1),
      createPage('p3', 2),
    ];

    // Move p3 (index 2) to index 0
    final result = useCase(pages: pages, oldIndex: 2, newIndex: 0);

    expect(result.map((p) => p.id).toList(), equals(['p3', 'p1', 'p2']));
    expect(result[0].pageIndex, equals(0));
    expect(result[1].pageIndex, equals(1));
    expect(result[2].pageIndex, equals(2));
  });
}
