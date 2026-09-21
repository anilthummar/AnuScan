/// Repository contract for capturing and importing document pages.
abstract class ScannerRepository {
  /// Launches native camera scanner to scan one or more physical document pages.
  Future<List<String>> scanDocuments();

  /// Launches gallery picker to import one or more images from device storage.
  Future<List<String>> importFromGallery();
}
