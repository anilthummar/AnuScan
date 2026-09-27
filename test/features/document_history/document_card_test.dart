import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anuscan/core/utils/date_formatter.dart';
import 'package:anuscan/core/utils/file_utils.dart';
import 'package:anuscan/features/document_history/domain/entities/document_entity.dart';
import 'package:anuscan/features/document_history/presentation/widgets/document_card.dart';

void main() {
  final testDate = DateTime(2026, 9, 21, 14, 30);
  final testDocument = DocumentEntity(
    id: 'doc_1',
    title: 'Passport Scan',
    pdfPath: '/path/to/doc.pdf',
    pageCount: 3,
    fileSizeBytes: 1048576, // 1.0 MB
    createdAt: testDate,
    updatedAt: testDate,
    thumbnailPath: null,
    pages: const [],
  );

  Widget buildTestWidget({
    required DocumentEntity document,
    VoidCallback? onTap,
    VoidCallback? onOpen,
    VoidCallback? onShare,
    VoidCallback? onRename,
    VoidCallback? onDelete,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: DocumentCard(
          document: document,
          onTap: onTap ?? () {},
          onOpen: onOpen,
          onShare: onShare ?? () {},
          onRename: onRename ?? () {},
          onDelete: onDelete ?? () {},
        ),
      ),
    );
  }

  testWidgets('renders all 5 required metadata fields', (tester) async {
    await tester.pumpWidget(buildTestWidget(document: testDocument));

    // 1. Document Name
    expect(find.text('Passport Scan'), findsOneWidget);

    // 2. Page Count
    expect(find.text('3 pages'), findsOneWidget);

    // 3. Created Date
    final expectedDateStr =
        'Created: ${DateFormatter.formatDateTime(testDate)}';
    expect(find.text(expectedDateStr), findsOneWidget);

    // 4. PDF Size
    final expectedSizeStr = FileUtils.formatBytes(testDocument.fileSizeBytes);
    expect(find.text(expectedSizeStr), findsOneWidget);

    // 5. Thumbnail / Fallback PDF Icon
    expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
  });

  testWidgets('renders single page count format correctly', (tester) async {
    final singlePageDoc = testDocument.copyWith(pageCount: 1);
    await tester.pumpWidget(buildTestWidget(document: singlePageDoc));

    expect(find.text('1 page'), findsOneWidget);
  });

  testWidgets('triggers onTap / onOpen when card body is tapped', (
    tester,
  ) async {
    bool tapped = false;
    await tester.pumpWidget(
      buildTestWidget(document: testDocument, onTap: () => tapped = true),
    );

    await tester.tap(find.text('Passport Scan'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('triggers onOpen when Open menu option is selected', (
    tester,
  ) async {
    bool opened = false;
    await tester.pumpWidget(
      buildTestWidget(document: testDocument, onOpen: () => opened = true),
    );

    // Open popup menu
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    // Tap 'Open'
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(opened, isTrue);
  });

  testWidgets('triggers onRename when Rename menu option is selected', (
    tester,
  ) async {
    bool renamed = false;
    await tester.pumpWidget(
      buildTestWidget(document: testDocument, onRename: () => renamed = true),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    expect(renamed, isTrue);
  });

  testWidgets('triggers onShare when Share PDF menu option is selected', (
    tester,
  ) async {
    bool shared = false;
    await tester.pumpWidget(
      buildTestWidget(document: testDocument, onShare: () => shared = true),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Share PDF'));
    await tester.pumpAndSettle();

    expect(shared, isTrue);
  });

  testWidgets('triggers onDelete when Delete menu option is selected', (
    tester,
  ) async {
    bool deleted = false;
    await tester.pumpWidget(
      buildTestWidget(document: testDocument, onDelete: () => deleted = true),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
  });
}
