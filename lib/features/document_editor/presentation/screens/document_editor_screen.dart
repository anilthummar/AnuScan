import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/file_storage_service.dart';
import '../../../../core/services/image_processing_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/scanned_page.dart';
import '../../domain/usecases/process_page_usecase.dart';
import '../../domain/usecases/reorder_pages_usecase.dart';
import '../cubit/document_editor_cubit.dart';
import '../cubit/document_editor_state.dart';
import '../widgets/reorderable_page_grid.dart';
import '../../../ocr/domain/usecases/ocr_usecases.dart';
import 'page_editor_screen.dart';

/// Screen for reviewing, reordering, and editing all pages of a document session.
class DocumentEditorScreen extends StatelessWidget {
  const DocumentEditorScreen({
    super.key,
    required this.documentId,
    required this.initialTitle,
    required this.initialImagePaths,
    this.customCubit,
  });

  final String documentId;
  final String initialTitle;
  final List<String> initialImagePaths;
  final DocumentEditorCubit? customCubit;

  @override
  Widget build(BuildContext context) {
    if (customCubit != null) {
      return BlocProvider.value(
        value: customCubit!,
        child: const _DocumentEditorView(),
      );
    }

    return BlocProvider(
      create: (context) {
        final cubit = DocumentEditorCubit(
          fileStorageService: sl<FileStorageService>(),
          imageProcessingService: sl<ImageProcessingService>(),
          processPageUseCase: ProcessPageUseCase(
            imageProcessingService: sl<ImageProcessingService>(),
            fileStorageService: sl<FileStorageService>(),
          ),
          reorderPagesUseCase: const ReorderPagesUseCase(),
          documentId: documentId,
          initialTitle: initialTitle,
          invalidatePageOcrUseCase: sl.isRegistered<InvalidatePageOcrUseCase>()
              ? sl<InvalidatePageOcrUseCase>()
              : null,
        );
        if (initialImagePaths.isNotEmpty) {
          cubit.addImages(initialImagePaths);
        }
        return cubit;
      },
      child: const _DocumentEditorView(),
    );
  }
}

class _DocumentEditorView extends StatelessWidget {
  const _DocumentEditorView();

  void _showRenameDialog(BuildContext context, String currentTitle) {
    final controller = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename Document'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Document Name',
            hintText: 'Enter title',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                context.read<DocumentEditorCubit>().updateTitle(text);
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePage(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Page'),
        content: Text('Are you sure you want to delete Page ${index + 1}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<DocumentEditorCubit>().deletePage(index);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _exportPdf(BuildContext context, DocumentEditorState state) {
    if (state.pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one page to export PDF.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    Navigator.pushNamed(
      context,
      AppRoutes.pdfPreview,
      arguments: PdfPreviewArgs(
        documentId: state.documentId,
        title: state.title,
        pages: state.pages,
      ),
    );
  }

  void _showAddAnotherPageSheet(
    BuildContext context,
    DocumentEditorCubit cubit,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Another Page',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.camera_alt, color: Colors.white),
                ),
                title: const Text('Scan with Camera'),
                subtitle: const Text('Capture physical documents with camera'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final results = await Navigator.pushNamed(
                    context,
                    AppRoutes.scanner,
                  );
                  if (results is List<String> &&
                      results.isNotEmpty &&
                      context.mounted) {
                    cubit.addImages(results);
                  }
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: Icon(Icons.photo_library, color: Colors.white),
                ),
                title: const Text('Import from Gallery'),
                subtitle: const Text('Select one or more photos from library'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final results = await Navigator.pushNamed(
                    context,
                    AppRoutes.gallery,
                  );
                  if (results is List<ScannedPage> &&
                      results.isNotEmpty &&
                      context.mounted) {
                    cubit.addPages(results);
                  } else if (results is List<String> &&
                      results.isNotEmpty &&
                      context.mounted) {
                    cubit.addImages(results);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DocumentEditorCubit, DocumentEditorState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<DocumentEditorCubit>();

        return Scaffold(
          appBar: AppBar(
            title: InkWell(
              onTap: () => _showRenameDialog(context, state.title),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        state.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.edit, size: 16, color: AppColors.primary),
                  ],
                ),
              ),
            ),
            actions: [
              // Page count indicator badge in AppBar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${state.pages.length} ${state.pages.length == 1 ? 'Page' : 'Pages'}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Extract Text (OCR)',
                icon: const Icon(Icons.document_scanner_outlined),
                onPressed: state.pages.isEmpty || state.isProcessing
                    ? null
                    : () {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.ocrViewer,
                          arguments: OcrViewerArgs(
                            documentId: state.documentId,
                            title: state.title,
                            pages: state.pages,
                          ),
                        );
                      },
              ),
              IconButton(
                tooltip: 'Add Another Page',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: state.isProcessing
                    ? null
                    : () => _showAddAnotherPageSheet(context, cubit),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.picture_as_pdf, size: 16),
                  label: const Text(
                    'Export PDF',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  onPressed: state.isProcessing
                      ? null
                      : () => _exportPdf(context, state),
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  // Status banner showing page count and drag-and-drop hint
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: AppColors.primary.withValues(alpha: 0.08),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${state.pages.length} ${state.pages.length == 1 ? 'Page' : 'Pages'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        if (state.pages.length > 1)
                          const Text(
                            'Hold & drag to reorder',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Reorderable list of pages [ Page 1 ] [ Page 2 ] [ Page 3 ]
                  Expanded(
                    child: ReorderablePageGrid(
                      pages: state.pages,
                      onReorder: (oldIdx, newIdx) =>
                          cubit.reorderPages(oldIdx, newIdx),
                      onTapPage: (index) async {
                        final updatedPage = await Navigator.push<ScannedPage>(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PageEditorScreen(page: state.pages[index]),
                          ),
                        );
                        if (updatedPage != null && context.mounted) {
                          cubit.updatePage(updatedPage);
                        }
                      },
                      onDuplicatePage: (index) => cubit.duplicatePage(index),
                      onRotatePage: (index) => cubit.rotatePage(index),
                      onDeletePage: (index) =>
                          _confirmDeletePage(context, index),
                    ),
                  ),

                  // Bottom Action Bar: Add Pages (Camera & Gallery) + Add Another Page
                  SafeArea(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border: const Border(
                          top: BorderSide(color: AppColors.borderLight),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(
                                    Icons.photo_library_outlined,
                                  ),
                                  label: const Text('Add Gallery'),
                                  onPressed: state.isProcessing
                                      ? null
                                      : () async {
                                          final results =
                                              await Navigator.pushNamed(
                                                context,
                                                AppRoutes.gallery,
                                              );
                                          if (results is List<ScannedPage> &&
                                              results.isNotEmpty &&
                                              context.mounted) {
                                            cubit.addPages(results);
                                          } else if (results is List<String> &&
                                              results.isNotEmpty &&
                                              context.mounted) {
                                            cubit.addImages(results);
                                          }
                                        },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.camera_alt_outlined),
                                  label: const Text('Scan Camera'),
                                  onPressed: state.isProcessing
                                      ? null
                                      : () async {
                                          final results =
                                              await Navigator.pushNamed(
                                                context,
                                                AppRoutes.scanner,
                                              );
                                          if (results is List<String> &&
                                              results.isNotEmpty &&
                                              context.mounted) {
                                            cubit.addImages(results);
                                          }
                                        },
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                tooltip: 'Add Another Page',
                                icon: const Icon(Icons.add),
                                onPressed: state.isProcessing
                                    ? null
                                    : () => _showAddAnotherPageSheet(
                                        context,
                                        cubit,
                                      ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              icon: const Icon(Icons.picture_as_pdf),
                              label: const Text(
                                'Review & Export PDF',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              onPressed: state.isProcessing
                                  ? null
                                  : () => _exportPdf(context, state),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Processing indicator
              if (state.isProcessing)
                Container(
                  color: Colors.black45,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 12),
                          Text(
                            state.processingMessage ?? 'Processing...',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
