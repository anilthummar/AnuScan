import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:anuscan/core/services/file_storage_service.dart';
import 'package:anuscan/core/services/image_processing_service.dart';
import 'package:anuscan/features/document_editor/domain/entities/scanned_page.dart';
import 'package:anuscan/features/document_editor/domain/usecases/edit_scan_page_usecase.dart';

class MockImageProcessingService extends Mock
    implements ImageProcessingService {}

class MockFileStorageService extends Mock implements FileStorageService {}

void main() {
  late MockImageProcessingService mockImageService;
  late MockFileStorageService mockStorageService;
  late EditScanPageUseCase useCase;
  late ScanPage testPage;

  setUpAll(() {
    registerFallbackValue(CropCorners.fullBounds());
    registerFallbackValue(ScanFilter.original);
  });

  setUp(() {
    mockImageService = MockImageProcessingService();
    mockStorageService = MockFileStorageService();
    useCase = EditScanPageUseCase(
      imageProcessingService: mockImageService,
      fileStorageService: mockStorageService,
    );

    testPage = ScanPage(
      id: 'page_1',
      documentId: 'doc_1',
      pageIndex: 0,
      originalImagePath: '/app_storage/doc_1/orig_0.jpg',
      processedImagePath: '/app_storage/doc_1/proc_0.jpg',
      width: 1200,
      height: 1600,
      createdAt: DateTime(2026, 1, 1),
    );

    when(
      () => mockStorageService.createTempFilePath(
        extension: any(named: 'extension'),
      ),
    ).thenAnswer(
      (invocation) async =>
          '/tmp/${invocation.namedArguments[#extension] ?? 'temp.jpg'}',
    );

    when(() => mockStorageService.deleteFile(any())).thenAnswer((_) async {});

    when(
      () => mockImageService.applyFilter(
        inputPath: any(named: 'inputPath'),
        outputPath: any(named: 'outputPath'),
        filterType: any(named: 'filterType'),
      ),
    ).thenAnswer((invocation) async => invocation.namedArguments[#outputPath]);

    when(
      () => mockImageService.rotateImage(
        inputPath: any(named: 'inputPath'),
        outputPath: any(named: 'outputPath'),
        angleDegrees: any(named: 'angleDegrees'),
      ),
    ).thenAnswer((invocation) async => invocation.namedArguments[#outputPath]);

    when(
      () => mockImageService.rectifyPerspective(
        inputPath: any(named: 'inputPath'),
        outputPath: any(named: 'outputPath'),
        corners: any(named: 'corners'),
      ),
    ).thenAnswer((invocation) async => invocation.namedArguments[#outputPath]);

    when(
      () => mockImageService.getImageDimensions(any()),
    ).thenAnswer((_) async => (1200, 1600));
  });

  test('preserves originalImagePath without mutating it', () async {
    final result = await useCase(
      page: testPage,
      filterType: ScanFilter.enhanced,
    );

    expect(result.originalImagePath, equals(testPage.originalImagePath));
    expect(result.filterType, equals(ScanFilter.enhanced));
    expect(result.processedImagePath, contains('proc_'));
  });

  test('applies rotation when angleDegrees > 0', () async {
    when(
      () => mockImageService.getImageDimensions(any()),
    ).thenAnswer((_) async => (1600, 1200));

    final result = await useCase(page: testPage, rotationDegrees: 90);

    verify(
      () => mockImageService.rotateImage(
        inputPath: testPage.originalImagePath,
        outputPath: any(named: 'outputPath'),
        angleDegrees: 90,
      ),
    ).called(1);

    expect(result.rotationDegrees, equals(90));
    expect(result.width, equals(1600));
    expect(result.height, equals(1200));
  });

  test(
    'applies perspective rectification when custom corners provided',
    () async {
      const customCorners = CropCorners(
        topLeftX: 0.1,
        topLeftY: 0.1,
        topRightX: 0.9,
        topRightY: 0.1,
        bottomLeftX: 0.05,
        bottomLeftY: 0.95,
        bottomRightX: 0.95,
        bottomRightY: 0.95,
      );

      final result = await useCase(page: testPage, corners: customCorners);

      verify(
        () => mockImageService.rectifyPerspective(
          inputPath: testPage.originalImagePath,
          outputPath: any(named: 'outputPath'),
          corners: customCorners,
        ),
      ).called(1);

      expect(result.corners, equals(customCorners));
    },
  );

  test(
    'skips perspective rectification when corners are full bounds',
    () async {
      final fullCorners = CropCorners.fullBounds();

      await useCase(page: testPage, corners: fullCorners);

      verifyNever(
        () => mockImageService.rectifyPerspective(
          inputPath: any(named: 'inputPath'),
          outputPath: any(named: 'outputPath'),
          corners: any(named: 'corners'),
        ),
      );
    },
  );

  test(
    'executes complete pipeline in order: crop -> rotate -> filter',
    () async {
      const customCorners = CropCorners(
        topLeftX: 0.1,
        topLeftY: 0.1,
        topRightX: 0.9,
        topRightY: 0.1,
        bottomLeftX: 0.1,
        bottomLeftY: 0.9,
        bottomRightX: 0.9,
        bottomRightY: 0.9,
      );

      final result = await useCase(
        page: testPage,
        corners: customCorners,
        rotationDegrees: 180,
        filterType: ScanFilter.blackAndWhite,
      );

      verifyInOrder([
        () => mockImageService.rectifyPerspective(
          inputPath: testPage.originalImagePath,
          outputPath: any(named: 'outputPath'),
          corners: customCorners,
        ),
        () => mockImageService.rotateImage(
          inputPath: any(named: 'inputPath'),
          outputPath: any(named: 'outputPath'),
          angleDegrees: 180,
        ),
        () => mockImageService.applyFilter(
          inputPath: any(named: 'inputPath'),
          outputPath: any(named: 'outputPath'),
          filterType: ScanFilter.blackAndWhite,
        ),
      ]);

      expect(result.filterType, equals(ScanFilter.blackAndWhite));
      expect(result.rotationDegrees, equals(180));
      expect(result.corners, equals(customCorners));
    },
  );
}
