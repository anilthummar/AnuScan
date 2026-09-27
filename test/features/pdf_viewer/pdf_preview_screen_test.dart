import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:anuscan/core/di/injection.dart';
import 'package:anuscan/core/services/pdf_generator_service.dart';
import 'package:anuscan/core/utils/result.dart';
import 'package:anuscan/features/document_editor/domain/entities/scanned_page.dart';
import 'package:anuscan/features/document_history/domain/entities/document_entity.dart';
import 'package:anuscan/features/document_history/domain/usecases/document_usecases.dart';
import 'package:anuscan/features/pdf_viewer/domain/usecases/delete_pdf_usecase.dart';
import 'package:anuscan/features/pdf_viewer/domain/usecases/generate_pdf_usecase.dart';
import 'package:anuscan/features/pdf_viewer/domain/usecases/rename_pdf_usecase.dart';
import 'package:anuscan/features/pdf_viewer/domain/usecases/share_pdf_usecase.dart';
import 'package:anuscan/features/pdf_viewer/presentation/screens/pdf_preview_screen.dart';
import 'package:anuscan/features/smart_document/domain/entities/document_classification.dart';
import 'package:anuscan/features/smart_document/domain/entities/document_metadata.dart';
import 'package:anuscan/features/smart_document/domain/entities/document_recognition_result.dart';
import 'package:anuscan/features/smart_document/domain/repositories/document_recognition_repository.dart';
import 'package:anuscan/features/smart_document/domain/usecases/smart_document_usecases.dart';
import 'package:anuscan/features/smart_document/presentation/cubit/smart_document_cubit.dart';

class MockGeneratePdfUseCase extends Mock implements GeneratePdfUseCase {}

class MockSharePdfUseCase extends Mock implements SharePdfUseCase {}

class MockSaveDocumentUseCase extends Mock implements SaveDocumentUseCase {}

class MockRenamePdfUseCase extends Mock implements RenamePdfUseCase {}

class MockDeletePdfUseCase extends Mock implements DeletePdfUseCase {}

class FakeDocumentRecognitionRepository
    implements DocumentRecognitionRepository {
  @override
  Future<Result<DocumentRecognitionResult>> recognizeDocument({
    required String documentId,
    required List<ScannedPage> pages,
    bool force = false,
  }) async {
    return Result.success(
      DocumentRecognitionResult(
        documentId: documentId,
        classification: const DocumentClassification(
          type: DocumentType.invoice,
          confidence: 0.9,
        ),
        metadata: const DocumentMetadata(
          companyName: 'Acme Corp',
          invoiceNumber: 'INV-101',
        ),
        suggestedFilename: 'Acme Corp - Invoice - INV-101',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<Result<DocumentRecognitionResult?>> getRecognition(
    String documentId,
  ) async => Result.success(null);

  @override
  Future<Result<void>> saveRecognition(
    DocumentRecognitionResult result,
  ) async => Result.success(null);

  @override
  Future<Result<void>> updateManualClassification({
    required String documentId,
    required DocumentType manualType,
  }) async => Result.success(null);

  @override
  Future<Result<void>> updateManualMetadata({
    required String documentId,
    required DocumentMetadata updatedMetadata,
  }) async => Result.success(null);

  @override
  Future<Result<void>> deleteRecognition(String documentId) async =>
      Result.success(null);

  @override
  Future<Result<String>> suggestFilename({
    required DocumentClassification classification,
    required DocumentMetadata metadata,
    String? fallbackName,
  }) async => Result.success('Suggested');
}

void main() {
  late MockGeneratePdfUseCase mockGenerate;
  late MockSharePdfUseCase mockShare;
  late MockSaveDocumentUseCase mockSave;
  late MockRenamePdfUseCase mockRename;
  late MockDeletePdfUseCase mockDelete;
  late Directory testDir;
  late File samplePdfFile;

  final samplePages = [
    ScannedPage(
      id: 'p1',
      documentId: 'doc-101',
      pageIndex: 0,
      originalImagePath: '/tmp/p1.jpg',
      processedImagePath: '/tmp/p1_proc.jpg',
      createdAt: DateTime(2026, 1, 1),
    ),
  ];

  setUpAll(() {
    registerFallbackValue(PdfPageSizeOption.a4);
    registerFallbackValue(
      DocumentEntity(
        id: 'doc-fallback',
        title: 'Fallback',
        pdfPath: '/fallback.pdf',
        pageCount: 1,
        fileSizeBytes: 100,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        pages: const [],
      ),
    );
  });

  setUp(() async {
    testDir = await Directory.systemTemp.createTemp('screen_test_');
    samplePdfFile = File('${testDir.path}/test.pdf');
    await samplePdfFile.writeAsString('%PDF-1.4 sample content');

    mockGenerate = MockGeneratePdfUseCase();
    mockShare = MockSharePdfUseCase();
    mockSave = MockSaveDocumentUseCase();
    mockRename = MockRenamePdfUseCase();
    mockDelete = MockDeletePdfUseCase();

    when(
      () => mockGenerate(
        documentId: any(named: 'documentId'),
        title: any(named: 'title'),
        pages: any(named: 'pages'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer(
      (_) async => (
        pdfPath: samplePdfFile.path,
        thumbnailPath: '/tmp/thumb.jpg',
        fileSizeBytes: 1024,
      ),
    );

    when(() => mockSave(any())).thenAnswer((_) async {});
    when(
      () => mockShare(any(), title: any(named: 'title')),
    ).thenAnswer((_) async => const Result.success(null));
    when(
      () => mockShare.openExternal(any()),
    ).thenAnswer((_) async => const Result.success(null));
    when(
      () => mockDelete(
        documentId: any(named: 'documentId'),
        pdfPath: any(named: 'pdfPath'),
      ),
    ).thenAnswer((_) async => const Result.success(null));

    await sl.reset();
    sl.registerSingleton<GeneratePdfUseCase>(mockGenerate);
    sl.registerSingleton<SharePdfUseCase>(mockShare);
    sl.registerSingleton<SaveDocumentUseCase>(mockSave);
    sl.registerSingleton<RenamePdfUseCase>(mockRename);
    sl.registerSingleton<DeletePdfUseCase>(mockDelete);

    final mockSmartRepo = FakeDocumentRecognitionRepository();
    sl.registerSingleton<RecognizeDocumentUseCase>(
      RecognizeDocumentUseCase(mockSmartRepo),
    );
    sl.registerSingleton<GetDocumentRecognitionUseCase>(
      GetDocumentRecognitionUseCase(mockSmartRepo),
    );
    sl.registerSingleton<OverrideDocumentTypeUseCase>(
      OverrideDocumentTypeUseCase(mockSmartRepo),
    );
    sl.registerSingleton<UpdateDocumentMetadataUseCase>(
      UpdateDocumentMetadataUseCase(mockSmartRepo),
    );
    sl.registerSingleton<SuggestDocumentNameUseCase>(
      SuggestDocumentNameUseCase(mockSmartRepo),
    );
    sl.registerFactory<SmartDocumentCubit>(
      () => SmartDocumentCubit(
        recognizeDocumentUseCase: sl<RecognizeDocumentUseCase>(),
        getDocumentRecognitionUseCase: sl<GetDocumentRecognitionUseCase>(),
        overrideDocumentTypeUseCase: sl<OverrideDocumentTypeUseCase>(),
        updateDocumentMetadataUseCase: sl<UpdateDocumentMetadataUseCase>(),
        suggestDocumentNameUseCase: sl<SuggestDocumentNameUseCase>(),
      ),
    );
  });

  tearDown(() async {
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  testWidgets('PdfPreviewScreen renders actions and controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PdfPreviewScreen(
          documentId: 'doc-101',
          title: 'Invoice 2026',
          pages: samplePages,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify title and buttons
    expect(find.text('Invoice 2026'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    expect(find.byIcon(Icons.share), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.byIcon(Icons.check), findsAtLeastNWidgets(1));

    // Verify bottom info
    expect(find.textContaining('1 Pages'), findsOneWidget);
  });

  testWidgets('tapping document title opens Rename dialog', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PdfPreviewScreen(
          documentId: 'doc-101',
          title: 'Invoice 2026',
          pages: samplePages,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Tap title
    await tester.tap(find.text('Invoice 2026'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Rename PDF'), findsOneWidget);
    expect(find.text('Enter new filename'), findsOneWidget);
    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('tapping delete icon opens Delete confirmation dialog', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PdfPreviewScreen(
          documentId: 'doc-101',
          title: 'Invoice 2026',
          pages: samplePages,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Tap delete button
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Delete Document'), findsOneWidget);
    expect(
      find.text(
        'Are you sure you want to permanently delete this document and all its scanned pages? This action cannot be undone.',
      ),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });
}
