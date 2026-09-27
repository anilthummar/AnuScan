import 'dart:io';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:anuscan/core/errors/failures.dart';
import 'package:anuscan/core/services/pdf_generator_service.dart';
import 'package:anuscan/core/utils/result.dart';
import 'package:anuscan/features/document_editor/domain/entities/document_session.dart';
import 'package:anuscan/features/document_editor/domain/entities/scanned_page.dart';
import 'package:anuscan/features/pdf_viewer/domain/usecases/generate_pdf_usecase.dart';
import 'package:anuscan/features/pdf_viewer/presentation/cubit/pdf_cubit.dart';
import 'package:anuscan/features/pdf_viewer/presentation/cubit/pdf_state.dart';

class MockGeneratePdfUseCase extends Mock implements GeneratePdfUseCase {}

class FakeDocumentSession extends Fake implements DocumentSession {}

void main() {
  late MockGeneratePdfUseCase mockUseCase;
  late PdfCubit cubit;
  late File samplePdf;

  setUpAll(() {
    registerFallbackValue(FakeDocumentSession());
    registerFallbackValue(PdfPageSizeOption.a4);
    registerFallbackValue(PdfQualityOption.standard);
  });

  setUp(() async {
    mockUseCase = MockGeneratePdfUseCase();
    cubit = PdfCubit(generatePdfUseCase: mockUseCase);

    final tempDir = await Directory.systemTemp.createTemp(
      'anuscan_pdf_cubit_test_',
    );
    samplePdf = File('${tempDir.path}/out.pdf');
    await samplePdf.writeAsBytes([1, 2, 3, 4, 5]);
  });

  tearDown(() async {
    await cubit.close();
    if (await samplePdf.parent.exists()) {
      await samplePdf.parent.delete(recursive: true);
    }
  });

  test('initial state is PdfInitial', () {
    expect(cubit.state, equals(const PdfInitial()));
  });

  final testSession = DocumentSession(
    id: 's1',
    name: 'Tax 2026',
    createdAt: DateTime(2026, 3, 22),
    updatedAt: DateTime(2026, 3, 22),
    pages: [
      DocumentSessionPage(
        id: 'p1',
        imagePath: '/tmp/p1.jpg',
        order: 0,
        createdAt: DateTime(2026, 3, 22),
      ),
      DocumentSessionPage(
        id: 'p2',
        imagePath: '/tmp/p2.jpg',
        order: 1,
        createdAt: DateTime(2026, 3, 22),
      ),
    ],
  );

  blocTest<PdfCubit, PdfState>(
    'emits [PdfGenerating, PdfSuccess] when generatePdfFromSession succeeds',
    build: () {
      when(
        () => mockUseCase.fromSession(
          session: any(named: 'session'),
          pageSize: any(named: 'pageSize'),
          quality: any(named: 'quality'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((invocation) async {
        final onProgress =
            invocation.namedArguments[#onProgress] as PdfProgressCallback?;
        onProgress?.call(0.5, 1, 2);
        onProgress?.call(1.0, 2, 2);
        return Result.success(samplePdf.path);
      });
      return cubit;
    },
    act: (c) => c.generatePdfFromSession(
      session: testSession,
      pageSize: PdfPageSizeOption.a4,
      quality: PdfQualityOption.standard,
    ),
    expect: () => [
      const PdfGenerating(
        progress: 0.0,
        currentPage: 0,
        totalPages: 2,
        message: 'Initializing PDF generation...',
      ),
      const PdfGenerating(
        progress: 0.5,
        currentPage: 1,
        totalPages: 2,
        message: 'Generating page 1 of 2...',
      ),
      const PdfGenerating(
        progress: 1.0,
        currentPage: 2,
        totalPages: 2,
        message: 'Generating page 2 of 2...',
      ),
      PdfSuccess(
        pdfPath: samplePdf.path,
        fileSizeBytes: 5,
        pageCount: 2,
        pageSize: PdfPageSizeOption.a4,
        quality: PdfQualityOption.standard,
      ),
    ],
  );

  blocTest<PdfCubit, PdfState>(
    'emits [PdfGenerating, PdfFailureState] when generatePdfFromSession fails',
    build: () {
      when(
        () => mockUseCase.fromSession(
          session: any(named: 'session'),
          pageSize: any(named: 'pageSize'),
          quality: any(named: 'quality'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer(
        (_) async =>
            const Result.failure(PdfGenerationFailure('Storage failure')),
      );
      return cubit;
    },
    act: (c) => c.generatePdfFromSession(session: testSession),
    expect: () => [
      const PdfGenerating(
        progress: 0.0,
        currentPage: 0,
        totalPages: 2,
        message: 'Initializing PDF generation...',
      ),
      const PdfFailureState('Storage failure'),
    ],
  );

  blocTest<PdfCubit, PdfState>(
    'emits [PdfGenerating, PdfSuccess] when generatePdfFromPages succeeds',
    build: () {
      when(
        () => mockUseCase.fromPages(
          documentId: any(named: 'documentId'),
          title: any(named: 'title'),
          pages: any(named: 'pages'),
          pageSize: any(named: 'pageSize'),
          quality: any(named: 'quality'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((_) async => Result.success(samplePdf.path));
      return cubit;
    },
    act: (c) => c.generatePdfFromPages(
      documentId: 'doc_1',
      title: 'Invoice',
      pages: [
        ScanPage(
          id: 'p1',
          documentId: 'doc_1',
          pageIndex: 0,
          originalImagePath: '/p1.jpg',
          processedImagePath: '/p1.jpg',
          createdAt: DateTime.now(),
        ),
      ],
    ),
    expect: () => [
      const PdfGenerating(
        progress: 0.0,
        currentPage: 0,
        totalPages: 1,
        message: 'Initializing PDF generation...',
      ),
      PdfSuccess(
        pdfPath: samplePdf.path,
        fileSizeBytes: 5,
        pageCount: 1,
        pageSize: PdfPageSizeOption.a4,
        quality: PdfQualityOption.standard,
      ),
    ],
  );

  test('reset returns state to PdfInitial', () {
    cubit.reset();
    expect(cubit.state, equals(const PdfInitial()));
  });
}
