import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/share_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/file_utils.dart';
import '../../../ocr/presentation/screens/ocr_viewer_screen.dart';
import '../../../pdf_viewer/presentation/screens/pdf_preview_screen.dart';
import '../../../smart_document/domain/entities/document_classification.dart';
import '../../../smart_document/domain/usecases/smart_document_usecases.dart';
import '../../domain/entities/document_entity.dart';
import '../cubit/document_history_cubit.dart';
import '../cubit/document_history_state.dart';
import '../widgets/folder_picker_dialog.dart';
import '../widgets/tag_picker_dialog.dart';

class DocumentDetailsScreen extends StatefulWidget {
  const DocumentDetailsScreen({super.key, required this.documentId});

  final String documentId;

  @override
  State<DocumentDetailsScreen> createState() => _DocumentDetailsScreenState();
}

class _DocumentDetailsScreenState extends State<DocumentDetailsScreen> {
  DocumentEntity? _doc;
  DocumentType? _docType;

  @override
  void initState() {
    super.initState();
    _refreshDocument();
  }

  void _refreshDocument() {
    final state = context.read<DocumentHistoryCubit>().state;
    if (state is DocumentHistoryLoaded) {
      final match = state.documents.where((d) => d.id == widget.documentId);
      if (match.isNotEmpty) {
        setState(() {
          _doc = match.first;
        });
      }
    }
    _loadClassification();
  }

  Future<void> _loadClassification() async {
    if (!sl.isRegistered<GetDocumentRecognitionUseCase>()) return;
    try {
      final res = await sl<GetDocumentRecognitionUseCase>()(widget.documentId);
      final rec = res.dataOrNull;
      if (rec != null && mounted) {
        setState(() {
          _docType = rec.classification.type;
        });
      }
    } catch (_) {}
  }

  void _showRenameDialog() {
    if (_doc == null) return;
    final controller = TextEditingController(text: _doc!.title);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename Document'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Document Name',
            hintText: 'Enter new name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != _doc!.title) {
                context.read<DocumentHistoryCubit>().renameDocument(
                      _doc!.id,
                      newName,
                    );
                setState(() {
                  _doc = _doc!.copyWith(title: newName);
                });
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showTypeSelector() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Select Document Type',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  children: DocumentType.values.map((type) {
                    final isSelected = type == _docType;
                    return ListTile(
                      title: Text(type.displayName),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () async {
                        Navigator.pop(bottomSheetContext);
                        if (sl.isRegistered<OverrideDocumentTypeUseCase>()) {
                          await sl<OverrideDocumentTypeUseCase>()(
                            documentId: widget.documentId,
                            manualType: type,
                          );
                          setState(() {
                            _docType = type;
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleMoveFolder() async {
    if (_doc == null) return;
    final cubit = context.read<DocumentHistoryCubit>();
    final state = cubit.state;
    final folders = state is DocumentHistoryLoaded ? state.folders : [];

    final selected = await FolderPickerDialog.show(
      context,
      folders: folders.cast(),
      currentFolderId: _doc!.folderId,
      onCreateFolder: (name) => cubit.createFolder(name),
    );

    if (selected != null && mounted) {
      final newFolderId = selected == 'none' ? null : selected;
      await cubit.moveDocumentToFolder(_doc!.id, newFolderId);
      _refreshDocument();
    }
  }

  Future<void> _handleManageTags() async {
    if (_doc == null) return;
    final cubit = context.read<DocumentHistoryCubit>();
    final state = cubit.state;
    final available = state is DocumentHistoryLoaded ? state.tags : [];

    await TagPickerDialog.show(
      context,
      availableTags: available.cast(),
      assignedTags: _doc!.tags,
      onAssignTag: (tagId) => cubit.assignTag(_doc!.id, tagId),
      onRemoveTag: (tagId) => cubit.removeTag(_doc!.id, tagId),
      onCreateTag: (name) => cubit.createTag(name),
    );

    if (mounted) {
      _refreshDocument();
    }
  }

  void _openPdf() {
    if (_doc == null) return;
    context.read<DocumentHistoryCubit>().recordDocumentOpened(_doc!.id);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(
          documentId: _doc!.id,
          title: _doc!.title,
          pages: _doc!.pages,
          existingPdfPath: _doc!.pdfPath,
        ),
      ),
    ).then((_) => _refreshDocument());
  }

  void _openOcrViewer() {
    if (_doc == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OcrViewerScreen(
          documentId: _doc!.id,
          title: _doc!.title,
          pages: _doc!.pages,
        ),
      ),
    );
  }

  Future<void> _sharePdf() async {
    if (_doc == null) return;
    try {
      final file = File(_doc!.pdfPath);
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF file not found on disk.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
      await sl<ShareService>().shareFile(
        _doc!.pdfPath,
        subject: _doc!.title,
        text: 'Shared from AnuScan: ${_doc!.title}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share PDF: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _confirmDelete() {
    if (_doc == null) return;
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Move to Trash?'),
        content: Text('"${_doc!.title}" will be moved to the Trash.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.read<DocumentHistoryCubit>().deleteDocument(_doc!.id);
              Navigator.pop(context);
            },
            child: const Text('Move to Trash'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DocumentHistoryCubit, DocumentHistoryState>(
      listener: (context, state) {
        if (state is DocumentHistoryLoaded) {
          final match = state.documents.where((d) => d.id == widget.documentId);
          if (match.isNotEmpty) {
            setState(() {
              _doc = match.first;
            });
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Document Details'),
          actions: [
            if (_doc != null) ...[
              IconButton(
                icon: Icon(
                  _doc!.isPrivate ? Icons.lock : Icons.lock_outline,
                  color: _doc!.isPrivate ? AppColors.primary : null,
                ),
                tooltip:
                    _doc!.isPrivate ? 'Remove from Private' : 'Mark as Private',
                onPressed: () {
                  context.read<DocumentHistoryCubit>().togglePrivate(
                        _doc!.id,
                        !_doc!.isPrivate,
                      );
                  setState(() {
                    _doc = _doc!.copyWith(isPrivate: !_doc!.isPrivate);
                  });
                },
              ),
              IconButton(
                icon: Icon(
                  _doc!.isFavorite ? Icons.star : Icons.star_border,
                  color: _doc!.isFavorite ? Colors.amber : null,
                ),
                tooltip: _doc!.isFavorite ? 'Unfavorite' : 'Favorite',
                onPressed: () {
                  context.read<DocumentHistoryCubit>().toggleFavorite(
                        _doc!.id,
                        !_doc!.isFavorite,
                      );
                  setState(() {
                    _doc = _doc!.copyWith(isFavorite: !_doc!.isFavorite);
                  });
                },
              ),
            ],
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share PDF',
              onPressed: _sharePdf,
            ),
          ],
        ),
        body: _doc == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Hero Preview Thumbnail & Title
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 140,
                        height: 190,
                        color: Colors.grey.shade100,
                        child: _doc!.isPrivate
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.lock,
                                      size: 56,
                                      color: AppColors.primary,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Private Document',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : (_doc!.thumbnailPath != null &&
                                    _doc!.thumbnailPath!.isNotEmpty
                                ? Image.file(
                                    File(_doc!.thumbnailPath!),
                                    fit: BoxFit.cover,
                                    cacheWidth: 300,
                                    cacheHeight: 400,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.picture_as_pdf,
                                      size: 64,
                                      color: AppColors.primary,
                                    ),
                                  )
                                : const Icon(
                                    Icons.picture_as_pdf,
                                    size: 64,
                                    color: AppColors.primary,
                                  )),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title & Rename Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          _doc!.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: 'Rename Document',
                        onPressed: _showRenameDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Document Type Badge
                  Center(
                    child: ActionChip(
                      avatar: const Icon(Icons.category_outlined, size: 16),
                      label: Text(
                        _docType?.displayName ?? 'Select Document Type',
                        style: const TextStyle(fontSize: 13),
                      ),
                      onPressed: _showTypeSelector,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Quick Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('Open PDF'),
                        onPressed: _openPdf,
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.text_fields_outlined),
                        label: const Text('OCR Text'),
                        onPressed: _openOcrViewer,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Security & Privacy Section
                  Card(
                    child: SwitchListTile(
                      secondary: const Icon(Icons.security_outlined),
                      title: const Text('Private Document'),
                      subtitle: const Text(
                        'Protected from open preview, listed under Private tab',
                      ),
                      value: _doc!.isPrivate,
                      onChanged: (val) {
                        context.read<DocumentHistoryCubit>().togglePrivate(
                              _doc!.id,
                              val,
                            );
                        setState(() {
                          _doc = _doc!.copyWith(isPrivate: val);
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Organization Section (Folder & Tags)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Organization',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.folder_outlined),
                            title: const Text('Folder'),
                            subtitle: Text(_doc!.folderName ?? 'Uncategorized'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _handleMoveFolder,
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.label_outlined),
                            title: const Text('Tags'),
                            subtitle: _doc!.tags.isEmpty
                                ? const Text('No tags')
                                : Wrap(
                                    spacing: 6,
                                    children: _doc!.tags.map((t) {
                                      return Chip(
                                        label: Text('#${t.name}'),
                                        labelStyle: const TextStyle(
                                          fontSize: 11,
                                        ),
                                        padding: EdgeInsets.zero,
                                      );
                                    }).toList(),
                                  ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _handleManageTags,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Statistics Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Document Information',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(),
                          _buildStatRow(
                            'Pages',
                            '${_doc!.pageCount}',
                            Icons.pages_outlined,
                          ),
                          _buildStatRow(
                            'File Size',
                            FileUtils.formatBytes(_doc!.fileSizeBytes),
                            Icons.storage_outlined,
                          ),
                          _buildStatRow(
                            'Created',
                            DateFormatter.formatDateTime(_doc!.createdAt),
                            Icons.calendar_today_outlined,
                          ),
                          _buildStatRow(
                            'Updated',
                            DateFormatter.formatDateTime(_doc!.updatedAt),
                            Icons.update_outlined,
                          ),
                          if (_doc!.lastOpenedAt != null)
                            _buildStatRow(
                              'Last Opened',
                              DateFormatter.formatDateTime(_doc!.lastOpenedAt!),
                              Icons.history_outlined,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Archive & Delete actions
                  ListTile(
                    leading: Icon(
                      _doc!.isArchived
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
                    ),
                    title: Text(
                      _doc!.isArchived ? 'Restore' : 'Archive Document',
                    ),
                    subtitle: Text(
                      _doc!.isArchived
                          ? 'Move document back to main collection'
                          : 'Hide document from main view without deleting',
                    ),
                    onTap: () {
                      context.read<DocumentHistoryCubit>().archiveDocument(
                            _doc!.id,
                            !_doc!.isArchived,
                          );
                      setState(() {
                        _doc = _doc!.copyWith(isArchived: !_doc!.isArchived);
                      });
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline,
                      color: AppColors.error,
                    ),
                    title: const Text(
                      'Move to Trash',
                      style: TextStyle(color: AppColors.error),
                    ),
                    subtitle: const Text('Document can be restored from Trash'),
                    onTap: _confirmDelete,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
