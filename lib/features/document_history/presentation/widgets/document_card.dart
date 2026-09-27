import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/file_utils.dart';
import '../../domain/entities/document_entity.dart';

/// Card widget representing a saved document in the history list.
class DocumentCard extends StatelessWidget {
  const DocumentCard({
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
      final firstPage = document.pages.first;
      if (firstPage.processedImagePath.trim().isNotEmpty) {
        return firstPage.processedImagePath;
      }
      if (firstPage.originalImagePath.trim().isNotEmpty) {
        return firstPage.originalImagePath;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumbnail = _resolveThumbnailPath();
    final handleOpen = isSelectionMode ? onSelectToggle : (onOpen ?? onTap);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? const BorderSide(color: AppColors.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: handleOpen,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Selection Checkbox
              if (isSelectionMode) ...[
                IconButton(
                  icon: Icon(
                    isSelected
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color: isSelected ? AppColors.primary : Colors.grey,
                  ),
                  onPressed: onSelectToggle,
                ),
                const SizedBox(width: 4),
              ],

              // Document Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 65,
                  height: 85,
                  color: Colors.grey.shade100,
                  child: document.isPrivate
                      ? const Center(
                          child: Icon(
                            Icons.lock,
                            color: AppColors.primary,
                            size: 32,
                          ),
                        )
                      : (thumbnail != null
                            ? Image.file(
                                File(thumbnail),
                                fit: BoxFit.cover,
                                cacheWidth: 150,
                                cacheHeight: 200,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                      Icons.picture_as_pdf,
                                      color: AppColors.primary,
                                      size: 32,
                                    ),
                              )
                            : const Icon(
                                Icons.picture_as_pdf,
                                color: AppColors.primary,
                                size: 32,
                              )),
                ),
              ),
              const SizedBox(width: 14),

              // Document Metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Document Name + Favorite indicator + Private indicator
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            document.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (document.isPrivate && !isSelectionMode)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.lock,
                              color: AppColors.primary,
                              size: 16,
                            ),
                          ),
                        if (document.isFavorite && !isSelectionMode)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 18,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Created Date & Folder name
                    Row(
                      children: [
                        Text(
                          'Created: ${DateFormatter.formatDateTime(document.createdAt)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.textTheme.bodySmall?.color?.withValues(
                              alpha: 0.65,
                            ),
                          ),
                        ),
                        if (document.folderName != null &&
                            document.folderName!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.folder,
                                  size: 11,
                                  color: Colors.blueGrey,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  document.folderName!,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Page Count, PDF Size & Tags
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${document.pageCount} ${document.pageCount == 1 ? 'page' : 'pages'}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          FileUtils.formatBytes(document.fileSizeBytes),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: theme.textTheme.bodySmall?.color?.withValues(
                              alpha: 0.65,
                            ),
                          ),
                        ),
                        if (document.tags.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: document.tags.map((tag) {
                                  return Container(
                                    margin: const EdgeInsets.only(right: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '#${tag.name}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Context Menu Actions
              if (!isSelectionMode)
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    color: AppColors.textSecondaryLight,
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'details':
                        onViewDetails?.call();
                        break;
                      case 'open':
                        (onOpen ?? onTap)();
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
                      case 'share':
                        onShare();
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
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 18),
                            SizedBox(width: 10),
                            Text('Document Details'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'open',
                      child: Row(
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 10),
                          Text('Open'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(
                            Icons.share_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 10),
                          Text('Share PDF'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('Rename'),
                        ],
                      ),
                    ),
                    if (onPrivateToggle != null)
                      PopupMenuItem(
                        value: 'private',
                        child: Row(
                          children: [
                            Icon(
                              document.isPrivate
                                  ? Icons.lock_open_outlined
                                  : Icons.lock_outline,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              document.isPrivate
                                  ? 'Remove from Private'
                                  : 'Mark as Private',
                            ),
                          ],
                        ),
                      ),
                    if (onFavoriteToggle != null)
                      PopupMenuItem(
                        value: 'favorite',
                        child: Row(
                          children: [
                            Icon(
                              document.isFavorite
                                  ? Icons.star_border
                                  : Icons.star,
                              size: 18,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              document.isFavorite
                                  ? 'Remove from Favorites'
                                  : 'Add to Favorites',
                            ),
                          ],
                        ),
                      ),
                    if (onMoveToFolder != null)
                      const PopupMenuItem(
                        value: 'move',
                        child: Row(
                          children: [
                            Icon(Icons.drive_file_move_outlined, size: 18),
                            SizedBox(width: 10),
                            Text('Move to Folder'),
                          ],
                        ),
                      ),
                    if (onManageTags != null)
                      const PopupMenuItem(
                        value: 'tags',
                        child: Row(
                          children: [
                            Icon(Icons.label_outline, size: 18),
                            SizedBox(width: 10),
                            Text('Manage Tags'),
                          ],
                        ),
                      ),
                    if (onArchive != null)
                      PopupMenuItem(
                        value: 'archive',
                        child: Row(
                          children: [
                            Icon(
                              document.isArchived
                                  ? Icons.unarchive_outlined
                                  : Icons.archive_outlined,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Text(document.isArchived ? 'Restore' : 'Archive'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: AppColors.error,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Delete',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
