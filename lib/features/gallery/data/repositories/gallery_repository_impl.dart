import 'package:uuid/uuid.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/file_storage_service.dart';
import '../../../../core/services/gallery_service.dart';
import '../../../../core/services/image_processing_service.dart';
import '../../../../core/utils/result.dart';
import '../../../document_editor/domain/entities/scanned_page.dart';
import '../../domain/repositories/gallery_repository.dart';

/// Concrete implementation of [GalleryRepository].
class GalleryRepositoryImpl implements GalleryRepository {
  GalleryRepositoryImpl({
    required this.galleryService,
    required this.fileStorageService,
    required this.imageProcessingService,
    Uuid? uuid,
  }) : uuid = uuid ?? const Uuid();

  final GalleryService galleryService;
  final FileStorageService fileStorageService;
  final ImageProcessingService imageProcessingService;
  final Uuid uuid;

  @override
  Future<Result<bool>> checkPermission() async {
    try {
      final granted = await galleryService.checkPermission();
      return Result.success(granted);
    } catch (e) {
      return Result.error(
        PermissionFailure('Failed to check photo permission: $e'),
      );
    }
  }

  @override
  Future<Result<bool>> requestPermission() async {
    try {
      final granted = await galleryService.requestPermission();
      if (!granted) {
        return const Result.error(
          PermissionFailure('Photo library permission was denied.'),
        );
      }
      return const Result.success(true);
    } catch (e) {
      return Result.error(
        PermissionFailure('Failed to request photo permission: $e'),
      );
    }
  }

  @override
  Future<Result<List<String>>> pickImages() async {
    try {
      final paths = await galleryService.pickMultipleImages();
      return Result.success(paths);
    } catch (e) {
      return Result.error(
        StorageFailure('Failed to pick images from gallery: $e'),
      );
    }
  }

  @override
  Future<Result<String?>> pickSingleImage() async {
    try {
      final path = await galleryService.pickSingleImage();
      return Result.success(path);
    } catch (e) {
      return Result.error(
        StorageFailure('Failed to pick image from gallery: $e'),
      );
    }
  }

  @override
  Future<Result<List<ScannedPage>>> processImportedImages({
    required List<String> rawPaths,
    required String documentId,
    int startIndex = 0,
    void Function(int current, int total)? onProgress,
  }) async {
    if (rawPaths.isEmpty) {
      return const Result.success([]);
    }

    final pages = <ScannedPage>[];
    var currentIndex = startIndex;
    var corruptedCount = 0;
    final total = rawPaths.length;

    for (int i = 0; i < total; i++) {
      final rawPath = rawPaths[i];
      onProgress?.call(i + 1, total);

      try {
        final isValid = await galleryService.isImageValid(rawPath);
        if (!isValid) {
          corruptedCount++;
          continue;
        }

        final pageId = uuid.v4();

        // 1. Persist original image into dedicated document storage folder
        final origName = 'orig_$pageId.jpg';
        final storedOriginal = await fileStorageService.copyImageFile(
          documentId,
          rawPath,
          filename: origName,
        );

        // 2. Initial processed copy is identical to original
        final procName = 'proc_$pageId.jpg';
        final storedProcessed = await fileStorageService.copyImageFile(
          documentId,
          rawPath,
          filename: procName,
        );

        // 3. Extract dimensions
        final (width, height) = await imageProcessingService.getImageDimensions(
          storedProcessed,
        );

        pages.add(
          ScannedPage(
            id: pageId,
            documentId: documentId,
            pageIndex: currentIndex++,
            originalImagePath: storedOriginal,
            processedImagePath: storedProcessed,
            filterType: DocumentFilterType.original,
            rotationDegrees: 0,
            corners: null,
            width: width,
            height: height,
            createdAt: DateTime.now(),
          ),
        );
      } catch (_) {
        corruptedCount++;
      }
    }

    if (pages.isEmpty && corruptedCount > 0) {
      return Result.error(
        ValidationFailure(
          corruptedCount == 1
              ? 'The selected image is corrupted or in an unsupported format.'
              : 'All $corruptedCount selected images are corrupted or in an unsupported format.',
        ),
      );
    }

    return Result.success(pages);
  }
}
