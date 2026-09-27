import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:anuscan/core/services/file_storage_service.dart';
import 'package:anuscan/core/services/image_processing_service.dart';
import 'package:anuscan/features/document_editor/domain/usecases/process_page_usecase.dart';
import 'package:anuscan/features/document_editor/domain/usecases/reorder_pages_usecase.dart';
import 'package:anuscan/features/document_editor/presentation/cubit/document_editor_cubit.dart';

class MockFileStorageService extends Mock implements FileStorageService {}

class MockImageProcessingService extends Mock
    implements ImageProcessingService {}

class MockProcessPageUseCase extends Mock implements ProcessPageUseCase {}

void main() {
  late MockFileStorageService mockStorageService;
  late MockImageProcessingService mockImageService;
  late MockProcessPageUseCase mockProcessPageUseCase;
  late DocumentEditorCubit cubit;

  setUp(() {
    mockStorageService = MockFileStorageService();
    mockImageService = MockImageProcessingService();
    mockProcessPageUseCase = MockProcessPageUseCase();

    when(
      () => mockStorageService.copyImageFile(
        any(),
        any(),
        filename: any(named: 'filename'),
      ),
    ).thenAnswer(
      (invocation) async =>
          '/app_storage/doc_1/${invocation.namedArguments[#filename]}',
    );

    when(
      () => mockImageService.getImageDimensions(any()),
    ).thenAnswer((_) async => (1080, 1920));

    cubit = DocumentEditorCubit(
      fileStorageService: mockStorageService,
      imageProcessingService: mockImageService,
      processPageUseCase: mockProcessPageUseCase,
      reorderPagesUseCase: const ReorderPagesUseCase(),
      documentId: 'doc_1',
      initialTitle: 'Test Document',
    );
  });

  tearDown(() {
    cubit.close();
  });

  test('initial state has empty pages and correct title', () {
    expect(cubit.state.documentId, equals('doc_1'));
    expect(cubit.state.title, equals('Test Document'));
    expect(cubit.state.pages, isEmpty);
  });

  test('addImages adds pages to state and copies files', () async {
    await cubit.addImages(['/tmp/page1.jpg', '/tmp/page2.jpg']);

    expect(cubit.state.pages.length, equals(2));
    expect(cubit.state.pages[0].pageIndex, equals(0));
    expect(cubit.state.pages[1].pageIndex, equals(1));
    expect(cubit.state.pages[0].width, equals(1080));
    expect(cubit.state.pages[0].height, equals(1920));
  });

  test('deletePage removes page and adjusts indices', () async {
    await cubit.addImages([
      '/tmp/page1.jpg',
      '/tmp/page2.jpg',
      '/tmp/page3.jpg',
    ]);
    expect(cubit.state.pages.length, equals(3));

    cubit.deletePage(1);

    expect(cubit.state.pages.length, equals(2));
    expect(cubit.state.pages[0].pageIndex, equals(0));
    expect(cubit.state.pages[1].pageIndex, equals(1));
  });

  test('reorderPages delegates to use case and normalizes order', () async {
    await cubit.addImages([
      '/tmp/page1.jpg',
      '/tmp/page2.jpg',
      '/tmp/page3.jpg',
    ]);
    final p1Id = cubit.state.pages[0].id;
    final p2Id = cubit.state.pages[1].id;

    cubit.reorderPages(0, 2);

    expect(cubit.state.pages[0].id, equals(p2Id));
    expect(cubit.state.pages[1].id, equals(p1Id));
    expect(cubit.state.pages[0].pageIndex, equals(0));
    expect(cubit.state.pages[1].pageIndex, equals(1));
  });

  test('duplicatePage duplicates page files and reindexes sequence', () async {
    await cubit.addImages(['/tmp/page1.jpg', '/tmp/page2.jpg']);

    await cubit.duplicatePage(0);

    expect(cubit.state.pages.length, equals(3));
    expect(cubit.state.pages[0].pageIndex, equals(0));
    expect(cubit.state.pages[1].pageIndex, equals(1));
    expect(cubit.state.pages[2].pageIndex, equals(2));
    expect(cubit.state.pages[1].id, isNot(equals(cubit.state.pages[0].id)));
  });

  test('toSession produces a valid DocumentSession domain object', () async {
    await cubit.addImages(['/tmp/page1.jpg']);

    final session = cubit.toSession();

    expect(session.id, equals('doc_1'));
    expect(session.name, equals('Test Document'));
    expect(session.pageCount, equals(1));
    expect(
      session.pages.first.imagePath,
      equals(cubit.state.pages.first.processedImagePath),
    );
  });

  test('updateTitle sanitizes and updates document title', () {
    cubit.updateTitle('  Quarterly Report 2026  ');
    expect(cubit.state.title, equals('Quarterly Report 2026'));
  });
}
