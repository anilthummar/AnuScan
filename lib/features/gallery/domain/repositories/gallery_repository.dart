import '../../../../core/utils/result.dart';
import '../../../document_editor/domain/entities/scanned_page.dart';

/// Repository contract for gallery image selection, permission handling,
/// and document-processing pipeline ingestion.
abstract class GalleryRepository {
  /// Checks whether photo library or storage access is granted.
  Future<Result<bool>> checkPermission();

  /// Requests photo library or storage access.
  Future<Result<bool>> requestPermission();

  /// Prompts the user to pick multiple images from the device gallery.
  /// Returns a list of absolute file paths. An empty list indicates user cancellation.
  Future<Result<List<String>>> pickImages();

  /// Prompts the user to pick a single image from the device gallery.
  /// Returns the absolute file path, or null if user cancelled.
  Future<Result<String?>> pickSingleImage();

  /// Ingests a list of [rawPaths] through the document processing pipeline,
  /// creating unified [ScannedPage] domain models.
  ///
  /// Skips any corrupted or unsupported files, and reports [onProgress] (current, total)
  /// as each image is processed.
  Future<Result<List<ScannedPage>>> processImportedImages({
    required List<String> rawPaths,
    required String documentId,
    int startIndex = 0,
    void Function(int current, int total)? onProgress,
  });
}
