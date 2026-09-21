import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/file_storage_service.dart';
import '../../../../core/services/image_processing_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../pdf_viewer/presentation/screens/pdf_preview_screen.dart';
import '../../../scanner/domain/usecases/import_gallery_usecase.dart';
import '../../../scanner/domain/usecases/scan_documents_usecase.dart';
import '../../domain/entities/scanned_page.dart';
import '../../domain/usecases/process_page_usecase.dart';
import '../../domain/usecases/reorder_pages_usecase.dart';
import '../cubit/document_editor_cubit.dart';
import '../cubit/document_editor_state.dart';
import '../widgets/reorderable_page_grid.dart';
import 'page_editor_screen.dart';

/// Screen for reviewing, reordering, and editing all pages of a document before PDF compilation.
class DocumentEditorScreen extends StatelessWidget {
  const DocumentEditorScreen({
    super.key,
    required this.documentId,
    required this.initialTitle,
    required this.initialImagePaths,
  });

  final String documentId;
  final String initialTitle;
  final List<String> initialImagePaths;

  @override
  Widget build(BuildContext context) {
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
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
              if (state.pages.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    onPressed: state.isProcessing
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PdfPreviewScreen(
                                  documentId: state.documentId,
                                  title: state.title,
                                  pages: state.pages,
                                ),
                              ),
                            );
                          },
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    label: const Text('Create PDF'),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

                  // Reorderable list of pages
                  Expanded(
                    child: ReorderablePageGrid(
                      pages: state.pages,
                      onReorder: (oldIdx, newIdx) => cubit.reorderPages(oldIdx, newIdx),
                      onTapPage: (index) async {
                        final updatedPage = await Navigator.push<ScannedPage>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PageEditorScreen(page: state.pages[index]),
                          ),
                        );
                        if (updatedPage != null && context.mounted) {
                          cubit.updatePage(updatedPage);
                        }
                      },
                      onRotatePage: (index) => cubit.rotatePage(index),
                      onDeletePage: (index) => _confirmDeletePage(context, index),
                    ),
                  ),

                  // Bottom Action Bar: Add Pages (Camera & Gallery)
                  SafeArea(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border: const Border(
                          top: BorderSide(color: AppColors.borderLight),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Add Gallery'),
                              onPressed: state.isProcessing
                                  ? null
                                  : () async {
                                      final useCase = ImportGalleryUseCase(sl());
                                      final paths = await useCase();
                                      if (paths.isNotEmpty && context.mounted) {
                                        cubit.addImages(paths);
                                      }
                                    },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Scan Camera'),
                              onPressed: state.isProcessing
                                  ? null
                                  : () async {
                                      final useCase = ScanDocumentsUseCase(sl());
                                      final paths = await useCase();
                                      if (paths.isNotEmpty && context.mounted) {
                                        cubit.addImages(paths);
                                      }
                                    },
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
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
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
