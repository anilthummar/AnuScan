import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:anuscan/core/errors/failures.dart' as f;
import 'package:anuscan/core/services/document_scanner_service.dart';
import 'package:anuscan/core/services/image_processing_service.dart';
import 'package:anuscan/core/utils/result.dart';
import 'package:anuscan/features/scanner/domain/repositories/scanner_repository.dart';
import 'package:anuscan/features/scanner/domain/usecases/import_gallery_usecase.dart';
import 'package:anuscan/features/scanner/domain/usecases/scan_document_usecase.dart';
import 'package:anuscan/features/scanner/domain/usecases/scan_documents_usecase.dart';
import 'package:anuscan/features/scanner/presentation/cubit/scanner_cubit.dart';
import 'package:anuscan/features/scanner/presentation/cubit/scanner_state.dart';

class MockScannerRepository extends Mock implements DocumentScannerRepository {}

class MockScanDocumentUseCase extends Mock implements ScanDocumentUseCase {}

class MockScanDocumentsUseCase extends Mock implements ScanDocumentsUseCase {}

class MockImportGalleryUseCase extends Mock implements ImportGalleryUseCase {}

void main() {
  late MockScannerRepository mockRepo;
  late MockScanDocumentUseCase mockScanDoc;
  late MockScanDocumentsUseCase mockScanDocs;
  late MockImportGalleryUseCase mockImportGallery;
  late StreamController<DocumentCornerPoints?> cornersController;

  setUp(() {
    mockRepo = MockScannerRepository();
    mockScanDoc = MockScanDocumentUseCase();
    mockScanDocs = MockScanDocumentsUseCase();
    mockImportGallery = MockImportGalleryUseCase();
    cornersController = StreamController<DocumentCornerPoints?>.broadcast();

    when(
      () => mockRepo.detectedCorners,
    ).thenAnswer((_) => cornersController.stream);
    when(
      () => mockRepo.detectionStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => mockRepo.currentDetectionState,
    ).thenReturn(DetectionState.searching);
    when(() => mockRepo.isFlashOn).thenReturn(false);
    when(() => mockRepo.releaseScanner()).thenAnswer((_) async {});
  });

  tearDown(() {
    cornersController.close();
  });

  ScannerCubit buildCubit() {
    return ScannerCubit(
      scannerRepository: mockRepo,
      scanDocumentUseCase: mockScanDoc,
      scanDocumentsUseCase: mockScanDocs,
      importGalleryUseCase: mockImportGallery,
    );
  }

  group('ScannerCubit comprehensive state machine tests', () {
    test('initial state is ScannerInitial', () {
      final cubit = buildCubit();
      expect(cubit.state, isA<ScannerInitial>());
      cubit.close();
    });

    blocTest<ScannerCubit, ScannerState>(
      'emits [ScannerInitializing, ScannerReady] on successful initializeCamera',
      build: () {
        when(
          () => mockRepo.initializeScanner(),
        ).thenAnswer((_) async => const Result.success(null));
        return buildCubit();
      },
      act: (cubit) => cubit.initializeCamera(),
      expect: () => [
        const ScannerInitializing(),
        const ScannerReady(isFlashOn: false),
      ],
    );

    blocTest<ScannerCubit, ScannerState>(
      'emits [ScannerInitializing, ScannerFailure] with isPermissionDenied=true on PermissionFailure',
      build: () {
        when(() => mockRepo.initializeScanner()).thenAnswer(
          (_) async =>
              const Result.failure(f.PermissionFailure('Permission denied')),
        );
        return buildCubit();
      },
      act: (cubit) => cubit.initializeCamera(),
      expect: () => [
        const ScannerInitializing(),
        const ScannerFailure(
          message: 'Permission denied',
          isPermissionDenied: true,
        ),
      ],
    );

    blocTest<ScannerCubit, ScannerState>(
      'emits [ScannerInitializing, ScannerFailure] on generic ScannerFailure',
      build: () {
        when(() => mockRepo.initializeScanner()).thenAnswer(
          (_) async =>
              const Result.failure(f.ScannerFailure('Camera init failed')),
        );
        return buildCubit();
      },
      act: (cubit) => cubit.initializeCamera(),
      expect: () => [
        const ScannerInitializing(),
        const ScannerFailure(
          message: 'Camera init failed',
          isPermissionDenied: false,
        ),
      ],
    );

    blocTest<ScannerCubit, ScannerState>(
      'emits [ScannerCapturing, ScannerProcessing, ScannerReviewing] on successful captureDocument',
      build: () {
        when(() => mockScanDoc()).thenAnswer(
          (_) async => const Result.success('/path/to/captured.jpg'),
        );
        return buildCubit();
      },
      seed: () => const ScannerReady(isFlashOn: false),
      act: (cubit) => cubit.captureDocument(),
      expect: () => [
        const ScannerCapturing(corners: null),
        const ScannerProcessing(
          rawImagePath: '/path/to/captured.jpg',
          corners: null,
          statusMessage: 'Preparing preview...',
        ),
        const ScannerReviewing(
          capturedImagePath: '/path/to/captured.jpg',
          corners: null,
        ),
      ],
    );

    blocTest<ScannerCubit, ScannerState>(
      'emits [ScannerCapturing, ScannerFailure] on failed captureDocument',
      build: () {
        when(() => mockScanDoc()).thenAnswer(
          (_) async =>
              const Result.failure(f.ScannerFailure('Failed to take picture')),
        );
        return buildCubit();
      },
      seed: () => const ScannerReady(isFlashOn: false),
      act: (cubit) => cubit.captureDocument(),
      expect: () => [
        const ScannerCapturing(corners: null),
        const ScannerFailure(message: 'Failed to take picture'),
      ],
    );

    blocTest<ScannerCubit, ScannerState>(
      'updates flash state in ScannerReady when toggleFlash succeeds',
      build: () {
        when(
          () => mockRepo.toggleFlash(),
        ).thenAnswer((_) async => const Result.success(true));
        return buildCubit();
      },
      seed: () => const ScannerReady(isFlashOn: false),
      act: (cubit) => cubit.toggleFlash(),
      expect: () => [const ScannerReady(isFlashOn: true)],
    );

    blocTest<ScannerCubit, ScannerState>(
      'emits [ScannerInitializing, ScannerSuccess] on scanWithCamera returning paths',
      build: () {
        when(
          () => mockScanDocs(),
        ).thenAnswer((_) async => ['/doc1.jpg', '/doc2.jpg']);
        return buildCubit();
      },
      act: (cubit) => cubit.scanWithCamera(),
      expect: () => [
        const ScannerInitializing(),
        const ScannerSuccess(['/doc1.jpg', '/doc2.jpg']),
      ],
    );

    blocTest<ScannerCubit, ScannerState>(
      'emits [ScannerInitializing, ScannerInitial] on scanWithCamera cancellation',
      build: () {
        when(() => mockScanDocs()).thenAnswer((_) async => []);
        return buildCubit();
      },
      act: (cubit) => cubit.scanWithCamera(),
      expect: () => [const ScannerInitializing(), const ScannerInitial()],
    );

    blocTest<ScannerCubit, ScannerState>(
      'emits [ScannerInitializing, ScannerSuccess] on importFromGallery returning paths',
      build: () {
        when(
          () => mockImportGallery(),
        ).thenAnswer((_) async => ['/gallery1.jpg']);
        return buildCubit();
      },
      act: (cubit) => cubit.importFromGallery(),
      expect: () => [
        const ScannerInitializing(),
        const ScannerSuccess(['/gallery1.jpg']),
      ],
    );

    blocTest<ScannerCubit, ScannerState>(
      'emits ScannerInitial on cancel',
      build: buildCubit,
      seed: () => const ScannerReady(isFlashOn: false),
      act: (cubit) => cubit.cancel(),
      expect: () => [const ScannerInitial()],
    );
  });
}
