import '../../../../core/utils/result.dart';
import '../../../document_editor/domain/entities/scanned_page.dart';
import '../repositories/gallery_repository.dart';

/// Use case for importing images from the device gallery into a scan session.
class ImportGalleryImagesUseCase {
  const ImportGalleryImagesUseCase(this._repository);

  final GalleryRepository _repository;

  /// Executes image selection (or accepts existing [rawPaths]) and runs them through
  /// the document processing pipeline.
  ///
  /// Returns [Result.success] with an empty list if the user cancels selection.
  Future<Result<List<ScannedPage>>> call({
    required String documentId,
    List<String>? rawPaths,
    int startIndex = 0,
    void Function(int current, int total)? onProgress,
  }) async {
    List<String> pathsToProcess;

    if (rawPaths != null) {
      pathsToProcess = rawPaths;
    } else {
      // 1. Check & Request permission
      final permResult = await _repository.requestPermission();
      if (permResult.isFailure) {
        return Result.error(permResult.errorOrNull!);
      }

      // 2. Pick images from gallery
      final pickResult = await _repository.pickImages();
      if (pickResult.isFailure) {
        return Result.error(pickResult.errorOrNull!);
      }

      pathsToProcess = pickResult.valueOrNull ?? [];
      // User cancelled
      if (pathsToProcess.isEmpty) {
        return const Result.success([]);
      }
    }

    // 3. Process each image through unified pipeline
    return await _repository.processImportedImages(
      rawPaths: pathsToProcess,
      documentId: documentId,
      startIndex: startIndex,
      onProgress: onProgress,
    );
  }
}
