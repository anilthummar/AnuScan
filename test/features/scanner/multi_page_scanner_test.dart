import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:anuscan/core/services/document_scanner_service.dart';
import 'package:anuscan/core/services/file_storage_service.dart';
import 'package:anuscan/core/services/image_processing_service.dart';
import 'package:anuscan/core/utils/result.dart';
import 'package:anuscan/features/scanner/domain/repositories/scanner_repository.dart';
import 'package:anuscan/features/scanner/domain/usecases/import_gallery_usecase.dart';
import 'package:anuscan/features/scanner/domain/usecases/scan_document_usecase.dart';
import 'package:anuscan/features/scanner/domain/usecases/scan_documents_usecase.dart';
import 'package:anuscan/features/scanner/presentation/cubit/scanner_cubit.dart';
import 'package:anuscan/features/scanner/presentation/cubit/scanner_state.dart';

class MockScannerRepo extends Mock implements DocumentScannerRepository {}

class MockScanDoc extends Mock implements ScanDocumentUseCase {}

class MockScanDocs extends Mock implements ScanDocumentsUseCase {}

class MockImportGallery extends Mock implements ImportGalleryUseCase {}

class MockFileStorage extends Mock implements FileStorageService {}

void main() {
  late MockScannerRepo mockRepo;
  late MockScanDoc mockScanDoc;
  late MockScanDocs mockScanDocs;
  late MockImportGallery mockImportGallery;
  late MockFileStorage mockFileStorage;
  late StreamController<DocumentDetectionResult> detectionController;
  late StreamController<DocumentCornerPoints?> cornersController;

  setUp(() {
    mockRepo = MockScannerRepo();
    mockScanDoc = MockScanDoc();
    mockScanDocs = MockScanDocs();
    mockImportGallery = MockImportGallery();
    mockFileStorage = MockFileStorage();
    detectionController = StreamController<DocumentDetectionResult>.broadcast();
    cornersController = StreamController<DocumentCornerPoints?>.broadcast();

    when(
      () => mockRepo.initializeScanner(),
    ).thenAnswer((_) async => const Result.success(null));
    when(
      () => mockRepo.detectedCorners,
    ).thenAnswer((_) => cornersController.stream);
    when(
      () => mockRepo.detectionStream,
    ).thenAnswer((_) => detectionController.stream);
    when(
      () => mockRepo.currentDetectionState,
    ).thenReturn(DetectionState.searching);
    when(() => mockRepo.isFlashOn).thenReturn(false);
    when(() => mockRepo.releaseScanner()).thenAnswer((_) async {});
  });

  tearDown(() {
    detectionController.close();
    cornersController.close();
  });

  ScannerCubit buildCubit() => ScannerCubit(
    scannerRepository: mockRepo,
    scanDocumentUseCase: mockScanDoc,
    scanDocumentsUseCase: mockScanDocs,
    importGalleryUseCase: mockImportGallery,
    fileStorageService: mockFileStorage,
  );

  group('Multi-page Scanning & Keep/Retake Flow (Phase 10.15, 10.16)', () {
    test('Keep page retains file and increments page count', () async {
      when(
        () => mockScanDoc(),
      ).thenAnswer((_) async => const Result.success('/tmp/doc_page1.jpg'));

      final cubit = buildCubit();
      await cubit.initializeCamera();
      expect(cubit.state, isA<ScannerReady>());

      await cubit.captureDocument();
      expect(cubit.state, isA<ScannerReviewing>());

      final reviewState = cubit.state as ScannerReviewing;
      expect(reviewState.capturedImagePath, equals('/tmp/doc_page1.jpg'));

      cubit.keepPage(reviewState.capturedImagePath);
      expect(cubit.capturedPages.length, equals(1));
      expect(cubit.state, isA<ScannerReady>());
      expect((cubit.state as ScannerReady).scannedPagesCount, equals(1));

      cubit.finishScanning();
      expect(cubit.state, isA<ScannerSuccess>());
      expect(
        (cubit.state as ScannerSuccess).imagePaths,
        contains('/tmp/doc_page1.jpg'),
      );

      await cubit.close();
    });

    test(
      'Retake page calls deleteFile and does not increment page count',
      () async {
        when(
          () => mockScanDoc(),
        ).thenAnswer((_) async => const Result.success('/tmp/doc_retake.jpg'));
        when(() => mockFileStorage.deleteFile(any())).thenAnswer((_) async {});

        final cubit = buildCubit();
        await cubit.initializeCamera();

        await cubit.captureDocument();
        expect(cubit.state, isA<ScannerReviewing>());

        await cubit.retakePage('/tmp/doc_retake.jpg');

        verify(
          () => mockFileStorage.deleteFile('/tmp/doc_retake.jpg'),
        ).called(1);
        expect(cubit.capturedPages.isEmpty, isTrue);
        expect(cubit.state, isA<ScannerReady>());
        expect((cubit.state as ScannerReady).scannedPagesCount, equals(0));

        await cubit.close();
      },
    );

    test('Auto-capture triggers after steady ready state', () async {
      when(
        () => mockScanDoc(),
      ).thenAnswer((_) async => const Result.success('/tmp/autocapture.jpg'));

      final cubit = buildCubit();
      // Enable auto-capture
      cubit.toggleAutoCapture();
      expect(cubit.autoCapture, isTrue);

      await cubit.initializeCamera();

      const readyQuad = DocumentCornerPoints(
        topLeftX: 0.1,
        topLeftY: 0.1,
        topRightX: 0.9,
        topRightY: 0.1,
        bottomLeftX: 0.1,
        bottomLeftY: 0.9,
        bottomRightX: 0.9,
        bottomRightY: 0.9,
      );

      // Emit ready state
      detectionController.add(
        const DocumentDetectionResult(
          corners: readyQuad,
          state: DetectionState.ready,
        ),
      );

      await pumpEventQueue();
      expect(cubit.state, isA<ScannerDetecting>());
      expect(
        (cubit.state as ScannerDetecting).detectionState,
        equals(DetectionState.ready),
      );

      // Advance past 1.2s auto-capture hold duration
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      await pumpEventQueue();

      expect(cubit.state, isA<ScannerReviewing>());
      final reviewState = cubit.state as ScannerReviewing;
      expect(reviewState.capturedImagePath, equals('/tmp/autocapture.jpg'));

      await cubit.close();
    });

    test(
      'addGalleryPages appends pages and updates scannedPagesCount',
      () async {
        final cubit = buildCubit();
        await cubit.initializeCamera();

        cubit.addGalleryPages(['/tmp/g1.jpg', '/tmp/g2.jpg']);
        expect(cubit.capturedPages.length, equals(2));
        expect((cubit.state as ScannerReady).scannedPagesCount, equals(2));

        await cubit.close();
      },
    );
  });
}
