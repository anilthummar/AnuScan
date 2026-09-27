import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:anuscan/core/services/file_storage_service.dart';
import 'package:anuscan/core/services/image_processing_service.dart';
import 'package:anuscan/features/document_editor/domain/entities/document_session.dart';
import 'package:anuscan/features/document_editor/domain/entities/scanned_page.dart';
import 'package:anuscan/features/document_editor/domain/usecases/edit_scan_page_usecase.dart';
import 'package:anuscan/features/document_editor/domain/usecases/reorder_pages_usecase.dart';
import 'package:anuscan/features/document_editor/presentation/cubit/document_session_cubit.dart';

class MockFileStorageService extends Mock implements FileStorageService {}

class MockImageProcessingService extends Mock
    implements ImageProcessingService {}

class MockEditScanPageUseCase extends Mock implements EditScanPageUseCase {}

class FakeScanPage extends Fake implements ScanPage {}

void main() {
  late MockFileStorageService mockStorageService;
  late MockImageProcessingService mockImageService;
  late MockEditScanPageUseCase mockEditScanPageUseCase;
  late DocumentSession initialSession;
  late DocumentSessionCubit cubit;

  setUpAll(() {
    registerFallbackValue(FakeScanPage());
    registerFallbackValue(ScanFilter.original);
  });

  setUp(() {
    mockStorageService = MockFileStorageService();
    mockImageService = MockImageProcessingService();
    mockEditScanPageUseCase = MockEditScanPageUseCase();

    initialSession = DocumentSession(
      id: 'session_1',
      name: 'Test Session',
      createdAt: DateTime(2026, 3, 22),
      updatedAt: DateTime(2026, 3, 22),
      pages: const [],
    );

    when(
      () => mockStorageService.copyImageFile(
        any(),
        any(),
        filename: any(named: 'filename'),
      ),
    ).thenAnswer(
      (invocation) async =>
          '/app_storage/session_1/${invocation.namedArguments[#filename]}',
    );

    when(
      () => mockImageService.getImageDimensions(any()),
    ).thenAnswer((_) async => (1080, 1920));

    cubit = DocumentSessionCubit(
      fileStorageService: mockStorageService,
      imageProcessingService: mockImageService,
      editScanPageUseCase: mockEditScanPageUseCase,
      reorderPagesUseCase: const ReorderPagesUseCase(),
      initialSession: initialSession,
    );
  });

  tearDown(() {
    cubit.close();
  });

  test('initial state contains initial session and zero pages', () {
    expect(cubit.state.session.id, equals('session_1'));
    expect(cubit.state.session.name, equals('Test Session'));
    expect(cubit.state.pageCount, equals(0));
    expect(cubit.state.isEmpty, isTrue);
  });

  test(
    'addScannedPages imports paths, assigns order, and copies files',
    () async {
      await cubit.addScannedPages(['/tmp/scan1.jpg', '/tmp/scan2.jpg']);

      expect(cubit.state.pageCount, equals(2));
      expect(cubit.state.session.pages[0].order, equals(0));
      expect(cubit.state.session.pages[1].order, equals(1));
      expect(cubit.state.session.pages[0].width, equals(1080));
      expect(cubit.state.session.pages[0].height, equals(1920));
      verify(
        () => mockStorageService.copyImageFile(
          'session_1',
          '/tmp/scan1.jpg',
          filename: any(named: 'filename'),
        ),
      ).called(2); // once for orig_, once for proc_
    },
  );

  test('addGalleryPages imports gallery paths into existing session', () async {
    await cubit.addGalleryPages(['/tmp/gallery1.jpg']);

    expect(cubit.state.pageCount, equals(1));
    expect(cubit.state.session.pages[0].order, equals(0));
    expect(cubit.state.session.pages[0].filter, equals(ScanFilter.original));
  });

  test('addPages appends already converted DocumentSessionPages', () {
    final page = DocumentSessionPage(
      id: 'p_test',
      imagePath: '/path/proc.jpg',
      order: 99,
      createdAt: DateTime.now(),
    );

    cubit.addPages([page]);

    expect(cubit.state.pageCount, equals(1));
    // Order should be normalized to 0
    expect(cubit.state.session.pages.first.order, equals(0));
  });

  test(
    'reorderPages correctly moves page forward and backward with index normalization',
    () async {
      await cubit.addScannedPages([
        '/tmp/scan1.jpg',
        '/tmp/scan2.jpg',
        '/tmp/scan3.jpg',
      ]);

      final page1Id = cubit.state.session.pages[0].id;
      final page2Id = cubit.state.session.pages[1].id;
      final page3Id = cubit.state.session.pages[2].id;

      // Move page 0 to index 2 (after page 1)
      cubit.reorderPages(0, 2);

      expect(cubit.state.session.pages[0].id, equals(page2Id));
      expect(cubit.state.session.pages[1].id, equals(page1Id));
      expect(cubit.state.session.pages[2].id, equals(page3Id));
      expect(cubit.state.session.pages[0].order, equals(0));
      expect(cubit.state.session.pages[1].order, equals(1));
      expect(cubit.state.session.pages[2].order, equals(2));
    },
  );

  test(
    'deletePage removes target page and re-indexes remaining pages',
    () async {
      await cubit.addScannedPages([
        '/tmp/scan1.jpg',
        '/tmp/scan2.jpg',
        '/tmp/scan3.jpg',
      ]);

      final page3Id = cubit.state.session.pages[2].id;

      // Delete middle page
      cubit.deletePage(1);

      expect(cubit.state.pageCount, equals(2));
      expect(cubit.state.session.pages[1].id, equals(page3Id));
      expect(cubit.state.session.pages[0].order, equals(0));
      expect(cubit.state.session.pages[1].order, equals(1));
    },
  );

  test(
    'duplicatePage clones original and processed files and inserts right after source page',
    () async {
      await cubit.addScannedPages(['/tmp/scan1.jpg', '/tmp/scan2.jpg']);
      final initialP1 = cubit.state.session.pages[0];

      await cubit.duplicatePage(0);

      expect(cubit.state.pageCount, equals(3));
      final dupPage = cubit.state.session.pages[1];
      expect(dupPage.id, isNot(equals(initialP1.id)));
      expect(dupPage.order, equals(1));
      expect(cubit.state.session.pages[2].order, equals(2));
      expect(cubit.state.selectedPageIndex, equals(1));

      // Verify storage calls for duplication
      verify(
        () => mockStorageService.copyImageFile(
          'session_1',
          initialP1.imagePath,
          filename: any(named: 'filename'),
        ),
      ).called(1);
    },
  );

  test(
    'rotatePage calls editScanPageUseCase with +90 degrees and updates state',
    () async {
      await cubit.addScannedPages(['/tmp/scan1.jpg']);
      final page = cubit.state.session.pages.first;

      when(
        () => mockEditScanPageUseCase(
          page: any(named: 'page'),
          rotationDegrees: 90,
        ),
      ).thenAnswer(
        (_) async => ScanPage(
          id: page.id,
          documentId: 'session_1',
          pageIndex: 0,
          originalImagePath: page.originalImagePath!,
          processedImagePath: '/app_storage/session_1/proc_rotated.jpg',
          rotationDegrees: 90,
          createdAt: page.createdAt,
        ),
      );

      await cubit.rotatePage(0);

      expect(cubit.state.session.pages[0].rotation, equals(90));
      expect(
        cubit.state.session.pages[0].imagePath,
        equals('/app_storage/session_1/proc_rotated.jpg'),
      );
    },
  );

  test('updateSessionName trims and updates session name', () {
    cubit.updateSessionName('   Tax Invoices 2026   ');
    expect(cubit.state.session.name, equals('Tax Invoices 2026'));
  });

  test('selectPage updates selectedPageIndex within bounds', () async {
    await cubit.addScannedPages(['/tmp/scan1.jpg', '/tmp/scan2.jpg']);

    cubit.selectPage(1);
    expect(cubit.state.selectedPageIndex, equals(1));
    expect(cubit.state.selectedPage?.order, equals(1));

    // Out of bounds selection is ignored
    cubit.selectPage(99);
    expect(cubit.state.selectedPageIndex, equals(1));
  });

  test('handles error gracefully when addScannedPages fails', () async {
    when(
      () => mockStorageService.copyImageFile(
        any(),
        any(),
        filename: any(named: 'filename'),
      ),
    ).thenThrow(Exception('Disk full'));

    await cubit.addScannedPages(['/tmp/broken.jpg']);

    expect(cubit.state.isProcessing, isFalse);
    expect(cubit.state.errorMessage, contains('Disk full'));
  });
}
