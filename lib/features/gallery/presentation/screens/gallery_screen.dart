import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../document_editor/domain/entities/scanned_page.dart';
import '../../../document_editor/presentation/screens/document_editor_screen.dart';
import '../../domain/usecases/import_gallery_images_usecase.dart';
import '../cubit/gallery_cubit.dart';
import '../cubit/gallery_state.dart';

/// Screen allowing the user to select multiple images from the device gallery,
/// showing real-time pipeline processing progress, and handling permissions and errors.
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({
    super.key,
    this.documentId,
    this.startIndex = 0,
    this.autoPick = false,
  });

  final String? documentId;
  final int startIndex;
  final bool autoPick;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = GalleryCubit(
          importGalleryImagesUseCase: sl<ImportGalleryImagesUseCase>(),
        );
        if (autoPick) {
          final effectiveDocId = documentId ?? const Uuid().v4();
          cubit.pickAndProcessImages(
            documentId: effectiveDocId,
            startIndex: startIndex,
          );
        }
        return cubit;
      },
      child: _GalleryView(documentId: documentId, startIndex: startIndex),
    );
  }
}

class _GalleryView extends StatelessWidget {
  const _GalleryView({required this.documentId, required this.startIndex});

  final String? documentId;
  final int startIndex;

  void _onSuccess(BuildContext context, List<ScannedPage> pages) {
    // If popped back to an existing screen waiting for pages
    if (Navigator.canPop(context)) {
      Navigator.pop(context, pages);
    } else {
      // Or navigate directly to DocumentEditorScreen
      final docId =
          documentId ??
          (pages.isNotEmpty ? pages.first.documentId : const Uuid().v4());
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentEditorScreen(
            documentId: docId,
            initialTitle: 'Imported Document',
            initialImagePaths: pages.map((p) => p.originalImagePath).toList(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveDocId = documentId ?? const Uuid().v4();

    return BlocConsumer<GalleryCubit, GalleryState>(
      listener: (context, state) {
        if (state is GallerySuccess) {
          if (state.corruptedCount > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${state.corruptedCount} corrupted/unreadable file(s) skipped.',
                ),
                backgroundColor: AppColors.warning,
              ),
            );
          }
          _onSuccess(context, state.pages);
        } else if (state is GalleryFailure && !state.isPermissionDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<GalleryCubit>();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Gallery Import'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                cubit.cancel();
                Navigator.of(context).maybePop();
              },
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: _buildBody(context, state, cubit, effectiveDocId),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    GalleryState state,
    GalleryCubit cubit,
    String docId,
  ) {
    if (state is GalleryProcessing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: state.progress > 0 ? state.progress : null,
                strokeWidth: 6,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Importing Images (${state.current}/${state.total})',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: LinearProgressIndicator(
                value: state.progress > 0 ? state.progress : null,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              state.message ?? 'Preserving original quality...',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondaryLight,
              ),
            ),
            const Spacer(),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => cubit.cancel(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    }

    if (state is GalleryFailure && state.isPermissionDenied) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.no_photography_outlined,
                size: 48,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Photo Library Access Required',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'AnuScan needs access to your photos to import document images. Please enable access in your device settings.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondaryLight,
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                await openAppSettings();
              },
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    }

    // Default / Initial / Cancelled / Generic Failure state
    return Column(
      children: [
        const Spacer(),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.photo_library_outlined,
            size: 48,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Import from Gallery',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'Select one or multiple images from your photo library to assemble into your scanned document.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.textSecondaryLight),
        ),
        const SizedBox(height: 20),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.high_quality, size: 18, color: AppColors.primary),
            SizedBox(width: 6),
            Text(
              'Original resolution & quality preserved',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
        const Spacer(),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            cubit.pickAndProcessImages(
              documentId: docId,
              startIndex: startIndex,
            );
          },
          icon: const Icon(Icons.add_photo_alternate),
          label: const Text('Select Images'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            cubit.cancel();
            Navigator.of(context).maybePop();
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
