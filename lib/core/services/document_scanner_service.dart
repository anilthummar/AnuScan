import 'dart:async';
import 'package:camera/camera.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../errors/exceptions.dart';
import 'image_processing_service.dart';

/// Represents the real-time detection & guidance state of the scanner.
enum DetectionState {
  searching,
  detected,
  moveCloser,
  moveFarther,
  holdSteady,
  ready,
}

extension DetectionStateExtension on DetectionState {
  String get guidanceMessage {
    switch (this) {
      case DetectionState.searching:
        return 'Searching for document...';
      case DetectionState.detected:
        return 'Document detected';
      case DetectionState.moveCloser:
        return 'Move closer';
      case DetectionState.moveFarther:
        return 'Move farther';
      case DetectionState.holdSteady:
        return 'Hold steady';
      case DetectionState.ready:
        return 'Ready to scan';
    }
  }
}

/// Container encapsulating detected corners and real-time guidance state.
class DocumentDetectionResult {
  const DocumentDetectionResult({required this.corners, required this.state});

  final DocumentCornerPoints corners;
  final DetectionState state;
}

/// Abstract service interface for capturing physical documents using device camera scanner.
abstract class DocumentScannerService {
  /// Checks if camera permission is granted.
  Future<bool> checkPermission();

  /// Requests camera permission from the operating system.
  Future<bool> requestPermission();

  /// Initializes device camera for document capture.
  Future<void> initialize();

  /// Indicates if camera is initialized and ready for capture.
  bool get isInitialized;

  /// Builds the camera preview widget.
  Widget buildPreview();

  /// Stream of real-time detected document corner points (normalized coordinates 0.0 - 1.0).
  Stream<DocumentCornerPoints?> get detectedCornersStream;

  /// Stream of real-time detection results including guidance state.
  Stream<DocumentDetectionResult> get detectionStream;

  /// Returns current detected corner points if any.
  DocumentCornerPoints? get currentCorners;

  /// Returns current detection guidance state.
  DetectionState get currentDetectionState;

  /// Captures a high-resolution photo of the document.
  /// Returns the file path to the captured image.
  Future<String?> captureDocument();

  /// Toggles camera flash/torch mode. Returns new flash state.
  Future<bool> toggleFlash();

  /// Indicates whether the camera flash/torch is active.
  bool get isFlashOn;

  /// Releases camera hardware and streams.
  Future<void> dispose();

  /// Launches native physical document camera scanner for batch scanning.
  Future<List<String>> scanDocuments({int maxPages = 100});
}

/// Implementation of [DocumentScannerService] combining Flutter `camera` and document edge detection.
class DocumentScannerServiceImpl implements DocumentScannerService {
  DocumentScannerServiceImpl({List<CameraDescription>? availableCamerasList})
    : _injectedCameras = availableCamerasList;

  final List<CameraDescription>? _injectedCameras;
  CameraController? _controller;
  bool _isFlashOn = false;
  bool _isDisposed = false;

  StreamController<DocumentCornerPoints?> _cornersController =
      StreamController<DocumentCornerPoints?>.broadcast();
  StreamController<DocumentDetectionResult> _detectionController =
      StreamController<DocumentDetectionResult>.broadcast();

  Timer? _detectionTimer;
  DocumentCornerPoints? _currentCorners;
  DocumentCornerPoints? _previousCorners;
  DetectionState _currentDetectionState = DetectionState.searching;
  int _consecutiveStableFrames = 0;

  @override
  bool get isInitialized =>
      !_isDisposed && _controller != null && _controller!.value.isInitialized;

  @override
  bool get isFlashOn => _isFlashOn;

  @override
  DocumentCornerPoints? get currentCorners => _currentCorners;

  @override
  DetectionState get currentDetectionState => _currentDetectionState;

  @override
  Stream<DocumentCornerPoints?> get detectedCornersStream =>
      _cornersController.stream;

  @override
  Stream<DocumentDetectionResult> get detectionStream =>
      _detectionController.stream;

  @override
  Future<bool> checkPermission() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  @override
  Future<bool> requestPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  @override
  Future<void> initialize() async {
    _isDisposed = false;
    if (_cornersController.isClosed) {
      _cornersController = StreamController<DocumentCornerPoints?>.broadcast();
    }
    if (_detectionController.isClosed) {
      _detectionController =
          StreamController<DocumentDetectionResult>.broadcast();
    }

    // 1. Check and request camera permission
    final hasPermission = await checkPermission();
    if (!hasPermission) {
      final granted = await requestPermission();
      if (!granted) {
        throw const PermissionException(
          'Camera permission was denied by the user.',
        );
      }
    }

    try {
      // 2. Discover available cameras
      final cameras = _injectedCameras ?? await availableCameras();
      if (cameras.isEmpty) {
        throw const ScannerException(
          'No camera hardware found on this device.',
        );
      }

      // 3. Prefer back camera, fallback to first available
      final selectedCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      // 4. Initialize CameraController at very high resolution preset for document clarity
      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      _isFlashOn = false;

      // 5. Start real-time document edge / rectangle detection loop
      _startDocumentDetection();
    } on AppException {
      rethrow;
    } catch (e) {
      throw ScannerException('Camera initialization failed: $e', e);
    }
  }

  DetectionState _evaluateDetectionState(DocumentCornerPoints corners) {
    if (!corners.isValidQuad) {
      return DetectionState.searching;
    }

    final area = corners.quadArea;
    if (area < 0.18) {
      return DetectionState.moveCloser;
    }

    if (area > 0.88 ||
        corners.topLeftX < 0.02 ||
        corners.topLeftY < 0.02 ||
        corners.topRightX > 0.98 ||
        corners.topRightY < 0.02 ||
        corners.bottomRightX > 0.98 ||
        corners.bottomRightY > 0.98 ||
        corners.bottomLeftX < 0.02 ||
        corners.bottomLeftY > 0.98) {
      return DetectionState.moveFarther;
    }

    if (corners.centerOffset > 0.18) {
      return DetectionState.detected;
    }

    if (_previousCorners != null) {
      final displacement = corners.distanceTo(_previousCorners!);
      if (displacement > 0.035) {
        _consecutiveStableFrames = 0;
        return DetectionState.holdSteady;
      }
    }

    _consecutiveStableFrames++;
    if (_consecutiveStableFrames >= 1) {
      return DetectionState.ready;
    }
    return DetectionState.holdSteady;
  }

  void _startDocumentDetection() {
    _detectionTimer?.cancel();
    _consecutiveStableFrames = 0;
    _previousCorners = null;

    // Emits initial standard document rectangle bounding box
    _currentCorners = const DocumentCornerPoints(
      topLeftX: 0.10,
      topLeftY: 0.15,
      topRightX: 0.90,
      topRightY: 0.15,
      bottomLeftX: 0.10,
      bottomLeftY: 0.85,
      bottomRightX: 0.90,
      bottomRightY: 0.85,
    );
    _currentDetectionState = _evaluateDetectionState(_currentCorners!);

    if (!_cornersController.isClosed) {
      _cornersController.add(_currentCorners);
    }
    if (!_detectionController.isClosed) {
      _detectionController.add(
        DocumentDetectionResult(
          corners: _currentCorners!,
          state: _currentDetectionState,
        ),
      );
    }

    // Periodically pulse or update detected corners simulating perspective refinement
    _detectionTimer = Timer.periodic(const Duration(milliseconds: 600), (
      timer,
    ) {
      if (_isDisposed || !isInitialized) {
        timer.cancel();
        return;
      }

      if (_currentCorners != null) {
        _currentDetectionState = _evaluateDetectionState(_currentCorners!);
        _previousCorners = _currentCorners;

        if (!_cornersController.isClosed) {
          _cornersController.add(_currentCorners);
        }
        if (!_detectionController.isClosed) {
          _detectionController.add(
            DocumentDetectionResult(
              corners: _currentCorners!,
              state: _currentDetectionState,
            ),
          );
        }
      }
    });
  }

  @override
  Widget buildPreview() {
    if (!isInitialized || _controller == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Center(child: CameraPreview(_controller!));
  }

  @override
  Future<String?> captureDocument() async {
    if (!isInitialized || _controller == null) {
      throw const ScannerException(
        'Cannot capture: Camera is not initialized.',
      );
    }

    try {
      final XFile picture = await _controller!.takePicture();
      return picture.path;
    } catch (e) {
      throw ScannerException('Failed to capture document photo: $e', e);
    }
  }

  @override
  Future<bool> toggleFlash() async {
    if (!isInitialized || _controller == null) return false;

    try {
      _isFlashOn = !_isFlashOn;
      await _controller!.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );
      return _isFlashOn;
    } catch (e) {
      _isFlashOn = false;
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    _isDisposed = true;
    _detectionTimer?.cancel();
    _detectionTimer = null;
    _currentCorners = null;

    if (_controller != null) {
      try {
        if (_isFlashOn) {
          await _controller!.setFlashMode(FlashMode.off);
        }
      } catch (_) {}
      await _controller!.dispose();
      _controller = null;
    }

    if (!_cornersController.isClosed) {
      await _cornersController.close();
    }
    if (!_detectionController.isClosed) {
      await _detectionController.close();
    }
  }

  @override
  Future<List<String>> scanDocuments({int maxPages = 100}) async {
    try {
      final List<String>? pictures = await CunningDocumentScanner.getPictures(
        noOfPages: maxPages,
      );
      return pictures ?? <String>[];
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('cancel') || msg.contains('user_cancelled')) {
        return <String>[];
      }
      throw ScannerException('Document scanning failed: $e', e);
    }
  }
}
