import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:anuscan/core/services/image_processing_service.dart';
import 'package:anuscan/features/document_editor/domain/entities/scanned_page.dart';
import 'package:anuscan/features/document_editor/domain/usecases/edit_scan_page_usecase.dart';
import 'package:anuscan/features/document_editor/presentation/cubit/page_editor_cubit.dart';

class MockEditScanPageUseCase extends Mock implements EditScanPageUseCase {}

class FakeScanPage extends Fake implements ScanPage {}

void main() {
  late MockEditScanPageUseCase mockUseCase;
  late PageEditorCubit cubit;
  late ScanPage testPage;

  setUpAll(() {
    registerFallbackValue(FakeScanPage());
    registerFallbackValue(CropCorners.fullBounds());
    registerFallbackValue(ScanFilter.original);
  });

  setUp(() {
    mockUseCase = MockEditScanPageUseCase();

    testPage = ScanPage(
      id: 'page_1',
      documentId: 'doc_1',
      pageIndex: 0,
      originalImagePath: '/app/orig.jpg',
      processedImagePath: '/app/proc.jpg',
      filterType: ScanFilter.original,
      rotationDegrees: 0,
      corners: null,
      width: 1000,
      height: 1500,
      createdAt: DateTime(2026, 1, 1),
    );

    when(
      () => mockUseCase(
        page: any(named: 'page'),
        filterType: any(named: 'filterType'),
        rotationDegrees: any(named: 'rotationDegrees'),
        corners: any(named: 'corners'),
      ),
    ).thenAnswer(
      (invocation) async =>
          (invocation.namedArguments[#page] as ScanPage).copyWith(
            filterType: invocation.namedArguments[#filterType] as ScanFilter?,
            rotationDegrees:
                invocation.namedArguments[#rotationDegrees] as int?,
            corners: invocation.namedArguments[#corners] as CropCorners?,
            processedImagePath: '/app/proc_updated.jpg',
          ),
    );

    cubit = PageEditorCubit(
      initialPage: testPage,
      editScanPageUseCase: mockUseCase,
    );
  });

  tearDown(() {
    cubit.close();
  });

  test(
    'initial state has matching page, default filter, 0 rotation, and no unsaved changes',
    () {
      expect(cubit.state.currentPage, equals(testPage));
      expect(cubit.state.selectedFilter, equals(ScanFilter.original));
      expect(cubit.state.currentRotation, equals(0));
      expect(cubit.state.currentCorners, isNull);
      expect(cubit.state.hasUnsavedChanges, isFalse);
      expect(cubit.state.isProcessing, isFalse);
    },
  );

  test(
    'setFilter updates selectedFilter, processed image, and sets hasUnsavedChanges',
    () async {
      await cubit.setFilter(ScanFilter.enhanced);

      expect(cubit.state.selectedFilter, equals(ScanFilter.enhanced));
      expect(cubit.state.hasUnsavedChanges, isTrue);
      expect(cubit.state.currentPage.filterType, equals(ScanFilter.enhanced));
      expect(cubit.state.isProcessing, isFalse);

      verify(
        () => mockUseCase(
          page: testPage,
          filterType: ScanFilter.enhanced,
          rotationDegrees: 0,
          corners: null,
        ),
      ).called(1);
    },
  );

  test(
    'rotateClockwise increments rotation by 90 degrees in a 360 loop',
    () async {
      await cubit.rotateClockwise();
      expect(cubit.state.currentRotation, equals(90));
      expect(cubit.state.hasUnsavedChanges, isTrue);

      await cubit.rotateClockwise();
      expect(cubit.state.currentRotation, equals(180));

      await cubit.rotateClockwise();
      expect(cubit.state.currentRotation, equals(270));

      await cubit.rotateClockwise();
      expect(cubit.state.currentRotation, equals(0));
    },
  );

  test('rotateCounterClockwise decrements rotation by 90 degrees', () async {
    await cubit.rotateCounterClockwise();
    expect(cubit.state.currentRotation, equals(270));

    await cubit.rotateCounterClockwise();
    expect(cubit.state.currentRotation, equals(180));
  });

  test(
    'setCorners updates currentCorners and marks hasUnsavedChanges',
    () async {
      const corners = CropCorners(
        topLeftX: 0.1,
        topLeftY: 0.1,
        topRightX: 0.9,
        topRightY: 0.1,
        bottomLeftX: 0.1,
        bottomLeftY: 0.9,
        bottomRightX: 0.9,
        bottomRightY: 0.9,
      );

      await cubit.setCorners(corners);

      expect(cubit.state.currentCorners, equals(corners));
      expect(cubit.state.hasCrop, isTrue);
      expect(cubit.state.hasUnsavedChanges, isTrue);
    },
  );

  test('resetCrop resets crop corners back to full bounds', () async {
    const corners = CropCorners(
      topLeftX: 0.2,
      topLeftY: 0.2,
      topRightX: 0.8,
      topRightY: 0.2,
      bottomLeftX: 0.2,
      bottomLeftY: 0.8,
      bottomRightX: 0.8,
      bottomRightY: 0.8,
    );
    await cubit.setCorners(corners);
    expect(cubit.state.hasCrop, isTrue);

    await cubit.resetCrop();

    expect(cubit.state.currentCorners, isNull);
    expect(cubit.state.hasCrop, isFalse);
  });

  test(
    'resetToOriginal restores page to initial state without unsaved changes',
    () async {
      await cubit.setFilter(ScanFilter.blackAndWhite);
      await cubit.rotateClockwise();
      expect(cubit.state.hasUnsavedChanges, isTrue);

      await cubit.resetToOriginal();

      expect(cubit.state.selectedFilter, equals(ScanFilter.original));
      expect(cubit.state.currentRotation, equals(0));
      expect(cubit.state.currentCorners, isNull);
      expect(cubit.state.hasUnsavedChanges, isFalse);
    },
  );

  test(
    'handles exception in usecase and emits errorMessage without crashing',
    () async {
      when(
        () => mockUseCase(
          page: any(named: 'page'),
          filterType: any(named: 'filterType'),
          rotationDegrees: any(named: 'rotationDegrees'),
          corners: any(named: 'corners'),
        ),
      ).thenThrow(Exception('Processing failed'));

      await cubit.setFilter(ScanFilter.grayscale);

      expect(cubit.state.isProcessing, isFalse);
      expect(cubit.state.errorMessage, contains('Processing failed'));
    },
  );

  test('save returns current edited ScanPage', () {
    final savedPage = cubit.save();
    expect(savedPage, equals(testPage));
  });
}
