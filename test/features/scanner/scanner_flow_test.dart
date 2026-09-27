import 'dart:async';
import 'package:flutter/material.dart';
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
import 'package:anuscan/features/scanner/presentation/widgets/document_corner_overlay.dart';

class MockDocumentScannerRepository extends Mock
    implements DocumentScannerRepository {}

class MockScanDocumentUseCase extends Mock implements ScanDocumentUseCase {}

class MockScanDocumentsUseCase extends Mock implements ScanDocumentsUseCase {}

class MockImportGalleryUseCase extends Mock implements ImportGalleryUseCase {}

void main() {
  late MockDocumentScannerRepository mockRepository;
  late MockScanDocumentUseCase mockScanDocumentUseCase;
  late MockScanDocumentsUseCase mockScanDocumentsUseCase;
  late MockImportGalleryUseCase mockImportGalleryUseCase;
  late StreamController<DocumentCornerPoints?> cornersController;

  setUp(() {
    mockRepository = MockDocumentScannerRepository();
    mockScanDocumentUseCase = MockScanDocumentUseCase();
    mockScanDocumentsUseCase = MockScanDocumentsUseCase();
    mockImportGalleryUseCase = MockImportGalleryUseCase();
    cornersController = StreamController<DocumentCornerPoints?>.broadcast();

    when(
      () => mockRepository.detectedCorners,
    ).thenAnswer((_) => cornersController.stream);
    when(
      () => mockRepository.detectionStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => mockRepository.currentDetectionState,
    ).thenReturn(DetectionState.searching);
    when(() => mockRepository.isFlashOn).thenReturn(false);
    when(() => mockRepository.releaseScanner()).thenAnswer((_) async {});
  });

  tearDown(() {
    cornersController.close();
  });

  group('ScannerCubit lifecycle & state transitions', () {
    test('initial state is ScannerInitial', () {
      final cubit = ScannerCubit(
        scannerRepository: mockRepository,
        scanDocumentUseCase: mockScanDocumentUseCase,
        scanDocumentsUseCase: mockScanDocumentsUseCase,
        importGalleryUseCase: mockImportGalleryUseCase,
      );

      expect(cubit.state, isA<ScannerInitial>());
      cubit.close();
    });

    test(
      'transitions through initializing -> ready -> detecting on success',
      () async {
        when(
          () => mockRepository.initializeScanner(),
        ).thenAnswer((_) async => const Result.success(null));

        final cubit = ScannerCubit(
          scannerRepository: mockRepository,
          scanDocumentUseCase: mockScanDocumentUseCase,
          scanDocumentsUseCase: mockScanDocumentsUseCase,
          importGalleryUseCase: mockImportGalleryUseCase,
        );

        final states = <ScannerState>[];
        cubit.stream.listen(states.add);

        await cubit.initializeCamera();
        await pumpEventQueue();

        expect(states, contains(isA<ScannerInitializing>()));
        expect(states, contains(isA<ScannerReady>()));

        // Emit detected document corners
        const sampleCorners = DocumentCornerPoints(
          topLeftX: 0.1,
          topLeftY: 0.2,
          topRightX: 0.9,
          topRightY: 0.2,
          bottomLeftX: 0.1,
          bottomLeftY: 0.8,
          bottomRightX: 0.9,
          bottomRightY: 0.8,
        );
        cornersController.add(sampleCorners);
        await pumpEventQueue();

        expect(states.last, isA<ScannerDetecting>());
        final detectingState = states.last as ScannerDetecting;
        expect(detectingState.corners, equals(sampleCorners));

        await cubit.close();
      },
    );

    test(
      'emits ScannerFailure with isPermissionDenied=true on PermissionFailure',
      () async {
        when(() => mockRepository.initializeScanner()).thenAnswer(
          (_) async => const Result.failure(
            f.PermissionFailure('Camera permission denied'),
          ),
        );

        final cubit = ScannerCubit(
          scannerRepository: mockRepository,
          scanDocumentUseCase: mockScanDocumentUseCase,
          scanDocumentsUseCase: mockScanDocumentsUseCase,
          importGalleryUseCase: mockImportGalleryUseCase,
        );

        final states = <ScannerState>[];
        cubit.stream.listen(states.add);

        await cubit.initializeCamera();
        await pumpEventQueue();

        expect(states.last, isA<ScannerFailure>());
        final failureState = states.last as ScannerFailure;
        expect(failureState.isPermissionDenied, isTrue);
        expect(failureState.message, contains('permission'));

        await cubit.close();
      },
    );

    test('emits ScannerFailure on camera initialization failure', () async {
      when(() => mockRepository.initializeScanner()).thenAnswer(
        (_) async =>
            const Result.failure(f.ScannerFailure('No camera hardware found')),
      );

      final cubit = ScannerCubit(
        scannerRepository: mockRepository,
        scanDocumentUseCase: mockScanDocumentUseCase,
        scanDocumentsUseCase: mockScanDocumentsUseCase,
        importGalleryUseCase: mockImportGalleryUseCase,
      );

      final states = <ScannerState>[];
      cubit.stream.listen(states.add);

      await cubit.initializeCamera();
      await pumpEventQueue();

      expect(states.last, isA<ScannerFailure>());
      final failureState = states.last as ScannerFailure;
      expect(failureState.isPermissionDenied, isFalse);
      expect(failureState.message, contains('hardware'));

      await cubit.close();
    });

    test(
      'manual capture transitions through capturing -> processing -> reviewing',
      () async {
        when(
          () => mockRepository.initializeScanner(),
        ).thenAnswer((_) async => const Result.success(null));
        when(() => mockScanDocumentUseCase()).thenAnswer(
          (_) async => const Result.success('/data/user/0/cache/scan_100.jpg'),
        );

        final cubit = ScannerCubit(
          scannerRepository: mockRepository,
          scanDocumentUseCase: mockScanDocumentUseCase,
          scanDocumentsUseCase: mockScanDocumentsUseCase,
          importGalleryUseCase: mockImportGalleryUseCase,
        );

        final states = <ScannerState>[];
        cubit.stream.listen(states.add);

        await cubit.initializeCamera();
        await pumpEventQueue();

        // Trigger manual capture
        await cubit.captureDocument();
        await pumpEventQueue();

        expect(states, contains(isA<ScannerCapturing>()));
        expect(states, contains(isA<ScannerProcessing>()));
        expect(states.last, isA<ScannerReviewing>());

        final reviewingState = states.last as ScannerReviewing;
        expect(
          reviewingState.capturedImagePath,
          equals('/data/user/0/cache/scan_100.jpg'),
        );

        // Keep page and complete scanning
        cubit.keepPage(reviewingState.capturedImagePath);
        expect(
          cubit.capturedPages,
          contains('/data/user/0/cache/scan_100.jpg'),
        );

        cubit.finishScanning();
        expect(cubit.state, isA<ScannerSuccess>());
        final successState = cubit.state as ScannerSuccess;
        expect(
          successState.imagePaths,
          contains('/data/user/0/cache/scan_100.jpg'),
        );

        await cubit.close();
      },
    );

    test('cancel releases camera and resets to ScannerInitial', () async {
      when(
        () => mockRepository.initializeScanner(),
      ).thenAnswer((_) async => const Result.success(null));

      final cubit = ScannerCubit(
        scannerRepository: mockRepository,
        scanDocumentUseCase: mockScanDocumentUseCase,
        scanDocumentsUseCase: mockScanDocumentsUseCase,
        importGalleryUseCase: mockImportGalleryUseCase,
      );

      await cubit.initializeCamera();
      expect(cubit.state, isA<ScannerReady>());

      await cubit.cancel();
      expect(cubit.state, isA<ScannerInitial>());
      verify(() => mockRepository.releaseScanner()).called(1);

      await cubit.close();
    });
  });

  group('DocumentCornerOverlay widget', () {
    testWidgets('paints detected corners without exception', (tester) async {
      const corners = DocumentCornerPoints(
        topLeftX: 0.1,
        topLeftY: 0.15,
        topRightX: 0.85,
        topRightY: 0.18,
        bottomLeftX: 0.12,
        bottomLeftY: 0.82,
        bottomRightX: 0.88,
        bottomRightY: 0.80,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: DocumentCornerOverlay(corners: corners)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DocumentCornerOverlay), findsOneWidget);
    });
  });
}
