import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:anuscan/core/services/file_storage_service.dart';
import 'package:anuscan/core/services/gallery_service.dart';
import 'package:anuscan/core/services/image_processing_service.dart';
import 'package:anuscan/features/document_editor/domain/entities/scanned_page.dart';
import 'package:anuscan/features/gallery/data/repositories/gallery_repository_impl.dart';

class FakeGalleryService implements GalleryService {
  bool permissionGranted = true;
  List<String> pickedPaths = [];
  Set<String> corruptedPaths = {};

  @override
  Future<bool> checkPermission() async => permissionGranted;

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<List<String>> pickMultipleImages() async => pickedPaths;

  @override
  Future<String?> pickSingleImage() async =>
      pickedPaths.isNotEmpty ? pickedPaths.first : null;

  @override
  Future<bool> isImageValid(String path) async {
    return !corruptedPaths.contains(path);
  }
}

class FakeFileStorageService implements FileStorageService {
  int copyCount = 0;

  @override
  Future<String> copyImageFile(
    String documentId,
    String sourcePath, {
    String? filename,
  }) async {
    copyCount++;
    return '/storage/docs/$documentId/${filename ?? "copied.jpg"}';
  }

  @override
  Future<String> createTempFilePath({String extension = 'jpg'}) async {
    return '/storage/temp/temp_file.$extension';
  }

  @override
  Future<void> clearTempFiles() async {}

  @override
  Future<void> deleteFile(String filePath) async {}

  @override
  Future<void> deleteDocumentDirectory(String documentId) async {}

  @override
  Future<Directory> getAppDocumentsDirectory() async =>
      Directory('/storage/docs');

  @override
  Future<Directory> getOrCreateDocumentDirectory(String documentId) async =>
      Directory('/storage/docs/$documentId');

  @override
  Future<Directory> getTemporaryDirectory() async => Directory('/storage/temp');

  @override
  Future<String> saveImageBytes(
    String documentId,
    dynamic bytes, {
    String? filename,
  }) async => '/storage/docs/$documentId/${filename ?? "saved.jpg"}';
}

class FakeImageProcessingService implements ImageProcessingService {
  @override
  Future<(int width, int height)> getImageDimensions(String imagePath) async =>
      (1920, 1080);

  @override
  Future<String> generateThumbnail({
    required String inputPath,
    required String outputPath,
    int targetWidth = 300,
  }) async => outputPath;

  @override
  Future<String> applyFilter({
    required String inputPath,
    required String outputPath,
    required DocumentFilterType filterType,
    BwIntensity bwIntensity = BwIntensity.medium,
  }) async => outputPath;

  @override
  Future<String> rectifyPerspective({
    required String inputPath,
    required String outputPath,
    required DocumentCornerPoints corners,
  }) async => outputPath;

  @override
  Future<String> rotateImage({
    required String inputPath,
    required String outputPath,
    required int angleDegrees,
  }) async => outputPath;
}

void main() {
  late FakeGalleryService fakeGalleryService;
  late FakeFileStorageService fakeStorageService;
  late FakeImageProcessingService fakeImageService;
  late GalleryRepositoryImpl repository;

  setUp(() {
    fakeGalleryService = FakeGalleryService();
    fakeStorageService = FakeFileStorageService();
    fakeImageService = FakeImageProcessingService();
    repository = GalleryRepositoryImpl(
      galleryService: fakeGalleryService,
      fileStorageService: fakeStorageService,
      imageProcessingService: fakeImageService,
    );
  });

  group('GalleryRepositoryImpl', () {
    test('checkPermission returns success with permission status', () async {
      fakeGalleryService.permissionGranted = true;
      final res = await repository.checkPermission();
      expect(res.isSuccess, isTrue);
      expect(res.valueOrNull, isTrue);
    });

    test('requestPermission returns error when permission denied', () async {
      fakeGalleryService.permissionGranted = false;
      final res = await repository.requestPermission();
      expect(res.isFailure, isTrue);
      expect(res.errorOrNull?.message, contains('denied'));
    });

    test('pickImages returns list of selected image paths', () async {
      fakeGalleryService.pickedPaths = [
        '/path/to/img1.jpg',
        '/path/to/img2.jpg',
      ];
      final res = await repository.pickImages();
      expect(res.isSuccess, isTrue);
      expect(
        res.valueOrNull,
        equals(['/path/to/img1.jpg', '/path/to/img2.jpg']),
      );
    });

    test(
      'processImportedImages creates ScannedPage domain models preserving quality',
      () async {
        final rawPaths = ['/gallery/photo1.jpg', '/gallery/photo2.jpg'];
        final progressUpdates = <(int, int)>[];

        final res = await repository.processImportedImages(
          rawPaths: rawPaths,
          documentId: 'doc-456',
          startIndex: 0,
          onProgress: (current, total) => progressUpdates.add((current, total)),
        );

        expect(res.isSuccess, isTrue);
        final pages = res.valueOrNull!;
        expect(pages.length, equals(2));

        // Unified ScanPage / ScannedPage domain model checks
        expect(pages[0], isA<ScanPage>());
        expect(pages[0].documentId, equals('doc-456'));
        expect(pages[0].pageIndex, equals(0));
        expect(pages[0].width, equals(1920));
        expect(pages[0].height, equals(1080));
        expect(pages[0].originalImagePath, contains('orig_'));
        expect(pages[0].processedImagePath, contains('proc_'));

        expect(pages[1].pageIndex, equals(1));
        expect(progressUpdates, equals([(1, 2), (2, 2)]));
      },
    );

    test(
      'processImportedImages gracefully skips corrupted image and processes valid one',
      () async {
        final rawPaths = ['/gallery/corrupt.jpg', '/gallery/valid.jpg'];
        fakeGalleryService.corruptedPaths.add('/gallery/corrupt.jpg');

        final res = await repository.processImportedImages(
          rawPaths: rawPaths,
          documentId: 'doc-789',
        );

        expect(res.isSuccess, isTrue);
        final pages = res.valueOrNull!;
        expect(pages.length, equals(1));
        expect(pages[0].pageIndex, equals(0));
      },
    );

    test(
      'processImportedImages returns failure when all images are corrupted',
      () async {
        final rawPaths = ['/gallery/bad1.jpg', '/gallery/bad2.jpg'];
        fakeGalleryService.corruptedPaths.addAll(rawPaths);

        final res = await repository.processImportedImages(
          rawPaths: rawPaths,
          documentId: 'doc-789',
        );

        expect(res.isFailure, isTrue);
        expect(
          res.errorOrNull?.message,
          contains('corrupted or in an unsupported format'),
        );
      },
    );

    test(
      'processImportedImages returns empty list when rawPaths is empty',
      () async {
        final res = await repository.processImportedImages(
          rawPaths: [],
          documentId: 'doc-empty',
        );
        expect(res.isSuccess, isTrue);
        expect(res.valueOrNull, isEmpty);
      },
    );
  });
}
