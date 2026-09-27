import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:anuscan/core/di/injection.dart';
import 'package:anuscan/core/services/file_storage_service.dart';
import 'package:anuscan/core/services/image_processing_service.dart';
import 'package:anuscan/features/document_editor/domain/entities/scanned_page.dart';
import 'package:anuscan/features/document_editor/domain/usecases/edit_scan_page_usecase.dart';
import 'package:anuscan/features/document_editor/presentation/screens/page_editor_screen.dart';

class MockEditScanPageUseCase extends Mock implements EditScanPageUseCase {}

class MockImageProcessingService extends Mock
    implements ImageProcessingService {}

class MockFileStorageService extends Mock implements FileStorageService {}

class FakeScanPage extends Fake implements ScanPage {}

void main() {
  late Directory tempDir;
  late File testFile;
  late ScanPage testPage;
  late MockEditScanPageUseCase mockUseCase;

  setUpAll(() {
    registerFallbackValue(FakeScanPage());
    registerFallbackValue(CropCorners.fullBounds());
    registerFallbackValue(ScanFilter.original);
  });

  setUp(() async {
    await sl.reset();
    tempDir = Directory.systemTemp.createTempSync('page_editor_test_');
    testFile = File('${tempDir.path}/test_image.jpg');
    final dummyImg = img.Image(width: 40, height: 40);
    testFile.writeAsBytesSync(img.encodeJpg(dummyImg));

    testPage = ScanPage(
      id: 'p1',
      documentId: 'doc1',
      pageIndex: 0,
      originalImagePath: testFile.path,
      processedImagePath: testFile.path,
      width: 40,
      height: 40,
      createdAt: DateTime(2026, 1, 1),
    );

    mockUseCase = MockEditScanPageUseCase();
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
          ),
    );

    await setupDependencyInjection(
      customImageService: MockImageProcessingService(),
      customStorageService: MockFileStorageService(),
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Widget buildTestWidget() {
    return MaterialApp(
      home: PageEditorScreen(page: testPage, editScanPageUseCase: mockUseCase),
    );
  }

  testWidgets(
    'renders page title, interactive preview, tools, and filter selector',
    (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Edit Page 1'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Crop / Perspective'), findsOneWidget);
      expect(find.text('Rotate'), findsOneWidget);

      // Verify all 5 filter options exist
      expect(find.text('Original'), findsOneWidget);
      expect(find.text('Color'), findsOneWidget);
      expect(find.text('Grayscale'), findsOneWidget);
      expect(find.text('B & W'), findsOneWidget);
      expect(find.text('Enhanced'), findsOneWidget);
    },
  );

  testWidgets('tapping filter selects and triggers EditScanPageUseCase', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final enhancedChip = find.text('Enhanced');
    expect(enhancedChip, findsOneWidget);

    await tester.tap(enhancedChip);
    await tester.pumpAndSettle();

    verify(
      () => mockUseCase(
        page: any(named: 'page'),
        filterType: ScanFilter.enhanced,
        rotationDegrees: 0,
        corners: null,
      ),
    ).called(1);

    // Reset button should now be visible since there are unsaved changes
    expect(find.byTooltip('Reset to Original'), findsOneWidget);
  });

  testWidgets('tapping Rotate triggers clockwise rotation', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final rotateButton = find.text('Rotate');
    await tester.tap(rotateButton);
    await tester.pumpAndSettle();

    verify(
      () => mockUseCase(
        page: any(named: 'page'),
        filterType: any(named: 'filterType'),
        rotationDegrees: 90,
        corners: null,
      ),
    ).called(1);
  });

  testWidgets('tapping Done returns edited ScanPage', (tester) async {
    ScanPage? returnedPage;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                returnedPage = await Navigator.push<ScanPage>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PageEditorScreen(
                      page: testPage,
                      editScanPageUseCase: mockUseCase,
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Done'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(returnedPage, isNotNull);
    expect(returnedPage!.id, equals('p1'));
  });
}
