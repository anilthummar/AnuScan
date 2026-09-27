import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:anuscan/core/routes/app_routes.dart';
import 'package:anuscan/core/routes/app_router.dart';
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

    cubit = DocumentEditorCubit(
      fileStorageService: mockStorage,
      imageProcessingService: mockImageService,
      processPageUseCase: mockProcessPage,
      reorderPagesUseCase: const ReorderPagesUseCase(),
      documentId: 'doc_nav_1',
      initialTitle: 'Export Test Doc',
    );
  });

  tearDown(() {
    cubit.close();
  });

  testWidgets('shows SnackBar warning when attempting to export with 0 pages', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DocumentEditorScreen(
          documentId: 'doc_nav_1',
          initialTitle: 'Export Test Doc',
          initialImagePaths: const [],
          customCubit: cubit,
        ),
      ),
    );

    // Tap bottom Review & Export PDF button
    await tester.tap(find.text('Review & Export PDF'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('Please add at least one page to export PDF.'),
      findsOneWidget,
    );
  });

  testWidgets('navigates to AppRoutes.pdfPreview when pages are present', (
    tester,
  ) async {
    final testPage = ScannedPage(
      id: 'p1',
      documentId: 'doc_nav_1',
      pageIndex: 0,
      originalImagePath: '/path/to/orig.jpg',
      processedImagePath: '/path/to/proc.jpg',
      createdAt: DateTime.now(),
    );

    // Seed page into cubit state
    cubit.emit(cubit.state.copyWith(pages: [testPage]));

    dynamic capturedArguments;

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.pdfPreview) {
            capturedArguments = settings.arguments;
            return MaterialPageRoute(
              builder: (_) =>
                  const Scaffold(body: Text('PDF Preview Mock Screen')),
            );
          }
          return null;
        },
        home: DocumentEditorScreen(
          documentId: 'doc_nav_1',
          initialTitle: 'Export Test Doc',
          initialImagePaths: const [],
          customCubit: cubit,
        ),
      ),
    );

    // Tap Review & Export PDF
    await tester.tap(find.text('Review & Export PDF'));
    await tester.pumpAndSettle();

    expect(find.text('PDF Preview Mock Screen'), findsOneWidget);
    expect(capturedArguments, isA<PdfPreviewArgs>());
    final args = capturedArguments as PdfPreviewArgs;
    expect(args.documentId, equals('doc_nav_1'));
    expect(args.title, equals('Export Test Doc'));
    expect(args.pages.length, equals(1));
  });
}
