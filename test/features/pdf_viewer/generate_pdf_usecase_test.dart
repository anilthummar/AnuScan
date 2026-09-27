import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:anuscan/core/errors/exceptions.dart';
import 'package:anuscan/core/errors/failures.dart';
import 'package:anuscan/core/services/file_storage_service.dart';
import 'package:anuscan/core/services/image_processing_service.dart';
import 'package:anuscan/core/services/pdf_generator_service.dart';
import 'package:anuscan/core/utils/result.dart';
import 'package:anuscan/features/document_editor/domain/entities/document_session.dart';
import 'package:anuscan/features/pdf_viewer/domain/repositories/pdf_repository.dart';
import 'package:anuscan/features/pdf_viewer/domain/usecases/generate_pdf_usecase.dart';

class MockPdfRepository extends Mock implements PdfRepository {}

class MockFileStorageService extends Mock implements FileStorageService {}

class MockImageProcessingService extends Mock
    implements ImageProcessingService {}

class FakeDocumentSession extends Fake implements DocumentSession {}

void main() {
  late MockPdfRepository mockPdfRepository;
  late MockFileStorageService mockStorageService;
  late MockImageProcessingService mockImageService;
  late GeneratePdfUseCase useCase;
  late File samplePdfFile;

  setUpAll(() {
    registerFallbackValue(FakeDocumentSession());
    registerFallbackValue(PdfPageSizeOption.a4);
    registerFallbackValue(PdfQualityOption.standard);
  });

  setUp(() async {
    mockPdfRepository = MockPdfRepository();
    mockStorageService = MockFileStorageService();
    mockImageService = MockImageProcessingService();

    final tempDir = await Directory.systemTemp.createTemp(
      'anuscan_usecase_test_',
    );
    samplePdfFile = File('${tempDir.path}/test_doc.pdf');
    await samplePdfFile.writeAsBytes([
      37,
      80,
      68,
      70,
      45,
      49,
      46,
      52,
    ]); // %PDF-1.4

    useCase = GeneratePdfUseCase(
      pdfRepository: mockPdfRepository,
      fileStorageService: mockStorageService,
      imageProcessingService: mockImageService,
    );
  });

  tearDown(() async {
    if (await samplePdfFile.parent.exists()) {
      await samplePdfFile.parent.delete(recursive: true);
    }
  });

  test(
    'call with DocumentSession executes repository and returns metadata',
    () async {
      final session = DocumentSession(
        id: 'session_1',
        name: 'Invoice',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        pages: [
          DocumentSessionPage(
            id: 'p1',
            imagePath: '/tmp/p1.jpg',
            order: 0,
            createdAt: DateTime.now(),
          ),
        ],
      );

      when(
        () => mockPdfRepository.generatePdfFromSession(
          session: any(named: 'session'),
          pageSize: any(named: 'pageSize'),
          quality: any(named: 'quality'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((_) async => Result.success(samplePdfFile.path));

      when(
        () => mockStorageService.getOrCreateDocumentDirectory(any()),
      ).thenAnswer((_) async => samplePdfFile.parent);

      when(
        () => mockImageService.generateThumbnail(
          inputPath: any(named: 'inputPath'),
          outputPath: any(named: 'outputPath'),
          targetWidth: any(named: 'targetWidth'),
        ),
      ).thenAnswer((_) async => '/tmp/thumb_session_1.jpg');

      final result = await useCase(
        session: session,
        pageSize: PdfPageSizeOption.a4,
        quality: PdfQualityOption.standard,
      );

      expect(result.pdfPath, equals(samplePdfFile.path));
      expect(result.thumbnailPath, equals('/tmp/thumb_session_1.jpg'));
      expect(result.fileSizeBytes, equals(8));
    },
  );

  test(
    'fromSession convenience method delegates directly to repository',
    () async {
      final session = DocumentSession(
        id: 'session_2',
        name: 'Receipt',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      when(
        () => mockPdfRepository.generatePdfFromSession(
          session: session,
          pageSize: PdfPageSizeOption.letter,
          quality: PdfQualityOption.high,
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((_) async => Result.success('/path/Receipt.pdf'));

      final result = await useCase.fromSession(
        session: session,
        pageSize: PdfPageSizeOption.letter,
        quality: PdfQualityOption.high,
      );

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, equals('/path/Receipt.pdf'));
    },
  );

  test(
    'throws PdfGenerationException when repository returns failure',
    () async {
      final session = DocumentSession(
        id: 's_err',
        name: 'Err',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      when(
        () => mockPdfRepository.generatePdfFromSession(
          session: any(named: 'session'),
          pageSize: any(named: 'pageSize'),
          quality: any(named: 'quality'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer(
        (_) async =>
            const Result.failure(PdfGenerationFailure('Compilation failed')),
      );

      expect(
        () => useCase(session: session),
        throwsA(isA<PdfGenerationException>()),
      );
    },
  );
}
