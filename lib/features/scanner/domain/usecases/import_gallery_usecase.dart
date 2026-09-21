import '../repositories/scanner_repository.dart';

/// Use case for importing document images from device photo gallery.
class ImportGalleryUseCase {
  const ImportGalleryUseCase(this._repository);

  final ScannerRepository _repository;

  Future<List<String>> call() async {
    return await _repository.importFromGallery();
  }
}
