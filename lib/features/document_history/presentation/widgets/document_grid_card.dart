import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/file_utils.dart';
import '../../domain/entities/document_entity.dart';

class DocumentGridCard extends StatelessWidget {
  const DocumentGridCard({
    super.key,
    required this.document,
    required this.onTap,
    this.onOpen,
    required this.onShare,
    required this.onRename,
    required this.onDelete,
    this.onFavoriteToggle,
    this.onArchive,
    this.onMoveToFolder,
    this.onManageTags,
    this.onViewDetails,
    this.onPrivateToggle,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.onSelectToggle,
    this.onLongPress,
  });

  final DocumentEntity document;
  final VoidCallback onTap;
  final VoidCallback? onOpen;
  final VoidCallback onShare;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onArchive;
  final VoidCallback? onMoveToFolder;
  final VoidCallback? onManageTags;
  final VoidCallback? onViewDetails;
  final VoidCallback? onPrivateToggle;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onLongPress;

  String? _resolveThumbnailPath() {
    if (document.thumbnailPath != null &&
        document.thumbnailPath!.trim().isNotEmpty) {
      return document.thumbnailPath;
    }
    if (document.pages.isNotEmpty) {
      final first = document.pages.first;
      if (first.processedImagePath.trim().isNotEmpty) {
        return first.processedImagePath;
      }
      if (first.originalImagePath.trim().isNotEmpty) {
        return first.originalImagePath;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumbnail = _resolveThumbnailPath();

    return Card(
      margin: const EdgeInsets.all(6),
      elevation: isSelected ? 4 : 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? const BorderSide(color: AppColors.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: isSelectionMode ? onSelectToggle : (onOpen ?? onTap),
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail Stack
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: Colors.grey.shade100,
                    child: document.isPrivate
                        ? const Center(
                            child: Icon(
                              Icons.lock,
                              color: AppColors.primary,
                              size: 40,
                            ),
                          )
                        : (thumbnail != null
                            ? Image.file(
                                File(thumbnail),
                                fit: BoxFit.cover,
                                cacheWidth: 200,
                                cacheHeight: 250,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(
                                    Icons.picture_as_pdf,
                                    color: AppColors.primary,
                                    size: 40,
                                  ),
                                ),
                              )
                            : const Center(
                                child: Icon(
                                  Icons.picture_as_pdf,
                                  color: AppColors.primary,
                                  size: 40,
                                ),
                              )),
                  ),

                  // Private Lock Badge
                  if (!isSelectionMode && document.isPrivate)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),

                  // Selection Checkbox
                  if (isSelectionMode)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),

                  // Favorite Star Button
                  if (!isSelectionMode && onFavoriteToggle != null)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        icon: Icon(
                          document.isFavorite ? Icons.star : Icons.star_border,
                          color: document.isFavorite
                              ? Colors.amber
                              : Colors.black.withValues(alpha: 0.6),
                          size: 22,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: document.isFavorite
                            ? 'Remove from favorites'
                            : 'Add to favorites',
                        onPressed: onFavoriteToggle,
                      ),
                    ),
                ],
              ),
            ),

            // Metadata area
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          document.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isSelectionMode)
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          iconSize: 18,
                          icon: const Icon(
                            Icons.more_vert,
                            color: AppColors.textSecondaryLight,
                          ),
                          onSelected: (val) {
                            switch (val) {
                              case 'details':
                                onViewDetails?.call();
                                break;
                              case 'open':
                                (onOpen ?? onTap)();
                                break;
                              case 'share':
                                onShare();
                                break;
                              case 'rename':
                                onRename();
                                break;
                              case 'favorite':
                                onFavoriteToggle?.call();
                                break;
                              case 'archive':
                                onArchive?.call();
                                break;
                              case 'move':
                                onMoveToFolder?.call();
                                break;
                              case 'tags':
                                onManageTags?.call();
                                break;
                              case 'private':
                                onPrivateToggle?.call();
                                break;
                              case 'delete':
                                onDelete();
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            if (onViewDetails != null)
                              const PopupMenuItem(
                                value: 'details',
                                child: Text('Document Details'),
                              ),
                            const PopupMenuItem(
                              value: 'open',
                              child: Text('Open PDF'),
                            ),
                            const PopupMenuItem(
                              value: 'share',
                              child: Text('Share PDF'),
                            ),
                            const PopupMenuItem(
                              value: 'rename',
                              child: Text('Rename'),
                            ),
                            if (onPrivateToggle != null)
                              PopupMenuItem(
                                value: 'private',
                                child: Text(
                                  document.isPrivate
                                      ? 'Remove from Private'
                                      : 'Mark as Private',
                                ),
                              ),
                            if (onMoveToFolder != null)
                              const PopupMenuItem(
                                value: 'move',
                                child: Text('Move to Folder'),
                              ),
                            if (onManageTags != null)
                              const PopupMenuItem(
                                value: 'tags',
                                child: Text('Manage Tags'),
                              ),
                            if (onArchive != null)
                              PopupMenuItem(
                                value: 'archive',
                                child: Text(
                                  document.isArchived ? 'Restore' : 'Archive',
                                ),
                              ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                'Delete',
                                style: TextStyle(color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${document.pageCount} ${document.pageCount == 1 ? 'p' : 'pp'} · ${FileUtils.formatBytes(document.fileSizeBytes)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.65,
                          ),
                        ),
                      ),
                      Text(
                        DateFormatter.formatDate(document.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.65,
                          ),
                        ),
                      ),
                    ],
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
