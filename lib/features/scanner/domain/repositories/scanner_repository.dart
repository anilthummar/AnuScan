import 'package:flutter/widgets.dart';
import '../../../../core/services/document_scanner_service.dart';
import '../../../../core/services/image_processing_service.dart';
import '../../../../core/utils/result.dart';

/// Repository contract for capturing and importing document pages.
abstract class DocumentScannerRepository {
  /// Checks and requests device camera permission.
  Future<Result<bool>> requestCameraPermission();

  /// Initializes the camera hardware for scanning.
  Future<Result<void>> initializeScanner();

  /// Builds the camera viewfinder preview widget.
  Widget buildCameraPreview();

  /// Stream of real-time detected corners of a document.
  Stream<DocumentCornerPoints?> get detectedCorners;

  /// Stream of real-time detection results including guidance state.
  Stream<DocumentDetectionResult> get detectionStream;

  /// Current detected corners if available.
  DocumentCornerPoints? get currentCorners;

  /// Current detection guidance state.
  DetectionState get currentDetectionState;

  /// Captures a high-resolution photograph of the document.
  Future<Result<String>> captureDocument();

  /// Toggles camera flash torch on or off.
  Future<Result<bool>> toggleFlash();

  /// Flash state.
  bool get isFlashOn;

  /// Releases camera hardware and listeners.
  Future<void> releaseScanner();

  /// Launches batch native camera scanner.
  Future<List<String>> scanDocuments();

  /// Launches gallery picker to import one or more images from device storage.
  Future<List<String>> importFromGallery();
}

/// Backward compatibility alias for [DocumentScannerRepository].
typedef ScannerRepository = DocumentScannerRepository;
