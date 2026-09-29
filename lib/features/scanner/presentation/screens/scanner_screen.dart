import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/document_scanner_service.dart';
import '../../../../core/services/file_storage_service.dart';
import '../../../../core/services/security_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/repositories/scanner_repository.dart';
import '../../domain/usecases/import_gallery_usecase.dart';
import '../../domain/usecases/scan_document_usecase.dart';
import '../../domain/usecases/scan_documents_usecase.dart';
import '../cubit/scanner_cubit.dart';
import '../cubit/scanner_state.dart';
import '../widgets/document_corner_overlay.dart';

/// Screen managing device camera preview, real-time document boundary detection,
/// auto & manual high-quality capture, keep/retake reviewing, and multi-page scanning.
class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key, this.customCubit});

  final ScannerCubit? customCubit;

  @override
  Widget build(BuildContext context) {
    if (customCubit != null) {
      return BlocProvider<ScannerCubit>.value(
        value: customCubit!,
        child: const _ScannerView(),
      );
    }

    return BlocProvider<ScannerCubit>(
      create: (context) {
        final cubit = ScannerCubit(
          scannerRepository: sl<DocumentScannerRepository>(),
          scanDocumentUseCase: sl<ScanDocumentUseCase>(),
          scanDocumentsUseCase: sl<ScanDocumentsUseCase>(),
          importGalleryUseCase: sl<ImportGalleryUseCase>(),
          fileStorageService: sl<FileStorageService>(),
        );
        cubit.initializeCamera();
        return cubit;
      },
      child: const _ScannerView(),
    );
  }
}

class _ScannerView extends StatefulWidget {
  const _ScannerView();

  @override
  State<_ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<_ScannerView>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (sl.isRegistered<SecurityService>()) {
      sl<SecurityService>().setTransientActivityActive(true);
    }
  }

  @override
  void dispose() {
    if (sl.isRegistered<SecurityService>()) {
      sl<SecurityService>().setTransientActivityActive(false);
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final cubit = context.read<ScannerCubit>();
    if (state == AppLifecycleState.paused) {
      // Release camera hardware when app is backgrounded to avoid OS sensor lock.
      if (cubit.state is ScannerReady ||
          cubit.state is ScannerDetecting ||
          cubit.state is ScannerInitializing) {
        cubit.cancel();
      }
    } else if (state == AppLifecycleState.resumed) {
      // Re-initialize camera if it was released or previously failed.
      if (cubit.state is ScannerInitial || cubit.state is ScannerFailure) {
        cubit.initializeCamera();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ScannerCubit, ScannerState>(
      listener: (context, state) {
        if (state is ScannerSuccess) {
          // Return all captured image paths to caller and release camera
          Navigator.pop(context, state.imagePaths);
        }
      },
      builder: (context, state) {
        final cubit = context.read<ScannerCubit>();

        // 1. Permission Denied or Initialization Failure
        if (state is ScannerFailure) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              title: const Text('Camera Scanner'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32.0,
                    vertical: 20.0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        state.isPermissionDenied
                            ? Icons.no_photography_outlined
                            : Icons.error_outline,
                        size: 64,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        state.isPermissionDenied
                            ? 'Camera Permission Required'
                            : 'Camera Error',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        state.message,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      if (state.isPermissionDenied) ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(200, 48),
                          ),
                          onPressed: () => openAppSettings(),
                          icon: const Icon(Icons.settings),
                          label: const Text('Open App Settings'),
                        ),
                        const SizedBox(height: 12),
                      ],
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white30),
                          minimumSize: const Size(200, 48),
                        ),
                        onPressed: () => cubit.initializeCamera(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        // 2. Initializing State
        if (state is ScannerInitial || state is ScannerInitializing) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text(
                    'Opening camera...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        // 3. Reviewing Just-Captured Page (Keep / Retake Flow - 10.18)
        if (state is ScannerReviewing) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: Text(
                'Review Scan (Page ${state.scannedPagesCount + 1})',
                style: const TextStyle(fontSize: 18),
              ),
              automaticallyImplyLeading: false,
            ),
            body: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(state.capturedImagePath),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 16.0,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: const Icon(Icons.refresh),
                            label: const Text(
                              'Retake',
                              style: TextStyle(fontSize: 16),
                            ),
                            onPressed: () =>
                                cubit.retakePage(state.capturedImagePath),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: const Icon(Icons.check),
                            label: const Text(
                              'Keep',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () =>
                                cubit.keepPage(state.capturedImagePath),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // 4. Active Camera Viewfinder View
        final bool isFlashOn = switch (state) {
          ScannerReady(:final isFlashOn) => isFlashOn,
          ScannerDetecting(:final isFlashOn) => isFlashOn,
          _ => false,
        };

        final bool isAutoCapture = switch (state) {
          ScannerReady(:final autoCapture) => autoCapture,
          ScannerDetecting(:final autoCapture) => autoCapture,
          _ => false,
        };

        final int pageCount = switch (state) {
          ScannerReady(:final scannedPagesCount) => scannedPagesCount,
          ScannerDetecting(:final scannedPagesCount) => scannedPagesCount,
          ScannerCapturing(:final scannedPagesCount) => scannedPagesCount,
          ScannerProcessing(:final scannedPagesCount) => scannedPagesCount,
          _ => 0,
        };

        final DetectionState detectionState = switch (state) {
          ScannerDetecting(:final detectionState) => detectionState,
          _ => DetectionState.searching,
        };

        final bool isBusy =
            state is ScannerCapturing || state is ScannerProcessing;

        final Color guidanceColor = switch (detectionState) {
          DetectionState.ready => AppColors.success.withValues(alpha: 0.9),
          DetectionState.holdSteady => AppColors.primaryLight.withValues(
            alpha: 0.9,
          ),
          DetectionState.detected => AppColors.primary.withValues(alpha: 0.85),
          DetectionState.moveCloser || DetectionState.moveFarther =>
            AppColors.warning.withValues(alpha: 0.9),
          DetectionState.searching => Colors.black54,
        };

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Camera Preview stream
              cubit.scannerRepository.buildCameraPreview(),

              // Detected document corners overlay with adaptive coloring
              if (state is ScannerDetecting)
                DocumentCornerOverlay(
                  corners: state.corners,
                  detectionState: detectionState,
                ),

              // Top Controls Header
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Close / Cancel Button
                        IconButton.filledTonal(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black45,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            cubit.cancel();
                            Navigator.pop(context);
                          },
                        ),

                        // Guidance Status Pill (10.2)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: guidanceColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                detectionState == DetectionState.ready
                                    ? Icons.check_circle
                                    : (detectionState ==
                                              DetectionState.holdSteady
                                          ? Icons.hourglass_top
                                          : Icons.crop_free),
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                detectionState.guidanceMessage,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Auto / Manual Capture Mode Toggle (10.3)
                            IconButton.filledTonal(
                              tooltip: isAutoCapture
                                  ? 'Auto Capture: ON'
                                  : 'Auto Capture: OFF',
                              style: IconButton.styleFrom(
                                backgroundColor: isAutoCapture
                                    ? AppColors.primary
                                    : Colors.black45,
                                foregroundColor: Colors.white,
                              ),
                              icon: Icon(
                                isAutoCapture
                                    ? Icons.auto_awesome
                                    : Icons.touch_app,
                                size: 20,
                              ),
                              onPressed: isBusy
                                  ? null
                                  : () => cubit.toggleAutoCapture(),
                            ),
                            const SizedBox(width: 6),

                            // Flash Toggle
                            IconButton.filledTonal(
                              style: IconButton.styleFrom(
                                backgroundColor: isFlashOn
                                    ? AppColors.warning.withValues(alpha: 0.9)
                                    : Colors.black45,
                                foregroundColor: isFlashOn
                                    ? Colors.black
                                    : Colors.white,
                              ),
                              icon: Icon(
                                isFlashOn ? Icons.flash_on : Icons.flash_off,
                              ),
                              onPressed: isBusy
                                  ? null
                                  : () => cubit.toggleFlash(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Shutter & Multi-Page Scanning Controls (10.19)
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Multi-Page Session Status & Action Bar
                        if (pageCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: 16.0,
                              left: 20.0,
                              right: 20.0,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$pageCount page${pageCount == 1 ? '' : 's'} scanned',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextButton.icon(
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.white70,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.photo_library_outlined,
                                          size: 18,
                                        ),
                                        label: const Text('+ Gallery'),
                                        onPressed: isBusy
                                            ? null
                                            : () => cubit.importFromGallery(),
                                      ),
                                      const SizedBox(width: 4),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 8,
                                          ),
                                          minimumSize: Size.zero,
                                        ),
                                        onPressed: isBusy
                                            ? null
                                            : () => cubit.finishScanning(),
                                        child: const Text(
                                          'Done',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                        Text(
                          isAutoCapture
                              ? 'Auto-capture active • Hold steady when green'
                              : (pageCount > 0
                                    ? '+ Scan next page or tap Done'
                                    : 'Hold steady for crisp text capture'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            shadows: [
                              Shadow(color: Colors.black87, blurRadius: 4),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Shutter Capture Button
                        GestureDetector(
                          onTap: isBusy ? null : () => cubit.captureDocument(),
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              color: Colors.white24,
                            ),
                            child: Center(
                              child: isBusy
                                  ? const SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 3,
                                      ),
                                    )
                                  : Container(
                                      width: 60,
                                      height: 60,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
