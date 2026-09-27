import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/document_query_filter.dart';
import '../../domain/entities/folder_entity.dart';
import '../cubit/document_history_cubit.dart';
import '../cubit/document_history_state.dart';

class FoldersScreen extends StatefulWidget {
  const FoldersScreen({super.key});

  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  void _showCreateDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Create Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Folder Name',
            hintText: 'e.g. Invoices, Personal, Work',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                context.read<DocumentHistoryCubit>().createFolder(name);
              }
              Navigator.pop(dialogCtx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(FolderEntity folder) {
    final controller = TextEditingController(text: folder.name);
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Folder Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != folder.name) {
                context.read<DocumentHistoryCubit>().renameFolder(
                  folder.id,
                  newName,
                );
              }
              Navigator.pop(dialogCtx);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(FolderEntity folder) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Folder?'),
        content: Text(
          'Are you sure you want to delete "${folder.name}"? Documents in this folder will NOT be deleted, they will become uncategorized.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.read<DocumentHistoryCubit>().deleteFolder(folder.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Folders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'New Folder',
            onPressed: _showCreateDialog,
          ),
        ],
      ),
      body: BlocBuilder<DocumentHistoryCubit, DocumentHistoryState>(
        builder: (context, state) {
          if (state is DocumentHistoryLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is DocumentHistoryLoaded) {
            final folders = state.folders;
            if (folders.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.folder_open_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No folders created yet',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Create Folder'),
                      onPressed: _showCreateDialog,
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final folder = folders[index];
                final count =
                    state.counts.folderCounts[folder.id] ??
                    folder.documentCount;

                return ListTile(
                  leading: const Icon(
                    Icons.folder,
                    size: 36,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    folder.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '$count ${count == 1 ? 'document' : 'documents'}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'rename') {
                        _showRenameDialog(folder);
                      } else if (val == 'delete') {
                        _confirmDelete(folder);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'rename',
                        child: Text('Rename'),
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
                  onTap: () {
                    // Filter Home by this folder
                    final cubit = context.read<DocumentHistoryCubit>();
                    cubit.setActiveTab(DocumentTab.all);
                    cubit.setFolderFilter(folder.id);
                    Navigator.pop(context);
                  },
                );
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
