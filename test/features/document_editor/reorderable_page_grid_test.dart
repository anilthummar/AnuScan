import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anuscan/features/document_editor/domain/entities/scanned_page.dart';
import 'package:anuscan/features/document_editor/presentation/widgets/reorderable_page_grid.dart';

void main() {
  final testPage1 = ScannedPage(
    id: 'p1',
    documentId: 'doc_1',
    pageIndex: 0,
    originalImagePath: '/tmp/orig1.jpg',
    processedImagePath: '/tmp/proc1.jpg',
    createdAt: DateTime(2026, 3, 22),
  );

  final testPage2 = ScannedPage(
    id: 'p2',
    documentId: 'doc_1',
    pageIndex: 1,
    originalImagePath: '/tmp/orig2.jpg',
    processedImagePath: '/tmp/proc2.jpg',
    rotationDegrees: 90,
    createdAt: DateTime(2026, 3, 22),
  );

  testWidgets('renders empty state when pages list is empty', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReorderablePageGrid(
            pages: const [],
            onReorder: (_, __) {},
            onTapPage: (_) {},
            onRotatePage: (_) {},
            onDeletePage: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('No pages in this document yet'), findsOneWidget);
    expect(
      find.text('Tap the buttons below to scan or import pages'),
      findsOneWidget,
    );
  });

  testWidgets(
    'renders page cards with [ Page X ] titles, badges, and filters',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReorderablePageGrid(
              pages: [testPage1, testPage2],
              onReorder: (_, __) {},
              onTapPage: (_) {},
              onRotatePage: (_) {},
              onDeletePage: (_) {},
            ),
          ),
        ),
      );

      // Page titles matching [ Page 1 ] [ Page 2 ] specification
      expect(find.text('[ Page 1 ]'), findsOneWidget);
      expect(find.text('[ Page 2 ]'), findsOneWidget);

      // Page badges
      expect(find.text('Page 1'), findsOneWidget);
      expect(find.text('Page 2'), findsOneWidget);

      // Filter indicator
      expect(find.text('Filter: Original'), findsNWidgets(2));

      // Rotation indicator on page 2
      expect(find.text('Rotated: 90°'), findsOneWidget);
    },
  );

  testWidgets('tapping actions triggers callbacks with correct indices', (
    tester,
  ) async {
    int? tappedIndex;
    int? rotatedIndex;
    int? deletedIndex;
    int? duplicatedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReorderablePageGrid(
            pages: [testPage1, testPage2],
            onReorder: (_, __) {},
            onTapPage: (idx) => tappedIndex = idx,
            onRotatePage: (idx) => rotatedIndex = idx,
            onDeletePage: (idx) => deletedIndex = idx,
            onDuplicatePage: (idx) => duplicatedIndex = idx,
          ),
        ),
      ),
    );

    // Tap on Edit Page button on first card
    final editButtons = find.byTooltip('Edit Page');
    expect(editButtons, findsNWidgets(2));
    await tester.tap(editButtons.first);
    expect(tappedIndex, equals(0));

    // Tap on Duplicate Page button on first card
    final duplicateButtons = find.byTooltip('Duplicate Page');
    expect(duplicateButtons, findsNWidgets(2));
    await tester.tap(duplicateButtons.first);
    expect(duplicatedIndex, equals(0));

    // Tap on Rotate 90° button on second card
    final rotateButtons = find.byTooltip('Rotate 90°');
    expect(rotateButtons, findsNWidgets(2));
    await tester.tap(rotateButtons.at(1));
    expect(rotatedIndex, equals(1));

    // Tap on Delete Page button on second card
    final deleteButtons = find.byTooltip('Delete Page');
    expect(deleteButtons, findsNWidgets(2));
    await tester.tap(deleteButtons.at(1));
    expect(deletedIndex, equals(1));
  });
}
