import 'package:flutter/widgets.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/document_scanner_service.dart';
import '../../../../core/services/gallery_service.dart';
import '../../../../core/services/image_processing_service.dart';
import '../../../../core/utils/result.dart';
import '../../domain/repositories/scanner_repository.dart';

/// Implementation of [DocumentScannerRepository] consuming [DocumentScannerService] and [GalleryService].
class DocumentScannerRepositoryImpl implements DocumentScannerRepository {
  const DocumentScannerRepositoryImpl({
    required this.scannerService,
    required this.galleryService,
  });

  final DocumentScannerService scannerService;
  final GalleryService galleryService;

  @override
  Future<Result<bool>> requestCameraPermission() async {
    try {
      final granted = await scannerService.requestPermission();
      if (!granted) {
        return const Result.failure(
          PermissionFailure('Camera permission was denied.'),
        );
      }
      return Result.success(granted);
    } catch (e) {
      return Result.failure(
        PermissionFailure('Failed to request camera permission: $e'),
      );
    }
  }

  @override
  Future<Result<void>> initializeScanner() async {
    try {
      await scannerService.initialize();
      return const Result.success(null);
    } on PermissionException catch (e) {
      return Result.failure(PermissionFailure(e.message));
    } on AppException catch (e) {
      return Result.failure(ScannerFailure(e.message));
    } catch (e) {
      return Result.failure(ScannerFailure('Failed to initialize camera: $e'));
    }
  }

  @override
  Widget buildCameraPreview() {
    return scannerService.buildPreview();
  }

  @override
  Stream<DocumentCornerPoints?> get detectedCorners =>
      scannerService.detectedCornersStream;

  @override
  Stream<DocumentDetectionResult> get detectionStream =>
      scannerService.detectionStream;

  @override
  DocumentCornerPoints? get currentCorners => scannerService.currentCorners;

  @override
  DetectionState get currentDetectionState =>
      scannerService.currentDetectionState;

  @override
  Future<Result<String>> captureDocument() async {
    try {
      final path = await scannerService.captureDocument();
      if (path == null || path.isEmpty) {
        return const Result.failure(ScannerFailure('No image was captured.'));
      }
      return Result.success(path);
    } on AppException catch (e) {
      return Result.failure(ScannerFailure(e.message));
    } catch (e) {
      return Result.failure(ScannerFailure('Failed to capture photo: $e'));
    }
  }

  @override
  Future<Result<bool>> toggleFlash() async {
    try {
      final state = await scannerService.toggleFlash();
      return Result.success(state);
    } catch (e) {
      return Result.failure(ScannerFailure('Failed to toggle flash: $e'));
    }
  }

  @override
  bool get isFlashOn => scannerService.isFlashOn;

  @override
  Future<void> releaseScanner() async {
    await scannerService.dispose();
  }

  @override
  Future<List<String>> scanDocuments() async {
    return await scannerService.scanDocuments();
  }

  @override
  Future<List<String>> importFromGallery() async {
    return await galleryService.pickMultipleImages();
  }
}

/// Backward compatibility alias for [DocumentScannerRepositoryImpl].
typedef ScannerRepositoryImpl = DocumentScannerRepositoryImpl;
