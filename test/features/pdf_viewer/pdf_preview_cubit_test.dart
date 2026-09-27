import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:anuscan/core/services/pdf_generator_service.dart';
import 'package:anuscan/core/utils/result.dart';
import 'package:anuscan/features/document_editor/domain/entities/scanned_page.dart';
import 'package:anuscan/features/document_history/domain/entities/document_entity.dart';
import 'package:anuscan/features/document_history/domain/usecases/document_usecases.dart';
import 'package:anuscan/features/pdf_viewer/domain/usecases/delete_pdf_usecase.dart';
import 'package:anuscan/features/pdf_viewer/domain/usecases/generate_pdf_usecase.dart';
import 'package:anuscan/features/pdf_viewer/domain/usecases/rename_pdf_usecase.dart';
import 'package:anuscan/features/pdf_viewer/domain/usecases/share_pdf_usecase.dart';
import 'package:anuscan/features/pdf_viewer/presentation/cubit/pdf_preview_cubit.dart';

class MockGeneratePdfUseCase extends Mock implements GeneratePdfUseCase {}

class MockSharePdfUseCase extends Mock implements SharePdfUseCase {}

class MockSaveDocumentUseCase extends Mock implements SaveDocumentUseCase {}

class MockRenamePdfUseCase extends Mock implements RenamePdfUseCase {}

class MockDeletePdfUseCase extends Mock implements DeletePdfUseCase {}

void main() {
  late MockGeneratePdfUseCase mockGenerate;
  late MockSharePdfUseCase mockShare;
  late MockSaveDocumentUseCase mockSave;
  late MockRenamePdfUseCase mockRename;
  late MockDeletePdfUseCase mockDelete;
  late Directory testDir;

  final samplePages = [
    ScannedPage(
      id: 'p1',
      documentId: 'doc-123',
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
    mockGenerate = MockGeneratePdfUseCase();
    mockShare = MockSharePdfUseCase();
    mockSave = MockSaveDocumentUseCase();
    mockRename = MockRenamePdfUseCase();
    mockDelete = MockDeletePdfUseCase();
    testDir = await Directory.systemTemp.createTemp('preview_cubit_test_');
  });

  tearDown(() async {
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  PdfPreviewCubit createCubit({String title = 'Initial Title'}) {
    return PdfPreviewCubit(
      generatePdfUseCase: mockGenerate,
      sharePdfUseCase: mockShare,
      saveDocumentUseCase: mockSave,
      renamePdfUseCase: mockRename,
      deletePdfUseCase: mockDelete,
      pages: samplePages,
      documentId: 'doc-123',
      title: title,
    );
  }

  group('PdfPreviewCubit', () {
    test('initial state is correct', () {
      final cubit = createCubit();
      expect(cubit.state.documentId, 'doc-123');
      expect(cubit.state.title, 'Initial Title');
      expect(cubit.state.isGenerating, isFalse);
      expect(cubit.state.isSaved, isFalse);
      expect(cubit.state.pdfPath, isNull);
    });

    test('compilePdf generates PDF and auto-saves document', () async {
      final pdfFile = File(p.join(testDir.path, 'output.pdf'));
      await pdfFile.writeAsString('sample pdf');

      when(
        () => mockGenerate(
          documentId: any(named: 'documentId'),
          title: any(named: 'title'),
          pages: any(named: 'pages'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer(
        (_) async => (
          pdfPath: pdfFile.path,
          thumbnailPath: '/tmp/thumb.jpg',
          fileSizeBytes: 2048,
        ),
      );

      when(() => mockSave(any())).thenAnswer((_) async {});

      final cubit = createCubit();
      await cubit.compilePdf();

      expect(cubit.state.isGenerating, isFalse);
      expect(cubit.state.pdfPath, pdfFile.path);
      expect(cubit.state.thumbnailPath, '/tmp/thumb.jpg');
      expect(cubit.state.fileSizeBytes, 2048);
      expect(cubit.state.isSaved, isTrue);

      verify(() => mockSave(any())).called(1);
    });

    test(
      'savePdf explicitly saves document and emits successMessage',
      () async {
        final pdfFile = File(p.join(testDir.path, 'output.pdf'));
        await pdfFile.writeAsString('sample');

        when(
          () => mockGenerate(
            documentId: any(named: 'documentId'),
            title: any(named: 'title'),
            pages: any(named: 'pages'),
            pageSize: any(named: 'pageSize'),
          ),
        ).thenAnswer(
          (_) async => (
            pdfPath: pdfFile.path,
            thumbnailPath: '/tmp/thumb.jpg',
            fileSizeBytes: 1000,
          ),
        );
        when(() => mockSave(any())).thenAnswer((_) async {});

        final cubit = createCubit();
        await cubit.compilePdf();

        await cubit.savePdf();

        expect(cubit.state.isSaved, isTrue);
        expect(cubit.state.successMessage, 'Document saved successfully');
      },
    );

    test('renameDocument rejects empty title', () async {
      final cubit = createCubit();
      await cubit.renameDocument('   ');

      expect(cubit.state.errorMessage, 'Document title cannot be empty');
    });

    test(
      'renameDocument successfully renames file and updates state',
      () async {
        final pdfFile = File(p.join(testDir.path, 'sample.pdf'));
        await pdfFile.writeAsString('sample');

        when(
          () => mockGenerate(
            documentId: any(named: 'documentId'),
            title: any(named: 'title'),
            pages: any(named: 'pages'),
            pageSize: any(named: 'pageSize'),
          ),
        ).thenAnswer(
          (_) async => (
            pdfPath: pdfFile.path,
            thumbnailPath: '/tmp/thumb.jpg',
            fileSizeBytes: 1000,
          ),
        );
        when(() => mockSave(any())).thenAnswer((_) async {});

        final cubit = createCubit();
        await cubit.compilePdf();

        when(
          () => mockRename(
            documentId: 'doc-123',
            currentPdfPath: pdfFile.path,
            newTitle: 'New Title',
          ),
        ).thenAnswer((_) async => const Result.success('/renamed/path.pdf'));

        await cubit.renameDocument('New Title');

        expect(cubit.state.title, 'New Title');
        expect(cubit.state.pdfPath, '/renamed/path.pdf');
        expect(cubit.state.successMessage, 'Document renamed to "New Title"');
      },
    );

    test('sharePdf invokes sharePdfUseCase when file exists', () async {
      final pdfFile = File(p.join(testDir.path, 'sample.pdf'));
      await pdfFile.writeAsString('sample');

      when(
        () => mockGenerate(
          documentId: any(named: 'documentId'),
          title: any(named: 'title'),
          pages: any(named: 'pages'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer(
        (_) async => (
          pdfPath: pdfFile.path,
          thumbnailPath: '/tmp/thumb.jpg',
          fileSizeBytes: 1000,
        ),
      );
      when(() => mockSave(any())).thenAnswer((_) async {});
      when(
        () => mockShare(any(), title: any(named: 'title')),
      ).thenAnswer((_) async => const Result.success(null));

      final cubit = createCubit();
      await cubit.compilePdf();

      await cubit.sharePdf();

      expect(cubit.state.isSharing, isFalse);
      verify(() => mockShare(pdfFile.path, title: 'Initial Title')).called(1);
    });

    test(
      'openExternal invokes sharePdfUseCase.openExternal when file exists',
      () async {
        final pdfFile = File(p.join(testDir.path, 'sample.pdf'));
        await pdfFile.writeAsString('sample');

        when(
          () => mockGenerate(
            documentId: any(named: 'documentId'),
            title: any(named: 'title'),
            pages: any(named: 'pages'),
            pageSize: any(named: 'pageSize'),
          ),
        ).thenAnswer(
          (_) async => (
            pdfPath: pdfFile.path,
            thumbnailPath: '/tmp/thumb.jpg',
            fileSizeBytes: 1000,
          ),
        );
        when(() => mockSave(any())).thenAnswer((_) async {});
        when(
          () => mockShare.openExternal(any()),
        ).thenAnswer((_) async => const Result.success(null));

        final cubit = createCubit();
        await cubit.compilePdf();

        await cubit.openExternal();

        expect(cubit.state.isOpeningExternal, isFalse);
        verify(() => mockShare.openExternal(pdfFile.path)).called(1);
      },
    );

    test('deletePdf calls deletePdfUseCase and sets isDeleted', () async {
      when(
        () => mockDelete(
          documentId: any(named: 'documentId'),
          pdfPath: any(named: 'pdfPath'),
        ),
      ).thenAnswer((_) async => const Result.success(null));

      final cubit = createCubit();
      await cubit.deletePdf();

      expect(cubit.state.isDeleting, isFalse);
      expect(cubit.state.isDeleted, isTrue);
      expect(cubit.state.successMessage, 'Document deleted successfully');
    });
  });
}
