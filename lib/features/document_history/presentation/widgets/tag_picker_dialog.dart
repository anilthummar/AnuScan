import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/tag_entity.dart';

/// Dialog to manage, assign, or create tags for a document.
class TagPickerDialog extends StatefulWidget {
  const TagPickerDialog({
    super.key,
    required this.availableTags,
    required this.assignedTags,
    required this.onAssignTag,
    required this.onRemoveTag,
    required this.onCreateTag,
  });

  final List<TagEntity> availableTags;
  final List<TagEntity> assignedTags;
  final Future<void> Function(String tagId) onAssignTag;
  final Future<void> Function(String tagId) onRemoveTag;
  final Future<void> Function(String name) onCreateTag;

  static Future<void> show(
    BuildContext context, {
    required List<TagEntity> availableTags,
    required List<TagEntity> assignedTags,
    required Future<void> Function(String tagId) onAssignTag,
    required Future<void> Function(String tagId) onRemoveTag,
    required Future<void> Function(String name) onCreateTag,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => TagPickerDialog(
        availableTags: availableTags,
        assignedTags: assignedTags,
        onAssignTag: onAssignTag,
        onRemoveTag: onRemoveTag,
        onCreateTag: onCreateTag,
      ),
    );
  }

  @override
  State<TagPickerDialog> createState() => _TagPickerDialogState();
}

class _TagPickerDialogState extends State<TagPickerDialog> {
  late Set<String> _assignedIds;
  final TextEditingController _newTagController = TextEditingController();
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _assignedIds = widget.assignedTags.map((t) => t.id).toSet();
  }

  @override
  void dispose() {
    _newTagController.dispose();
    super.dispose();
  }

  Future<void> _handleToggle(TagEntity tag) async {
    final isAssigned = _assignedIds.contains(tag.id);
    if (isAssigned) {
      await widget.onRemoveTag(tag.id);
      setState(() {
        _assignedIds.remove(tag.id);
      });
    } else {
      await widget.onAssignTag(tag.id);
      setState(() {
        _assignedIds.add(tag.id);
      });
    }
  }

  Future<void> _handleCreate() async {
    final name = _newTagController.text.trim();
    if (name.isEmpty) return;
    await widget.onCreateTag(name);
    _newTagController.clear();
    setState(() {
      _isCreating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.label_outlined, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Manage Tags'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.availableTags.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No tags created yet.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.availableTags.length,
                  itemBuilder: (context, index) {
                    final tag = widget.availableTags[index];
                    final isChecked = _assignedIds.contains(tag.id);
                    return CheckboxListTile(
                      dense: true,
                      title: Text('#${tag.name}'),
                      value: isChecked,
                      activeColor: AppColors.primary,
                      onChanged: (_) => _handleToggle(tag),
                    );
                  },
                ),
              ),
            const Divider(),

            if (_isCreating)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newTagController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'New tag name',
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
                label: const Text('Create Tag'),
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
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
