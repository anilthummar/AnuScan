import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/scanned_page.dart';
import 'document_page_card.dart';
import 'pages_ready_banner.dart';

/// Reorderable list / grid of scanned pages matching the AnuScan reference design.
///
/// Supports drag-to-reorder, card controls (crop, rotate, delete, duplicate),
/// and renders the "All Pages Ready!" banner at the bottom of the list.
class ReorderablePageGrid extends StatelessWidget {
  const ReorderablePageGrid({
    super.key,
    required this.pages,
    required this.onReorder,
    required this.onTapPage,
    required this.onRotatePage,
    required this.onDeletePage,
    this.onCropPage,
    this.onDuplicatePage,
    this.isGridMode = false,
  });

  final List<ScannedPage> pages;
  final void Function(int oldIndex, int newIndex) onReorder;
  final ValueChanged<int> onTapPage;
  final ValueChanged<int> onRotatePage;
  final ValueChanged<int> onDeletePage;
  final ValueChanged<int>? onCropPage;
  final ValueChanged<int>? onDuplicatePage;
  final bool isGridMode;

  @override
  Widget build(BuildContext context) {
    if (pages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  size: 40,
                  color: Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No pages in this document yet',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap the buttons below to scan or import pages',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (isGridMode) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: pages.length,
        itemBuilder: (context, index) {
          final page = pages[index];
          return _GridPageCard(
            key: ValueKey(page.id),
            page: page,
            index: index,
            totalPages: pages.length,
            onTap: () => onTapPage(index),
            onRotate: () => onRotatePage(index),
            onDelete: () => onDeletePage(index),
          );
        },
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: pages.length,
      onReorderItem: onReorder,
      footer: pages.isNotEmpty ? const PagesReadyBanner() : null,
      itemBuilder: (context, index) {
        final page = pages[index];
        return DocumentPageCard(
          key: ValueKey(page.id),
          page: page,
          index: index,
          totalPages: pages.length,
          onTap: () => onTapPage(index),
          onCrop: () => onCropPage != null ? onCropPage!(index) : onTapPage(index),
          onRotate: () => onRotatePage(index),
          onDelete: () => onDeletePage(index),
          onDuplicate:
              onDuplicatePage != null ? () => onDuplicatePage!(index) : null,
        );
      },
    );
  }
}

class _GridPageCard extends StatelessWidget {
  const _GridPageCard({
    super.key,
    required this.page,
    required this.index,
    required this.totalPages,
    required this.onTap,
    required this.onRotate,
    required this.onDelete,
  });

  final ScannedPage page;
  final int index;
  final int totalPages;
  final VoidCallback onTap;
  final VoidCallback onRotate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(page.processedImagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Center(child: Icon(Icons.broken_image)),
                  ),
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${index + 1}/$totalPages',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Page ${index + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: onRotate,
                    child: const Icon(
                      Icons.rotate_right,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onDelete,
                    child: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
