import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/folder_entity.dart';

/// Dialog to select a folder for a document or create a new folder.
class FolderPickerDialog extends StatefulWidget {
  const FolderPickerDialog({
    super.key,
    required this.folders,
    this.currentFolderId,
    required this.onCreateFolder,
  });

  final List<FolderEntity> folders;
  final String? currentFolderId;
  final Future<void> Function(String name) onCreateFolder;

  static Future<String?> show(
    BuildContext context, {
    required List<FolderEntity> folders,
    String? currentFolderId,
    required Future<void> Function(String name) onCreateFolder,
  }) {
    return showDialog<String?>(
      context: context,
      builder: (ctx) => FolderPickerDialog(
        folders: folders,
        currentFolderId: currentFolderId,
        onCreateFolder: onCreateFolder,
      ),
    );
  }

  @override
  State<FolderPickerDialog> createState() => _FolderPickerDialogState();
}

class _FolderPickerDialogState extends State<FolderPickerDialog> {
  final TextEditingController _newFolderController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _newFolderController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    final name = _newFolderController.text.trim();
    if (name.isEmpty) return;
    await widget.onCreateFolder(name);
    if (mounted) {
      Navigator.pop(context, 'created');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.folder_outlined, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Select Folder'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // "No Folder" option
            ListTile(
              leading: const Icon(Icons.folder_off_outlined),
              title: const Text('No Folder (Uncategorized)'),
              trailing: widget.currentFolderId == null
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () => Navigator.pop(context, 'none'),
            ),
            const Divider(),

            // Existing folders
            if (widget.folders.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No folders yet',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.folders.length,
                  itemBuilder: (context, index) {
                    final folder = widget.folders[index];
                    final isSelected = folder.id == widget.currentFolderId;
                    return ListTile(
                      leading: const Icon(Icons.folder, color: Colors.blueGrey),
                      title: Text(folder.name),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () => Navigator.pop(context, folder.id),
                    );
                  },
                ),
              ),

            const Divider(),

            // Create new folder section
            if (_isCreating)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newFolderController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'New folder name',
                        isDense: true,
                      ),
                      onSubmitted: (_) => _handleCreate(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check, color: AppColors.primary),
                    onPressed: _handleCreate,
                  ),
                ],
              )
            else
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Create New Folder'),
                onPressed: () {
                  setState(() {
                    _isCreating = true;
                  });
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
