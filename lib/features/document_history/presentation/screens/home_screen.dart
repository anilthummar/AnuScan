import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/security_service.dart';
import '../../../../core/services/share_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../document_editor/domain/entities/scanned_page.dart';
import '../../../document_editor/presentation/screens/document_editor_screen.dart';
import '../../../pdf_viewer/presentation/screens/pdf_preview_screen.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/entities/document_query_filter.dart';
import '../cubit/document_history_cubit.dart';
import '../cubit/document_history_state.dart';
import '../widgets/document_card.dart';
import '../widgets/document_grid_card.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/folder_picker_dialog.dart';
import '../widgets/tag_picker_dialog.dart';
import 'document_details_screen.dart';
import 'folders_screen.dart';
import 'trash_screen.dart';

/// Main landing home screen displaying saved document history, search, filters,
/// folder/tag management, view modes, and multi-selection bulk operations.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  String _selectedFilter = 'All';

  static const _filterOptions = [
    'All',
    'Invoice',
    'Receipt',
    'Business Card',
    'Contract',
    'Certificate',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    context.read<DocumentHistoryCubit>().loadDocuments();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<DocumentHistoryCubit>().loadNextPage();
    }
  }

  void _onSearchChanged(String query) {
    context.read<DocumentHistoryCubit>().searchDocuments(query);
  }

  Future<void> _startCameraScan() async {
    try {
      if (sl.isRegistered<SecurityService>()) {
        sl<SecurityService>().setTransientActivityActive(true);
      }
      final results = await Navigator.pushNamed(context, AppRoutes.scanner);
      if (results is List<String> && results.isNotEmpty && mounted) {
        _navigateToEditor(results);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start scanner: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (sl.isRegistered<SecurityService>()) {
        sl<SecurityService>().setTransientActivityActive(false);
      }
    }
  }

  Future<void> _startGalleryImport() async {
    try {
      if (sl.isRegistered<SecurityService>()) {
        sl<SecurityService>().setTransientActivityActive(true);
      }
      final results = await Navigator.pushNamed(context, AppRoutes.gallery);
      if (results is List<ScannedPage> && results.isNotEmpty && mounted) {
        _navigateToEditor(results.map((p) => p.originalImagePath).toList());
      } else if (results is List<String> && results.isNotEmpty && mounted) {
        _navigateToEditor(results);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import images: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (sl.isRegistered<SecurityService>()) {
        sl<SecurityService>().setTransientActivityActive(false);
      }
    }
  }

  void _navigateToEditor(List<String> imagePaths) {
    final docId = const Uuid().v4();
    final defaultTitle = DateFormatter.defaultDocumentTitle();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentEditorScreen(
          documentId: docId,
          initialTitle: defaultTitle,
          initialImagePaths: imagePaths,
        ),
      ),
    ).then((_) {
      if (mounted) {
        context.read<DocumentHistoryCubit>().loadDocuments();
      }
    });
  }

  void _openDocument(DocumentEntity doc) {
    context.read<DocumentHistoryCubit>().recordDocumentOpened(doc.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(
          documentId: doc.id,
          title: doc.title,
          pages: doc.pages,
          existingPdfPath: doc.pdfPath,
        ),
      ),
    ).then((_) {
      if (mounted) {
        context.read<DocumentHistoryCubit>().loadDocuments();
      }
    });
  }

  void _openDetails(DocumentEntity doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentDetailsScreen(documentId: doc.id),
      ),
    ).then((_) {
      if (mounted) {
        context.read<DocumentHistoryCubit>().loadDocuments();
      }
    });
  }

  Future<void> _shareDocument(DocumentEntity doc) async {
    try {
      final file = File(doc.pdfPath);
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'PDF file not found. It may have been moved or deleted.',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      await sl<ShareService>().shareFile(
        doc.pdfPath,
        subject: doc.title,
        text: 'Shared from AnuScan: ${doc.title}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share document: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showRenameDialog(DocumentEntity doc) {
    final controller = TextEditingController(text: doc.title);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename Document'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Document Name',
            hintText: 'Enter new document name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty && newTitle != doc.title) {
                context.read<DocumentHistoryCubit>().renameDocument(
                      doc.id,
                      newTitle,
                    );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Renamed to "$newTitle"'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(DocumentEntity doc) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text(
          'Are you sure you want to delete "${doc.title}"? This cannot be undone.',
        ),
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
              context.read<DocumentHistoryCubit>().deleteDocument(doc.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMoveFolder(DocumentEntity doc) async {
    final cubit = context.read<DocumentHistoryCubit>();
    final state = cubit.state;
    final folders = state is DocumentHistoryLoaded ? state.folders : [];

    final selected = await FolderPickerDialog.show(
      context,
      folders: folders.cast(),
      currentFolderId: doc.folderId,
      onCreateFolder: (name) => cubit.createFolder(name),
    );

    if (selected != null && mounted) {
      final newFolderId = selected == 'none' ? null : selected;
      await cubit.moveDocumentToFolder(doc.id, newFolderId);
    }
  }

  Future<void> _handleManageTags(DocumentEntity doc) async {
    final cubit = context.read<DocumentHistoryCubit>();
    final state = cubit.state;
    final available = state is DocumentHistoryLoaded ? state.tags : [];

    await TagPickerDialog.show(
      context,
      availableTags: available.cast(),
      assignedTags: doc.tags,
      onAssignTag: (tagId) => cubit.assignTag(doc.id, tagId),
      onRemoveTag: (tagId) => cubit.removeTag(doc.id, tagId),
      onCreateTag: (name) => cubit.createTag(name),
    );
  }

  void _showSortBottomSheet(DocumentSortOption currentSort) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Sort Documents By',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  children: DocumentSortOption.values.map((opt) {
                    final isSelected = opt == currentSort;
                    return ListTile(
                      title: Text(opt.displayName),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        context.read<DocumentHistoryCubit>().setSortOption(opt);
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

  void _confirmBulkTrash(DocumentHistoryLoaded state) {
    final count = state.selectedDocumentIds.length;
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Move to Trash?'),
        content: Text('Move $count selected documents to the Trash?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.read<DocumentHistoryCubit>().bulkMoveToTrash();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Moved $count documents to Trash')),
              );
            },
            child: const Text('Move to Trash'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBulkMoveFolder(DocumentHistoryLoaded state) async {
    final cubit = context.read<DocumentHistoryCubit>();
    final selected = await FolderPickerDialog.show(
      context,
      folders: state.folders,
      onCreateFolder: (name) => cubit.createFolder(name),
    );

    if (selected != null && mounted) {
      final newFolderId = selected == 'none' ? null : selected;
      await cubit.bulkMoveToFolder(newFolderId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DocumentHistoryCubit, DocumentHistoryState>(
      builder: (context, state) {
        final loaded = state is DocumentHistoryLoaded ? state : null;
        final isSelectionMode = loaded?.isSelectionMode ?? false;

        return Scaffold(
          appBar: isSelectionMode
              ? AppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () =>
                        context.read<DocumentHistoryCubit>().clearSelection(),
                  ),
                  title: Text('${loaded!.selectedDocumentIds.length} Selected'),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.select_all),
                      tooltip: 'Select All',
                      onPressed: () =>
                          context.read<DocumentHistoryCubit>().selectAll(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.drive_file_move_outlined),
                      tooltip: 'Move to Folder',
                      onPressed: () => _handleBulkMoveFolder(loaded),
                    ),
                    IconButton(
                      icon: const Icon(Icons.star_border),
                      tooltip: 'Favorite Selected',
                      onPressed: () => context
                          .read<DocumentHistoryCubit>()
                          .bulkFavorite(true),
                    ),
                    IconButton(
                      icon: const Icon(Icons.archive_outlined),
                      tooltip: 'Archive Selected',
                      onPressed: () => context
                          .read<DocumentHistoryCubit>()
                          .bulkArchive(true),
                    ),
                    IconButton(
                      icon: Icon(
                        loaded.activeTab == DocumentTab.private
                            ? Icons.lock_open_outlined
                            : Icons.lock_outline,
                      ),
                      tooltip: loaded.activeTab == DocumentTab.private
                          ? 'Remove from Private'
                          : 'Mark as Private',
                      onPressed: () =>
                          context.read<DocumentHistoryCubit>().bulkSetPrivate(
                                loaded.activeTab != DocumentTab.private,
                              ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.error,
                      ),
                      tooltip: 'Move to Trash',
                      onPressed: () => _confirmBulkTrash(loaded),
                    ),
                  ],
                )
              : AppBar(
                  title: _isSearchOpen
                      ? TextField(
                          controller: _searchController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'Search documents, OCR, tags...',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                          onChanged: _onSearchChanged,
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.document_scanner,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'AnuScan',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                  actions: [
                    IconButton(
                      icon: Icon(_isSearchOpen ? Icons.close : Icons.search),
                      onPressed: () {
                        setState(() {
                          if (_isSearchOpen) {
                            _isSearchOpen = false;
                            _searchController.clear();
                            context
                                .read<DocumentHistoryCubit>()
                                .searchDocuments('');
                          } else {
                            _isSearchOpen = true;
                          }
                        });
                      },
                    ),
                    if (!_isSearchOpen && loaded != null) ...[
                      IconButton(
                        icon: Icon(
                          loaded.viewMode == DocumentViewMode.grid
                              ? Icons.view_list
                              : Icons.grid_view,
                        ),
                        tooltip: loaded.viewMode == DocumentViewMode.grid
                            ? 'List View'
                            : 'Grid View',
                        onPressed: () {
                          final next = loaded.viewMode == DocumentViewMode.grid
                              ? DocumentViewMode.list
                              : DocumentViewMode.grid;
                          context.read<DocumentHistoryCubit>().setViewMode(
                                next,
                              );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.sort),
                        tooltip: 'Sort Documents',
                        onPressed: () =>
                            _showSortBottomSheet(loaded.sortOption),
                      ),
                    ],
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz),
                      tooltip: 'More options',
                      onSelected: (val) {
                        final cubit = context.read<DocumentHistoryCubit>();
                        switch (val) {
                          case 'folders':
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FoldersScreen(),
                              ),
                            ).then((_) {
                              cubit.loadDocuments();
                            });
                            break;
                          case 'trash':
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TrashScreen(),
                              ),
                            ).then((_) {
                              cubit.loadDocuments();
                            });
                            break;
                          case 'settings':
                            Navigator.pushNamed(context, AppRoutes.settings);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'folders',
                          child: Row(
                            children: [
                              Icon(Icons.folder_outlined, size: 20),
                              SizedBox(width: 10),
                              Text('Folders'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'trash',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 20),
                              SizedBox(width: 10),
                              Text('Trash'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'settings',
                          child: Row(
                            children: [
                              Icon(Icons.settings_outlined, size: 20),
                              SizedBox(width: 10),
                              Text('Settings'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
          body: _buildBody(context, state),
          floatingActionButton: isSelectionMode
              ? null
              : FloatingActionButton.extended(
                  backgroundColor: AppColors.primary,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Scan'),
                  onPressed: _startCameraScan,
                ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, DocumentHistoryState state) {
    if (state is DocumentHistoryLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is DocumentHistoryError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(state.message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    context.read<DocumentHistoryCubit>().loadDocuments(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state is DocumentHistoryLoaded) {
      final cubit = context.read<DocumentHistoryCubit>();

      return RefreshIndicator(
        onRefresh: () => cubit.loadDocuments(),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Top Filter Tabs (All, Favorites, Folders, Archived)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tab selector row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildTabChip(
                            label: 'All (${state.counts.activeCount})',
                            isSelected: state.activeTab == DocumentTab.all,
                            onTap: () => cubit.setActiveTab(DocumentTab.all),
                          ),
                          const SizedBox(width: 8),
                          _buildTabChip(
                            label: 'Favorites (${state.counts.favoriteCount})',
                            isSelected:
                                state.activeTab == DocumentTab.favorites,
                            onTap: () =>
                                cubit.setActiveTab(DocumentTab.favorites),
                          ),
                          const SizedBox(width: 8),
                          _buildTabChip(
                            label: 'Archived (${state.counts.archivedCount})',
                            isSelected: state.activeTab == DocumentTab.archived,
                            onTap: () =>
                                cubit.setActiveTab(DocumentTab.archived),
                          ),
                          const SizedBox(width: 8),
                          _buildTabChip(
                            label: 'Private (${state.counts.privateCount})',
                            isSelected: state.activeTab == DocumentTab.private,
                            onTap: () =>
                                cubit.setActiveTab(DocumentTab.private),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Document Type chips
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filterOptions.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final filter = _filterOptions[i];
                        final isSelected = filter == _selectedFilter;
                        return ChoiceChip(
                          label: Text(
                            filter,
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              _selectedFilter = filter;
                            });
                            cubit.setDocumentTypeFilter(filter);
                          },
                        );
                      },
                    ),
                  ),

                  // Active Filter Summary row if active
                  if (state.filter.hasActiveFilters)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.filter_list,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _buildActiveFilterText(state.filter),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(50, 24),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedFilter = 'All';
                              });
                              cubit.clearFilters();
                            },
                            child: const Text(
                              'Reset',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                ],
              ),
            ),

            // Section Header (Recent Documents or Search Results)
            if (state.documents.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isSearchOpen ||
                                (state.filter.searchQuery != null &&
                                    state.filter.searchQuery!.isNotEmpty)
                            ? 'Search Results (${state.documents.length})'
                            : 'Recent Documents',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${state.documents.length} ${state.documents.length == 1 ? 'file' : 'files'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Document Content
            if (state.documents.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyStateView(
                  onScanPressed: _startCameraScan,
                  onGalleryPressed: _startGalleryImport,
                ),
              )
            else if (state.viewMode == DocumentViewMode.grid)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.68,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final doc = state.documents[index];
                    final isSelected = state.selectedDocumentIds.contains(
                      doc.id,
                    );
                    return DocumentGridCard(
                      document: doc,
                      isSelected: isSelected,
                      isSelectionMode: state.isSelectionMode,
                      onTap: () => _openDocument(doc),
                      onOpen: () => _openDocument(doc),
                      onViewDetails: () => _openDetails(doc),
                      onShare: () => _shareDocument(doc),
                      onRename: () => _showRenameDialog(doc),
                      onDelete: () => _confirmDelete(doc),
                      onFavoriteToggle: () =>
                          cubit.toggleFavorite(doc.id, !doc.isFavorite),
                      onArchive: () =>
                          cubit.archiveDocument(doc.id, !doc.isArchived),
                      onPrivateToggle: () =>
                          cubit.togglePrivate(doc.id, !doc.isPrivate),
                      onMoveToFolder: () => _handleMoveFolder(doc),
                      onManageTags: () => _handleManageTags(doc),
                      onSelectToggle: () => cubit.toggleSelection(doc.id),
                      onLongPress: () => cubit.toggleSelection(doc.id),
                    );
                  }, childCount: state.documents.length),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 88),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final doc = state.documents[index];
                    final isSelected = state.selectedDocumentIds.contains(
                      doc.id,
                    );
                    return DocumentCard(
                      document: doc,
                      isSelected: isSelected,
                      isSelectionMode: state.isSelectionMode,
                      onTap: () => _openDocument(doc),
                      onOpen: () => _openDocument(doc),
                      onViewDetails: () => _openDetails(doc),
                      onShare: () => _shareDocument(doc),
                      onRename: () => _showRenameDialog(doc),
                      onDelete: () => _confirmDelete(doc),
                      onFavoriteToggle: () =>
                          cubit.toggleFavorite(doc.id, !doc.isFavorite),
                      onArchive: () =>
                          cubit.archiveDocument(doc.id, !doc.isArchived),
                      onPrivateToggle: () =>
                          cubit.togglePrivate(doc.id, !doc.isPrivate),
                      onMoveToFolder: () => _handleMoveFolder(doc),
                      onManageTags: () => _handleManageTags(doc),
                      onSelectToggle: () => cubit.toggleSelection(doc.id),
                      onLongPress: () => cubit.toggleSelection(doc.id),
                    );
                  }, childCount: state.documents.length),
                ),
              ),

            // Pagination loader indicator
            if (state.isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildTabChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.primary : null,
      ),
      onSelected: (_) => onTap(),
    );
  }

  String _buildActiveFilterText(DocumentQueryFilter filter) {
    final parts = <String>[];
    if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
      parts.add('"${filter.searchQuery}"');
    }
    if (filter.documentType != null) {
      parts.add(filter.documentType!);
    }
    if (filter.isFavorite == true) {
      parts.add('Favorites');
    }
    if (filter.folderId != null) {
      parts.add('Folder');
    }
    if (filter.tagId != null) {
      parts.add('Tag');
    }
    return 'Active: ${parts.join(' · ')}';
  }
}
