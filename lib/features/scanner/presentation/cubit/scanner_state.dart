import 'package:equatable/equatable.dart';
import '../../../../core/services/document_scanner_service.dart';
import '../../../../core/services/image_processing_service.dart';

/// Base class for all scanner state machine states.
sealed class ScannerState extends Equatable {
  const ScannerState();

  @override
  List<Object?> get props => [];
}

/// Initial dormant state before camera initialization.
class ScannerInitial extends ScannerState {
  const ScannerInitial();
}

/// Camera hardware is being checked for permissions and initialized.
class ScannerInitializing extends ScannerState {
  const ScannerInitializing();
}

/// Camera preview is active, hardware is ready, no document yet locked.
class ScannerReady extends ScannerState {
  const ScannerReady({
    this.isFlashOn = false,
    this.autoCapture = false,
    this.scannedPagesCount = 0,
  });

  final bool isFlashOn;
  final bool autoCapture;
  final int scannedPagesCount;

  @override
  List<Object?> get props => [isFlashOn, autoCapture, scannedPagesCount];
}

/// Document rectangle and corners have been detected in the camera preview.
class ScannerDetecting extends ScannerState {
  const ScannerDetecting({
    required this.corners,
    this.detectionState = DetectionState.detected,
    this.isFlashOn = false,
    this.autoCapture = false,
    this.scannedPagesCount = 0,
  });

  final DocumentCornerPoints corners;
  final DetectionState detectionState;
  final bool isFlashOn;
  final bool autoCapture;
  final int scannedPagesCount;

  @override
  List<Object?> get props => [
    corners,
    detectionState,
    isFlashOn,
    autoCapture,
    scannedPagesCount,
  ];
}

/// Shutter triggered, high-resolution picture being taken by sensor.
class ScannerCapturing extends ScannerState {
  const ScannerCapturing({this.corners, this.scannedPagesCount = 0});

  final DocumentCornerPoints? corners;
  final int scannedPagesCount;

  @override
  List<Object?> get props => [corners, scannedPagesCount];
}

/// Image captured, staging and preparing high-resolution document file.
class ScannerProcessing extends ScannerState {
  const ScannerProcessing({
    required this.rawImagePath,
    this.corners,
    this.scannedPagesCount = 0,
    this.statusMessage = 'Processing document...',
  });

  final String rawImagePath;
  final DocumentCornerPoints? corners;
  final int scannedPagesCount;
  final String statusMessage;

  @override
  List<Object?> get props => [
    rawImagePath,
    corners,
    scannedPagesCount,
    statusMessage,
  ];
}

/// Reviewing captured page with KEEP or RETAKE options.
class ScannerReviewing extends ScannerState {
  const ScannerReviewing({
    required this.capturedImagePath,
    this.corners,
    this.scannedPagesCount = 0,
    this.autoCapture = false,
  });

  final String capturedImagePath;
  final DocumentCornerPoints? corners;
  final int scannedPagesCount;
  final bool autoCapture;

  @override
  List<Object?> get props => [
    capturedImagePath,
    corners,
    scannedPagesCount,
    autoCapture,
  ];
}

/// Document capture succeeded, delivering captured image file paths.
class ScannerSuccess extends ScannerState {
  const ScannerSuccess(this.imagePaths, {this.detectedCorners});

  final List<String> imagePaths;
  final DocumentCornerPoints? detectedCorners;

  @override
  List<Object?> get props => [imagePaths, detectedCorners];
}

/// Error or permission failure encountered during scanning flow.
class ScannerFailure extends ScannerState {
  const ScannerFailure({
    required this.message,
    this.isPermissionDenied = false,
  });

  final String message;
  final bool isPermissionDenied;

  @override
  List<Object?> get props => [message, isPermissionDenied];
}
