import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/services/image_processing_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/scanned_page.dart';

/// Reorderable list of scanned pages with individual card controls.
class ReorderablePageGrid extends StatelessWidget {
  const ReorderablePageGrid({
    super.key,
    required this.pages,
    required this.onReorder,
    required this.onTapPage,
    required this.onRotatePage,
    required this.onDeletePage,
  });

  final List<ScannedPage> pages;
  final void Function(int oldIndex, int newIndex) onReorder;
  final ValueChanged<int> onTapPage;
  final ValueChanged<int> onRotatePage;
  final ValueChanged<int> onDeletePage;

  @override
  Widget build(BuildContext context) {
    if (pages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: AppColors.textTertiaryLight),
            const SizedBox(height: 16),
            const Text(
              'No pages in this document yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the buttons below to scan or import pages',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: pages.length,
      onReorderItem: onReorder,
      itemBuilder: (context, index) {
        final page = pages[index];
        return _PageCard(
          key: ValueKey(page.id),
          page: page,
          index: index,
          onTap: () => onTapPage(index),
          onRotate: () => onRotatePage(index),
          onDelete: () => onDeletePage(index),
        );
      },
    );
  }
}

class _PageCard extends StatelessWidget {
  const _PageCard({
    super.key,
    required this.page,
    required this.index,
    required this.onTap,
    required this.onRotate,
    required this.onDelete,
  });

  final ScannedPage page;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onRotate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Page Number Badge & Drag handle indicator
              Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Icon(
                    Icons.drag_handle,
                    color: AppColors.textTertiaryLight,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Page Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 70,
                  height: 95,
                  color: Colors.grey.shade200,
                  child: Image.file(
                    File(page.processedImagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Page Details & Quick Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Page ${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Filter: ${page.filterType.displayName}',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                    if (page.rotationDegrees > 0)
                      Text(
                        'Rotated: ${page.rotationDegrees}°',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                        ),
                      ),
                  ],
                ),
              ),

              // Action Buttons: Edit, Rotate, Delete
              IconButton(
                tooltip: 'Edit Page',
                icon: const Icon(Icons.tune, color: AppColors.primary),
                onPressed: onTap,
              ),
              IconButton(
                tooltip: 'Rotate 90°',
                icon: const Icon(Icons.rotate_right),
                onPressed: onRotate,
              ),
              IconButton(
                tooltip: 'Delete Page',
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
