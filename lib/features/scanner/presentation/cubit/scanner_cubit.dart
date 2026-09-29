import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/failures.dart' hide ScannerFailure;
import '../../../../core/services/document_scanner_service.dart';
import '../../../../core/services/file_storage_service.dart';
import '../../../../core/services/image_processing_service.dart';
import '../../domain/repositories/scanner_repository.dart';
import '../../domain/usecases/import_gallery_usecase.dart';
import '../../domain/usecases/scan_document_usecase.dart';
import '../../domain/usecases/scan_documents_usecase.dart';
import 'scanner_state.dart';

/// Cubit managing camera hardware lifecycle, real-time edge detection, auto/manual capture,
/// Keep / Retake reviewing, and multi-page document scanning sessions.
class ScannerCubit extends Cubit<ScannerState> {
  ScannerCubit({
    required this.scannerRepository,
    required this.scanDocumentUseCase,
    required this.scanDocumentsUseCase,
    required this.importGalleryUseCase,
    this.fileStorageService,
  }) : super(const ScannerInitial());

  final DocumentScannerRepository scannerRepository;
  final ScanDocumentUseCase scanDocumentUseCase;
  final ScanDocumentsUseCase scanDocumentsUseCase;
  final ImportGalleryUseCase importGalleryUseCase;
  final FileStorageService? fileStorageService;

  StreamSubscription<DocumentCornerPoints?>? _cornersSubscription;
  StreamSubscription<DocumentDetectionResult>? _detectionSubscription;

  final List<String> _capturedPages = [];
  List<String> get capturedPages => List.unmodifiable(_capturedPages);

  bool _autoCapture = false;
  bool get isAutoCaptureEnabled => _autoCapture;
  bool get autoCapture => _autoCapture;

  Timer? _autoCaptureTimer;
  Timer? _autoCaptureCooldown;
  bool _isCooldownActive = false;
  bool _isInitializingCamera = false;

  /// Starts the camera scanning workflow: requests permissions, initializes sensor,
  /// and listens to real-time detection results and corners.
  Future<void> initializeCamera() async {
    if (_isInitializingCamera) return;
    _isInitializingCamera = true;

    emit(const ScannerInitializing());
    _cornersSubscription?.cancel();
    _detectionSubscription?.cancel();
    _autoCaptureTimer?.cancel();
    _autoCaptureTimer = null;

    try {
      final result = await scannerRepository.initializeScanner();
      if (isClosed) return;
      result.fold(
      onFailure: (failure) {
        final isPermission = failure is PermissionFailure;
        emit(
          ScannerFailure(
            message: failure.message,
            isPermissionDenied: isPermission,
          ),
        );
      },
      onSuccess: (_) {
        emit(
          ScannerReady(
            isFlashOn: scannerRepository.isFlashOn,
            autoCapture: _autoCapture,
            scannedPagesCount: _capturedPages.length,
          ),
        );

        // Listen to enhanced detection stream
        _detectionSubscription = scannerRepository.detectionStream.listen((
          detectionResult,
        ) {
          if (isClosed) return;
          if (state is ScannerReady || state is ScannerDetecting) {
            emit(
              ScannerDetecting(
                corners: detectionResult.corners,
                detectionState: detectionResult.state,
                isFlashOn: scannerRepository.isFlashOn,
                autoCapture: _autoCapture,
                scannedPagesCount: _capturedPages.length,
              ),
            );

            // Auto-capture evaluation (10.3)
            if (_autoCapture && !_isCooldownActive) {
              if (detectionResult.state == DetectionState.ready) {
                _autoCaptureTimer ??= Timer(
                  const Duration(milliseconds: 1200),
                  () {
                    if (!isClosed &&
                        (state is ScannerReady || state is ScannerDetecting)) {
                      captureDocument();
                    }
                  },
                );
              } else {
                _autoCaptureTimer?.cancel();
                _autoCaptureTimer = null;
              }
            } else {
              _autoCaptureTimer?.cancel();
              _autoCaptureTimer = null;
            }
          }
        });

        // Fallback for mock repositories only implementing detectedCorners
        _cornersSubscription = scannerRepository.detectedCorners.listen((
          corners,
        ) {
          if (isClosed) return;
          if (corners != null &&
              (state is ScannerReady || state is ScannerDetecting)) {
            final currentState = state;
            if (currentState is! ScannerDetecting) {
              emit(
                ScannerDetecting(
                  corners: corners,
                  isFlashOn: scannerRepository.isFlashOn,
                  autoCapture: _autoCapture,
                  scannedPagesCount: _capturedPages.length,
                ),
              );
            }
          }
        });
      },
    );
  } finally {
    _isInitializingCamera = false;
  }
}

  /// Toggles between manual and auto-capture modes.
  void toggleAutoCapture() {
    _autoCapture = !_autoCapture;
    _autoCaptureTimer?.cancel();
    _autoCaptureTimer = null;

    final currentState = state;
    if (currentState is ScannerReady) {
      emit(
        ScannerReady(
          isFlashOn: currentState.isFlashOn,
          autoCapture: _autoCapture,
          scannedPagesCount: _capturedPages.length,
        ),
      );
    } else if (currentState is ScannerDetecting) {
      emit(
        ScannerDetecting(
          corners: currentState.corners,
          detectionState: currentState.detectionState,
          isFlashOn: currentState.isFlashOn,
          autoCapture: _autoCapture,
          scannedPagesCount: _capturedPages.length,
        ),
      );
    }
  }

  /// Captures the current document view at high resolution.
  Future<void> captureDocument() async {
    if (state is ScannerCapturing || state is ScannerProcessing) return;

    _autoCaptureTimer?.cancel();
    _autoCaptureTimer = null;

    DocumentCornerPoints? capturedCorners;
    final currentState = state;
    if (currentState is ScannerDetecting) {
      capturedCorners = currentState.corners;
    }

    emit(
      ScannerCapturing(
        corners: capturedCorners,
        scannedPagesCount: _capturedPages.length,
      ),
    );

    final result = await scanDocumentUseCase();
    result.fold(
      onFailure: (failure) {
        emit(ScannerFailure(message: failure.message));
      },
      onSuccess: (imagePath) {
        emit(
          ScannerProcessing(
            rawImagePath: imagePath,
            corners: capturedCorners,
            scannedPagesCount: _capturedPages.length,
            statusMessage: 'Preparing preview...',
          ),
        );

        // Activate auto-capture cooldown
        _isCooldownActive = true;
        _autoCaptureCooldown?.cancel();
        _autoCaptureCooldown = Timer(const Duration(milliseconds: 2500), () {
          _isCooldownActive = false;
        });

        // Present Keep / Retake reviewing screen
        emit(
          ScannerReviewing(
            capturedImagePath: imagePath,
            corners: capturedCorners,
            scannedPagesCount: _capturedPages.length,
            autoCapture: _autoCapture,
          ),
        );
      },
    );
  }

  /// Keeps the captured page and returns to active multi-page scanning.
  void keepPage(String imagePath) {
    if (!_capturedPages.contains(imagePath)) {
      _capturedPages.add(imagePath);
    }

    emit(
      ScannerReady(
        isFlashOn: scannerRepository.isFlashOn,
        autoCapture: _autoCapture,
        scannedPagesCount: _capturedPages.length,
      ),
    );
  }

  /// Discards the captured page, deletes the temp file, and resumes viewfinder.
  Future<void> retakePage(String imagePath) async {
    try {
      if (fileStorageService != null) {
        await fileStorageService!.deleteFile(imagePath);
      } else {
        final file = File(imagePath);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (_) {}

    emit(
      ScannerReady(
        isFlashOn: scannerRepository.isFlashOn,
        autoCapture: _autoCapture,
        scannedPagesCount: _capturedPages.length,
      ),
    );
  }

  /// Incorporates gallery image paths into the multi-page session.
  void addGalleryPages(List<String> paths) {
    _capturedPages.addAll(paths);
    emit(
      ScannerReady(
        isFlashOn: scannerRepository.isFlashOn,
        autoCapture: _autoCapture,
        scannedPagesCount: _capturedPages.length,
      ),
    );
  }

  /// Finishes the scanning session and delivers all accumulated pages.
  void finishScanning() {
    if (_capturedPages.isNotEmpty) {
      emit(ScannerSuccess(List.from(_capturedPages)));
    } else {
      emit(const ScannerInitial());
    }
  }

  /// Toggles camera flash torch on and off.
  Future<void> toggleFlash() async {
    final result = await scannerRepository.toggleFlash();
    result.fold(
      onFailure: (_) {},
      onSuccess: (newFlashOn) {
        final currentState = state;
        if (currentState is ScannerReady) {
          emit(
            ScannerReady(
              isFlashOn: newFlashOn,
              autoCapture: _autoCapture,
              scannedPagesCount: _capturedPages.length,
            ),
          );
        } else if (currentState is ScannerDetecting) {
          emit(
            ScannerDetecting(
              corners: currentState.corners,
              detectionState: currentState.detectionState,
              isFlashOn: newFlashOn,
              autoCapture: _autoCapture,
              scannedPagesCount: _capturedPages.length,
            ),
          );
        }
      },
    );
  }

  /// Batch camera scanning fallback.
  Future<void> scanWithCamera() async {
    emit(const ScannerInitializing());
    try {
      final paths = await scanDocumentsUseCase();
      if (paths.isEmpty) {
        emit(const ScannerInitial());
      } else {
        _capturedPages.addAll(paths);
        emit(ScannerSuccess(paths));
      }
    } catch (e) {
      emit(ScannerFailure(message: 'Camera scanning failed: $e'));
    }
  }

  /// Import images from photo gallery into the session.
  Future<void> importFromGallery() async {
    final isInLiveSession = state is ScannerReady || state is ScannerDetecting;
    if (!isInLiveSession) {
      emit(const ScannerInitializing());
    }
    try {
      final paths = await importGalleryUseCase();
      if (paths.isNotEmpty) {
        _capturedPages.addAll(paths);
        if (isInLiveSession) {
          emit(
            ScannerReady(
              isFlashOn: scannerRepository.isFlashOn,
              autoCapture: _autoCapture,
              scannedPagesCount: _capturedPages.length,
            ),
          );
        } else {
          emit(ScannerSuccess(paths));
        }
      } else {
        if (!isInLiveSession) {
          emit(const ScannerInitial());
        }
      }
    } catch (e) {
      emit(ScannerFailure(message: 'Gallery import failed: $e'));
    }
  }

  /// Releases camera hardware and resets state.
  Future<void> cancel() async {
    _cornersSubscription?.cancel();
    _cornersSubscription = null;
    _detectionSubscription?.cancel();
    _detectionSubscription = null;
    _autoCaptureTimer?.cancel();
    _autoCaptureTimer = null;
    _autoCaptureCooldown?.cancel();
    _autoCaptureCooldown = null;
    await scannerRepository.releaseScanner();
    if (!isClosed) {
      emit(const ScannerInitial());
    }
  }

  @override
  Future<void> close() async {
    _cornersSubscription?.cancel();
    _cornersSubscription = null;
    _detectionSubscription?.cancel();
    _detectionSubscription = null;
    _autoCaptureTimer?.cancel();
    _autoCaptureTimer = null;
    _autoCaptureCooldown?.cancel();
    _autoCaptureCooldown = null;
    await scannerRepository.releaseScanner();
    return super.close();
  }
}
