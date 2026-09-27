import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:anuscan/core/di/injection.dart';
import 'package:anuscan/core/services/share_service.dart';
import 'package:anuscan/features/document_history/domain/entities/document_entity.dart';
import 'package:anuscan/features/document_history/domain/usecases/document_usecases.dart';
import 'package:anuscan/features/document_history/presentation/cubit/document_history_cubit.dart';
import 'package:anuscan/features/document_history/presentation/screens/home_screen.dart';
import 'package:anuscan/features/document_history/presentation/widgets/empty_state_view.dart';
import 'package:anuscan/features/document_history/presentation/widgets/document_card.dart';

class MockGetDocumentsUseCase extends Mock implements GetDocumentsUseCase {}

class MockDeleteDocumentUseCase extends Mock implements DeleteDocumentUseCase {}

class MockRenameDocumentUseCase extends Mock implements RenameDocumentUseCase {}

class MockSearchDocumentsUseCase extends Mock
    implements SearchDocumentsUseCase {}

class MockShareService extends Mock implements ShareService {}

void main() {
  late MockGetDocumentsUseCase mockGetDocuments;
  late MockDeleteDocumentUseCase mockDeleteDocument;
  late MockRenameDocumentUseCase mockRenameDocument;
  late MockSearchDocumentsUseCase mockSearchDocuments;
  late MockShareService mockShareService;

  final now = DateTime(2026, 9, 21, 10, 0);
  final testDoc1 = DocumentEntity(
    id: 'doc_1',
    title: 'Passport Scan',
    pdfPath: '/path/to/doc1.pdf',
    pageCount: 2,
    fileSizeBytes: 204800,
    createdAt: now,
    updatedAt: now,
    pages: const [],
  );

  final testDoc2 = DocumentEntity(
    id: 'doc_2',
    title: 'Work Contract',
    pdfPath: '/path/to/doc2.pdf',
    pageCount: 5,
    fileSizeBytes: 512000,
    createdAt: now,
    updatedAt: now,
    pages: const [],
  );

  setUp(() async {
    await sl.reset();
    mockGetDocuments = MockGetDocumentsUseCase();
    mockDeleteDocument = MockDeleteDocumentUseCase();
    mockRenameDocument = MockRenameDocumentUseCase();
    mockSearchDocuments = MockSearchDocumentsUseCase();
    mockShareService = MockShareService();

    sl.registerSingleton<ShareService>(mockShareService);
  });

  Widget buildTestWidget({required DocumentHistoryCubit cubit}) {
    return MaterialApp(
      home: BlocProvider<DocumentHistoryCubit>.value(
        value: cubit,
        child: const HomeScreen(),
      ),
    );
  }

  testWidgets('renders EmptyStateView when document history is empty', (
    tester,
  ) async {
    when(() => mockGetDocuments()).thenAnswer((_) async => []);

    final cubit = DocumentHistoryCubit(
      getDocumentsUseCase: mockGetDocuments,
      deleteDocumentUseCase: mockDeleteDocument,
      renameDocumentUseCase: mockRenameDocument,
      searchDocumentsUseCase: mockSearchDocuments,
    );

    await tester.pumpWidget(buildTestWidget(cubit: cubit));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyStateView), findsOneWidget);
    expect(find.text('No Documents Yet'), findsOneWidget);
    expect(find.text('Scan Now'), findsOneWidget);
  });

  testWidgets(
    'renders Recent Documents section and DocumentCards when history has items',
    (tester) async {
      when(
        () => mockGetDocuments(),
      ).thenAnswer((_) async => [testDoc1, testDoc2]);

      final cubit = DocumentHistoryCubit(
        getDocumentsUseCase: mockGetDocuments,
        deleteDocumentUseCase: mockDeleteDocument,
        renameDocumentUseCase: mockRenameDocument,
        searchDocumentsUseCase: mockSearchDocuments,
      );

      await tester.pumpWidget(buildTestWidget(cubit: cubit));
      await tester.pumpAndSettle();

      // Section header
      expect(find.text('Recent Documents'), findsOneWidget);
      expect(find.text('2 files'), findsOneWidget);

      // Document cards
      expect(find.byType(DocumentCard), findsNWidgets(2));
      expect(find.text('Passport Scan'), findsOneWidget);
      expect(find.text('Work Contract'), findsOneWidget);
    },
  );

  testWidgets('search bar toggles and performs search on query input', (
    tester,
  ) async {
    when(
      () => mockGetDocuments(),
    ).thenAnswer((_) async => [testDoc1, testDoc2]);
    when(
      () => mockSearchDocuments('Contract'),
    ).thenAnswer((_) async => [testDoc2]);

    final cubit = DocumentHistoryCubit(
      getDocumentsUseCase: mockGetDocuments,
      deleteDocumentUseCase: mockDeleteDocument,
      renameDocumentUseCase: mockRenameDocument,
      searchDocumentsUseCase: mockSearchDocuments,
    );

    await tester.pumpWidget(buildTestWidget(cubit: cubit));
    await tester.pumpAndSettle();

    // Tap search icon
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    // Verify search field appears
    expect(find.byType(TextField), findsOneWidget);

    // Enter search query
    await tester.enterText(find.byType(TextField), 'Contract');
    await tester.pumpAndSettle();

    expect(find.text('Search Results (1)'), findsOneWidget);
    expect(find.text('Work Contract'), findsOneWidget);
    expect(find.text('Passport Scan'), findsNothing);
  });

  testWidgets('shows rename dialog and calls cubit when confirmed', (
    tester,
  ) async {
    when(() => mockGetDocuments()).thenAnswer((_) async => [testDoc1]);
    when(
      () => mockRenameDocument('doc_1', 'New Passport'),
    ).thenAnswer((_) async {});

    final cubit = DocumentHistoryCubit(
      getDocumentsUseCase: mockGetDocuments,
      deleteDocumentUseCase: mockDeleteDocument,
      renameDocumentUseCase: mockRenameDocument,
      searchDocumentsUseCase: mockSearchDocuments,
    );

    await tester.pumpWidget(buildTestWidget(cubit: cubit));
    await tester.pumpAndSettle();

    // Open popup menu on document card
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    // Tap Rename
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    // Verify dialog appears
    expect(find.text('Rename Document'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);

    // Clear and enter new text
    final textField = find.byType(TextField);
    await tester.enterText(textField, 'New Passport');
    await tester.pumpAndSettle();

    // Tap Rename button in dialog
    await tester.tap(find.widgetWithText(ElevatedButton, 'Rename'));
    await tester.pumpAndSettle();

    verify(() => mockRenameDocument('doc_1', 'New Passport')).called(1);
  });

  testWidgets('shows delete confirmation dialog and calls cubit when confirmed', (
    tester,
  ) async {
    when(() => mockGetDocuments()).thenAnswer((_) async => [testDoc1]);
    when(() => mockDeleteDocument('doc_1')).thenAnswer((_) async {});

    final cubit = DocumentHistoryCubit(
      getDocumentsUseCase: mockGetDocuments,
      deleteDocumentUseCase: mockDeleteDocument,
      renameDocumentUseCase: mockRenameDocument,
      searchDocumentsUseCase: mockSearchDocuments,
    );

    await tester.pumpWidget(buildTestWidget(cubit: cubit));
    await tester.pumpAndSettle();

    // Open popup menu on document card
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    // Tap Delete
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Verify dialog appears
    expect(find.text('Delete Document'), findsOneWidget);
    expect(
      find.text(
        'Are you sure you want to delete "Passport Scan"? This cannot be undone.',
      ),
      findsOneWidget,
    );

    // Tap Delete button in dialog
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();

    verify(() => mockDeleteDocument('doc_1')).called(1);
  });
}
