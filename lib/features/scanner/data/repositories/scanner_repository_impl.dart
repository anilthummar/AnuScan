import '../../../../core/services/document_scanner_service.dart';
import '../../../../core/services/gallery_service.dart';
import '../../domain/repositories/scanner_repository.dart';

/// Implementation of [ScannerRepository] consuming [DocumentScannerService] and [GalleryService].
class ScannerRepositoryImpl implements ScannerRepository {
  const ScannerRepositoryImpl({
    required this.scannerService,
    required this.galleryService,
  });

  final DocumentScannerService scannerService;
  final GalleryService galleryService;

  @override
  Future<List<String>> scanDocuments() async {
    return await scannerService.scanDocuments();
  }

  @override
  Future<List<String>> importFromGallery() async {
    return await galleryService.pickMultipleImages();
  }
}
