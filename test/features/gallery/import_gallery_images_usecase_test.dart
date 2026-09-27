import 'package:flutter_test/flutter_test.dart';
import 'package:anuscan/core/errors/failures.dart';
import 'package:anuscan/core/services/image_processing_service.dart';
import 'package:anuscan/core/utils/result.dart';
import 'package:anuscan/features/document_editor/domain/entities/scanned_page.dart';
import 'package:anuscan/features/gallery/domain/repositories/gallery_repository.dart';
import 'package:anuscan/features/gallery/domain/usecases/import_gallery_images_usecase.dart';

class MockGalleryRepository implements GalleryRepository {
  Result<bool> permissionResult = const Result.success(true);
  Result<List<String>> pickResult = const Result.success(['/path/image1.jpg']);
  Result<List<ScannedPage>> processResult = Result.success([
    ScannedPage(
      id: 'page-1',
      documentId: 'doc-1',
      pageIndex: 0,
      originalImagePath: '/path/orig_1.jpg',
      processedImagePath: '/path/proc_1.jpg',
      filterType: DocumentFilterType.original,
      createdAt: DateTime.now(),
    ),
  ]);

  @override
  Future<Result<bool>> checkPermission() async => permissionResult;

  @override
  Future<Result<bool>> requestPermission() async => permissionResult;

  @override
  Future<Result<List<String>>> pickImages() async => pickResult;

  @override
  Future<Result<String?>> pickSingleImage() async =>
      const Result.success('/path/single.jpg');

  @override
  Future<Result<List<ScannedPage>>> processImportedImages({
    required List<String> rawPaths,
    required String documentId,
    int startIndex = 0,
    void Function(int current, int total)? onProgress,
  }) async {
    onProgress?.call(1, rawPaths.length);
    return processResult;
  }
}

void main() {
  late MockGalleryRepository mockRepo;
  late ImportGalleryImagesUseCase useCase;

  setUp(() {
    mockRepo = MockGalleryRepository();
    useCase = ImportGalleryImagesUseCase(mockRepo);
  });

  group('ImportGalleryImagesUseCase', () {
    test('returns error when permission is denied', () async {
      mockRepo.permissionResult = const Result<bool>.failure(
        PermissionFailure('Photo library permission denied'),
      );

      final result = await useCase(documentId: 'doc-1');
      expect(result.isFailure, isTrue);
      expect(
        result.errorOrNull?.message,
        contains('Photo library permission denied'),
      );
    });

    test('returns empty list when user cancels picker', () async {
      mockRepo.pickResult = const Result.success([]);

      final result = await useCase(documentId: 'doc-1');
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isEmpty);
    });

    test('returns error when picking fails', () async {
      mockRepo.pickResult = const Result<List<String>>.failure(
        StorageFailure('Picker crashed'),
      );

      final result = await useCase(documentId: 'doc-1');
      expect(result.isFailure, isTrue);
      expect(result.errorOrNull?.message, contains('Picker crashed'));
    });

    test('successfully picks and processes images into ScanPages', () async {
      final progressList = <(int, int)>[];
      final result = await useCase(
        documentId: 'doc-1',
        onProgress: (cur, tot) => progressList.add((cur, tot)),
      );

      expect(result.isSuccess, isTrue);
      final pages = result.valueOrNull!;
      expect(pages.length, equals(1));
      expect(pages.first.id, equals('page-1'));
      expect(progressList, equals([(1, 1)]));
    });

    test('skips picking and processes directly when rawPaths provided', () async {
      // Intentionally set pickResult to failure to assert picker was not called
      mockRepo.pickResult = const Result<List<String>>.failure(
        StorageFailure('Should not be called'),
      );

      final result = await useCase(
        documentId: 'doc-1',
        rawPaths: ['/direct/path.jpg'],
      );

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull?.first.id, equals('page-1'));
    });
  });
}
