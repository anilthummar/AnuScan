import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:anuscan/core/services/file_storage_service.dart';
import 'package:anuscan/core/services/image_processing_service.dart';
import 'package:anuscan/features/document_editor/domain/entities/scanned_page.dart';
import 'package:anuscan/features/document_editor/domain/usecases/process_page_usecase.dart';
import 'package:anuscan/features/document_editor/domain/usecases/reorder_pages_usecase.dart';
import 'package:anuscan/features/document_editor/presentation/cubit/document_editor_cubit.dart';
import 'package:anuscan/features/document_editor/presentation/screens/document_editor_screen.dart';

class MockFileStorageService extends Mock implements FileStorageService {}

class MockImageProcessingService extends Mock
    implements ImageProcessingService {}

class MockProcessPageUseCase extends Mock implements ProcessPageUseCase {}

void main() {
  late MockFileStorageService mockStorage;
  late MockImageProcessingService mockImageService;
  late MockProcessPageUseCase mockProcessPage;
  late DocumentEditorCubit cubit;

  setUp(() {
    mockStorage = MockFileStorageService();
    mockImageService = MockImageProcessingService();
    mockProcessPage = MockProcessPageUseCase();

    when(
      () => mockStorage.copyImageFile(
        any(),
        any(),
        filename: any(named: 'filename'),
      ),
    ).thenAnswer(
      (invocation) async =>
          '/app_storage/doc_1/${invocation.namedArguments[#filename]}',
    );

    when(
      () => mockImageService.getImageDimensions(any()),
    ).thenAnswer((_) async => (1080, 1920));

    cubit = DocumentEditorCubit(
      fileStorageService: mockStorage,
      imageProcessingService: mockImageService,
      processPageUseCase: mockProcessPage,
      reorderPagesUseCase: const ReorderPagesUseCase(),
      documentId: 'doc_1',
      initialTitle: 'Quarterly Invoices',
    );
  });

  tearDown(() {
    cubit.close();
  });

  Widget buildTestableWidget() {
    return MaterialApp(
      home: DocumentEditorScreen(
        documentId: 'doc_1',
        initialTitle: 'Quarterly Invoices',
        initialImagePaths: const [],
        customCubit: cubit,
      ),
    );
  }

  testWidgets(
    'renders document title, page count badge, and empty list message',
    (tester) async {
      await tester.pumpWidget(buildTestableWidget());

      expect(find.text('Quarterly Invoices'), findsOneWidget);
      expect(
        find.text('0 Pages'),
        findsNWidgets(2),
      ); // AppBar and status banner
      expect(find.text('No pages in this document yet'), findsOneWidget);
      expect(find.text('Add Gallery'), findsOneWidget);
      expect(find.text('Scan Camera'), findsOneWidget);
    },
  );

  testWidgets('tapping document title opens rename dialog and updates title', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestableWidget());

    // Tap title
    await tester.tap(find.text('Quarterly Invoices'));
    await tester.pumpAndSettle();

    expect(find.text('Rename Document'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // Enter new title
    await tester.enterText(find.byType(TextField), 'Tax Documents 2026');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Tax Documents 2026'), findsOneWidget);
    expect(cubit.state.title, equals('Tax Documents 2026'));
  });

  testWidgets(
    'tapping Add Another Page button opens bottom sheet with Camera and Gallery',
    (tester) async {
      await tester.pumpWidget(buildTestableWidget());

      // Tap the filled Add icon button in the bottom bar
      final addButtons = find.byTooltip('Add Another Page');
      expect(addButtons, findsNWidgets(2)); // AppBar and bottom bar
      await tester.tap(addButtons.first);
      await tester.pumpAndSettle();

      // Verify modal sheet options
      expect(find.text('Add Another Page'), findsOneWidget);
      expect(find.text('Scan with Camera'), findsOneWidget);
      expect(find.text('Import from Gallery'), findsOneWidget);
    },
  );

  testWidgets(
    'displays pages, cards with [ Page X ], and delete confirmation dialog',
    (tester) async {
      cubit.addPages([
        ScannedPage(
          id: 'p1',
          documentId: 'doc_1',
          pageIndex: 0,
          originalImagePath: '/tmp/p1.jpg',
          processedImagePath: '/tmp/p1.jpg',
          createdAt: DateTime(2026, 3, 22),
        ),
        ScannedPage(
          id: 'p2',
          documentId: 'doc_1',
          pageIndex: 1,
          originalImagePath: '/tmp/p2.jpg',
          processedImagePath: '/tmp/p2.jpg',
          createdAt: DateTime(2026, 3, 22),
        ),
      ]);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('2 Pages'), findsNWidgets(2));
      expect(find.text('[ Page 1 ]'), findsOneWidget);
      expect(find.text('[ Page 2 ]'), findsOneWidget);

      // Tap delete on Page 1
      final deleteButtons = find.byTooltip('Delete Page');
      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('Delete Page'), findsOneWidget);
      expect(
        find.text('Are you sure you want to delete Page 1?'),
        findsOneWidget,
      );

      // Confirm deletion
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(cubit.state.pages.length, equals(1));
      expect(find.text('1 Page'), findsNWidgets(2));
    },
  );
}
