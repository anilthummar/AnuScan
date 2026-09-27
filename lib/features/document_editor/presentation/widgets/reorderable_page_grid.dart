import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/services/image_processing_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/scanned_page.dart';

/// Reorderable list of scanned pages with individual card controls and drag-and-drop.
class ReorderablePageGrid extends StatelessWidget {
  const ReorderablePageGrid({
    super.key,
    required this.pages,
    required this.onReorder,
    required this.onTapPage,
    required this.onRotatePage,
    required this.onDeletePage,
    this.onDuplicatePage,
  });

  final List<ScannedPage> pages;
  final void Function(int oldIndex, int newIndex) onReorder;
  final ValueChanged<int> onTapPage;
  final ValueChanged<int> onRotatePage;
  final ValueChanged<int> onDeletePage;
  final ValueChanged<int>? onDuplicatePage;

  @override
  Widget build(BuildContext context) {
    if (pages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.description_outlined,
              size: 64,
              color: AppColors.textTertiaryLight,
            ),
            const SizedBox(height: 16),
            const Text(
              'No pages in this document yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the buttons below to scan or import pages',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryLight,
              ),
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
          onDuplicate: onDuplicatePage != null
              ? () => onDuplicatePage!(index)
              : null,
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
    this.onDuplicate,
  });

  final ScannedPage page;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onRotate;
  final VoidCallback onDelete;
  final VoidCallback? onDuplicate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.borderLight.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Page Number Badge & Drag handle indicator: [ Page 1 ]
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Page ${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Icon(
                    Icons.drag_handle,
                    color: AppColors.textTertiaryLight,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(width: 12),

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
                    cacheWidth: 150,
                    cacheHeight: 200,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.broken_image),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Page Details & Quick Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '[ Page ${index + 1} ]',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Filter: ${page.filterType.displayName}',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                    if (page.rotationDegrees > 0)
                      Text(
                        'Rotated: ${page.rotationDegrees}°',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Action Buttons: Edit, Duplicate, Rotate, Delete
              IconButton(
                tooltip: 'Edit Page',
                icon: const Icon(
                  Icons.tune,
                  color: AppColors.primary,
                  size: 20,
                ),
                onPressed: onTap,
              ),
              if (onDuplicate != null)
                IconButton(
                  tooltip: 'Duplicate Page',
                  icon: const Icon(Icons.copy_outlined, size: 20),
                  onPressed: onDuplicate,
                ),
              IconButton(
                tooltip: 'Rotate 90°',
                icon: const Icon(Icons.rotate_right, size: 22),
                onPressed: onRotate,
              ),
              IconButton(
                tooltip: 'Delete Page',
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                  size: 20,
                ),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
