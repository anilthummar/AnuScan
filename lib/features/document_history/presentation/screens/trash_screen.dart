import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/file_utils.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/entities/document_query_filter.dart';
import '../cubit/document_history_cubit.dart';
import '../cubit/document_history_state.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    context.read<DocumentHistoryCubit>().setActiveTab(DocumentTab.trash);
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
    });
  }

  void _confirmPermanentDelete(DocumentEntity doc) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete permanently?'),
        content: Text(
          'Are you sure you want to permanently delete "${doc.title}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.read<DocumentHistoryCubit>().permanentDeleteDocument(
                    doc.id,
                  );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Permanently deleted "${doc.title}"')),
              );
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  void _confirmEmptyTrash(List<DocumentEntity> docs) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Empty Trash?'),
        content: Text(
          'All ${docs.length} documents in the Trash will be permanently deleted. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final ids = docs.map((d) => d.id).toList();
              final cubit = context.read<DocumentHistoryCubit>();
              if (cubit.bulkDocumentActionUseCase != null) {
                await cubit.bulkDocumentActionUseCase!.permanentDelete(ids);
                cubit.loadDocuments();
              } else {
                for (final id in ids) {
                  await cubit.permanentDeleteDocument(id);
                }
              }
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Trash emptied')));
              }
            },
            child: const Text('Empty Trash'),
          ),
        ],
      ),
    );
  }

  void _confirmBulkPermanentDelete() {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Selected Permanently?'),
        content: Text(
          'Delete ${_selectedIds.length} documents permanently? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final cubit = context.read<DocumentHistoryCubit>();
              final ids = _selectedIds.toList();
              if (cubit.bulkDocumentActionUseCase != null) {
                await cubit.bulkDocumentActionUseCase!.permanentDelete(ids);
                cubit.loadDocuments();
              }
              _clearSelection();
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  void _bulkRestore() async {
    final cubit = context.read<DocumentHistoryCubit>();
    final ids = _selectedIds.toList();
    if (cubit.bulkDocumentActionUseCase != null) {
      await cubit.bulkDocumentActionUseCase!.restoreFromTrash(ids);
      cubit.loadDocuments();
    } else {
      for (final id in ids) {
        await cubit.restoreFromTrash(id);
      }
    }
    _clearSelection();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${ids.length} documents restored')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedIds.isNotEmpty ? '${_selectedIds.length} Selected' : 'Trash',
        ),
        actions: [
          if (_selectedIds.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.restore),
              tooltip: 'Restore Selected',
              onPressed: _bulkRestore,
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever, color: AppColors.error),
              tooltip: 'Permanently Delete',
              onPressed: _confirmBulkPermanentDelete,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _clearSelection,
            ),
          ],
        ],
      ),
      body: BlocBuilder<DocumentHistoryCubit, DocumentHistoryState>(
        builder: (context, state) {
          if (state is DocumentHistoryLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is DocumentHistoryLoaded) {
            final docs = state.documents;
            if (docs.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete_outline, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Trash is empty',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                // Info Banner & Empty Trash Button
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  color: Colors.amber.shade50,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.amber,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Items in Trash are kept locally until permanently deleted.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _confirmEmptyTrash(docs),
                        child: const Text(
                          'Empty Trash',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Documents List
                Expanded(
                  child: ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final isSelected = _selectedIds.contains(doc.id);
                      final isSelecting = _selectedIds.isNotEmpty;

                      return ListTile(
                        leading: isSelecting
                            ? Checkbox(
                                value: isSelected,
                                onChanged: (_) => _toggleSelect(doc.id),
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  width: 45,
                                  height: 60,
                                  color: Colors.grey.shade100,
                                  child: doc.thumbnailPath != null
                                      ? Image.file(
                                          File(doc.thumbnailPath!),
                                          fit: BoxFit.cover,
                                          cacheWidth: 90,
                                          cacheHeight: 120,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                            Icons.picture_as_pdf,
                                            size: 24,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.picture_as_pdf,
                                          size: 24,
                                        ),
                                ),
                              ),
                        title: Text(
                          doc.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Deleted: ${doc.deletedAt != null ? DateFormatter.formatDate(doc.deletedAt!) : 'Recently'} · ${FileUtils.formatBytes(doc.fileSizeBytes)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: isSelecting
                            ? null
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.restore,
                                      color: AppColors.primary,
                                    ),
                                    tooltip: 'Restore',
                                    onPressed: () {
                                      context
                                          .read<DocumentHistoryCubit>()
                                          .restoreFromTrash(doc.id);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Restored "${doc.title}"',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_forever,
                                      color: AppColors.error,
                                    ),
                                    tooltip: 'Delete Permanently',
                                    onPressed: () =>
                                        _confirmPermanentDelete(doc),
                                  ),
                                ],
                              ),
                        onLongPress: () => _toggleSelect(doc.id),
                        onTap: isSelecting ? () => _toggleSelect(doc.id) : null,
                      );
                    },
                  ),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
