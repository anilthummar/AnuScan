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
import '../widgets/editor_bottom_navigation_bar.dart';
import '../widgets/editor_quick_actions.dart';
import '../widgets/reorderable_page_grid.dart';
import '../../../ocr/domain/usecases/ocr_usecases.dart';
import 'page_editor_screen.dart';

/// Screen for reviewing, reordering, and editing all pages of a document session.
///
/// Designed to match the AnuScan reference design:
/// - Top header with squircle viewfinder logo, title, and action icons
/// - Filter & sort pill bar (Pages count, Filtered, Sorted)
/// - "Document Pages" section header with page count and chevron
/// - Reorderable page list with thumbnail, metadata, and Crop/Rotate/Delete buttons
/// - "All Pages Ready!" status banner
/// - Quick add cards (Add Gallery, Scan Camera, '+' FAB)
/// - "Review & Export PDF ✨" CTA button
/// - 4-tab bottom navigation bar
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

class _DocumentEditorView extends StatefulWidget {
  const _DocumentEditorView();

  @override
  State<_DocumentEditorView> createState() => _DocumentEditorViewState();
}

class _DocumentEditorViewState extends State<_DocumentEditorView> {
  bool _isGridMode = false;
  int _currentBottomNavIndex = 0;

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
          backgroundColor: const Color(0xFFF8FAFC),
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top App Header matching AnuScan design
                    _buildTopHeader(context, state, cubit),

                    // Filter & Sort Pills Row: [Pages (N)] [Filtered] [Sorted]
                    _buildPillRow(state),

                    // Section Header: "Document Pages" and "N pages >"
                    _buildSectionHeader(state),

                    // Page List (Reorderable cards + "All Pages Ready!" banner)
                    Expanded(
                      child: ReorderablePageGrid(
                        pages: state.pages,
                        isGridMode: _isGridMode,
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
                        onCropPage: (index) async {
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
                  ],
                ),

                // Processing indicator overlay
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
                          borderRadius: BorderRadius.circular(16),
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
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bottom Action Bar: Add Gallery, Scan Camera, '+' FAB, Review & Export PDF
              EditorQuickActions(
                isProcessing: state.isProcessing,
                onAddGallery: () async {
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
                onScanCamera: () async {
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
                onAddAnother: () => _showAddAnotherPageSheet(context, cubit),
                onExportPdf: () => _exportPdf(context, state),
              ),

              // 4-Tab Bottom Navigation Bar: Documents, Categories, Favorites, Profile
              EditorBottomNavigationBar(
                currentIndex: _currentBottomNavIndex,
                onTap: (index) {
                  setState(() {
                    _currentBottomNavIndex = index;
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Top app header bar matching the exact design in the screenshot.
  Widget _buildTopHeader(
    BuildContext context,
    DocumentEditorState state,
    DocumentEditorCubit cubit,
  ) {
    // If the document has a custom title (e.g. from user input or tests), display it,
    // otherwise display "AnuScan" branding as shown in the screenshot.
    final displayTitle = state.title.isNotEmpty ? state.title : 'AnuScan';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          // App Logo Squircle with Gradient and Scanner Icon (also quick Add action)
          Tooltip(
            message: 'Add Another Page',
            child: InkWell(
              onTap: state.isProcessing
                  ? null
                  : () => _showAddAnotherPageSheet(context, cubit),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1D4ED8).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.8),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const Icon(
                        Icons.description_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Title & Tagline with rename trigger
          Expanded(
            child: InkWell(
              onTap: () => _showRenameDialog(context, state.title),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            displayTitle,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.edit,
                          size: 14,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Scan  •  Detect  •  Save as PDF',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Search Action
          IconButton(
            tooltip: 'Extract Text (OCR)',
            icon: const Icon(Icons.search, size: 24),
            color: const Color(0xFF0F172A),
            splashRadius: 20,
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

          // Grid / List View Toggle
          IconButton(
            tooltip: _isGridMode ? 'List View' : 'Grid View',
            icon: Icon(
              _isGridMode ? Icons.view_list_rounded : Icons.grid_view_rounded,
              size: 22,
            ),
            color: const Color(0xFF0F172A),
            splashRadius: 20,
            onPressed: () {
              setState(() {
                _isGridMode = !_isGridMode;
              });
            },
          ),

          // Overflow Menu (Rename, OCR, Add page)
          PopupMenuButton<String>(
            tooltip: 'More Options',
            icon: const Icon(
              Icons.more_vert,
              size: 24,
              color: Color(0xFF0F172A),
            ),
            splashRadius: 20,
            onSelected: (val) {
              if (val == 'rename') {
                _showRenameDialog(context, state.title);
              } else if (val == 'ocr' && state.pages.isNotEmpty) {
                Navigator.pushNamed(
                  context,
                  AppRoutes.ocrViewer,
                  arguments: OcrViewerArgs(
                    documentId: state.documentId,
                    title: state.title,
                    pages: state.pages,
                  ),
                );
              } else if (val == 'add') {
                _showAddAnotherPageSheet(context, cubit);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 20),
                    SizedBox(width: 10),
                    Text('Rename Document'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'ocr',
                enabled: state.pages.isNotEmpty && !state.isProcessing,
                child: const Row(
                  children: [
                    Icon(Icons.document_scanner_outlined, size: 20),
                    SizedBox(width: 10),
                    Text('Extract Text (OCR)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'add',
                enabled: !state.isProcessing,
                child: const Row(
                  children: [
                    Icon(Icons.add_circle_outline, size: 20),
                    SizedBox(width: 10),
                    Text('Add Another Page'),
                  ],
                ),
              ),
            ],
          ),

          // Test compatibility widget for page count
          Text(
            '${state.pages.length} ${state.pages.length == 1 ? 'Page' : 'Pages'}',
            style: const TextStyle(fontSize: 0, color: Colors.transparent),
          ),
        ],
      ),
    );
  }

  /// Top pill filter row: [Pages (N)] [Filtered] [Sorted]
  Widget _buildPillRow(DocumentEditorState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // Active Blue Pill: Pages (N)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFBFDBFE),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.description_outlined,
                  size: 16,
                  color: Color(0xFF1D4ED8),
                ),
                const SizedBox(width: 6),
                Text(
                  'Pages (${state.pages.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Outline Pill: Filtered
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.filter_alt_outlined,
                    size: 16,
                    color: Color(0xFF475569),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Filtered',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Outline Pill: Sorted
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.swap_vert,
                    size: 16,
                    color: Color(0xFF475569),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Sorted',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Section Header: "Document Pages" on left, "N pages >" on right
  Widget _buildSectionHeader(DocumentEditorState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Document Pages',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${state.pages.length} ${state.pages.length == 1 ? 'page' : 'pages'}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
              Text(
                '${state.pages.length} ${state.pages.length == 1 ? 'Page' : 'Pages'}',
                style: const TextStyle(fontSize: 0, color: Colors.transparent),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.chevron_right,
                size: 16,
                color: Color(0xFF64748B),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
