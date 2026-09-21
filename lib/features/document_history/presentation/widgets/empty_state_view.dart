import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Clean empty state placeholder when no documents have been scanned.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.onScanPressed,
    required this.onGalleryPressed,
  });

  final VoidCallback onScanPressed;
  final VoidCallback onGalleryPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.document_scanner,
                size: 52,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Documents Yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Scan physical documents using your device camera or import existing images from your gallery.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondaryLight,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Import Gallery'),
                  onPressed: onGalleryPressed,
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Scan Now'),
                  onPressed: onScanPressed,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
