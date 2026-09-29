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
import '../../domain/entities/document_counts.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/entities/document_query_filter.dart';
import '../cubit/document_history_cubit.dart';
import '../cubit/document_history_state.dart';
import '../widgets/document_card.dart';
import '../widgets/document_grid_card.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/category_selector_card.dart';
import '../widgets/hero_scan_banner.dart';
import '../widgets/home_bottom_navigation_bar.dart';
import '../widgets/home_header.dart';
import '../widgets/quick_actions_row.dart';
import '../widgets/status_filter_pills.dart';
import '../widgets/folder_picker_dialog.dart';
import '../widgets/tag_picker_dialog.dart';
import '../../../subscription/presentation/widgets/feature_gate_sheet.dart';
import '../../../../core/constants/premium_constants.dart';
import '../../../../core/services/feature_access_service.dart';
import 'document_details_screen.dart';

/// Main landing home screen displaying saved document history, search, filters,
/// folder/tag management, view modes, and multi-selection bulk operations.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentNavIndex = 0;
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  String _selectedFilter = 'All';


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
                      icon: const Icon(Icons.folder_zip_outlined),
                      tooltip: PremiumConstants.isMonetizationHidden
                          ? 'Batch Export'
                          : 'Batch Export (Pro)',
                      onPressed: () => _handleBatchExport(loaded),
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
              : null,
          backgroundColor: const Color(0xFFF8FAFC),
          body: SafeArea(
            bottom: false,
            child: _buildBody(context, state),
          ),
          floatingActionButton: isSelectionMode
              ? null
              : FloatingActionButton(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 4,
                  tooltip: 'Scan Document',
                  onPressed: _startCameraScan,
                  child: const Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.camera_alt, size: 28),
                      Offstage(
                        offstage: true,
                        child: Text('Scan'),
                      ),
                    ],
                  ),
                ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          bottomNavigationBar: isSelectionMode
              ? null
              : HomeBottomNavigationBar(
                  currentIndex: _currentNavIndex,
                  onTap: _onBottomNavTapped,
                ),
        );
      },
    );
  }

  void _handleBatchExport(DocumentHistoryLoaded loaded) {
    final featureAccess =
        sl.isRegistered<FeatureAccessService>()
            ? sl<FeatureAccessService>()
            : null;
    if (featureAccess != null &&
        !featureAccess.canUse(PremiumFeature.batchPdfExport)) {
      FeatureGateSheet.show(
        context,
        feature: PremiumFeature.batchPdfExport,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Batch export initiated for ${loaded.selectedDocumentIds.length} documents.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _showCloudBackupInfoSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_outlined,
                  size: 28,
                  color: Color(0xFF16A34A),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Offline-First & Local Storage',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'AnuScan is built with a 100% offline-first privacy architecture. Your documents, photos, and OCR text remain securely on your device only and are never uploaded to any cloud server.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Understood'),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onBottomNavTapped(int index) {
    if (index == 0) {
      setState(() {
        _currentNavIndex = 0;
        _isSearchOpen = false;
      });
    } else if (index == 1) {
      setState(() {
        _currentNavIndex = 1;
      });
    } else if (index == 2) {
      Navigator.pushNamed(context, AppRoutes.folders).then((_) {
        if (mounted) context.read<DocumentHistoryCubit>().loadDocuments();
      });
    } else if (index == 3) {
      Navigator.pushNamed(context, AppRoutes.settings).then((_) {
        if (mounted) context.read<DocumentHistoryCubit>().loadDocuments();
      });
    }
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Color(0xFF64748B), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search documents, OCR, tags...',
                hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
            splashRadius: 18,
            onPressed: () {
              setState(() {
                _isSearchOpen = false;
                _searchController.clear();
                context.read<DocumentHistoryCubit>().searchDocuments('');
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, DocumentHistoryState state) {
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

    final loaded = state is DocumentHistoryLoaded ? state : null;
    final cubit = context.read<DocumentHistoryCubit>();

    return RefreshIndicator(
      onRefresh: () => cubit.loadDocuments(),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Top Section (Header, Filter Pills, Category Selector, Hero Banner, Quick Actions)
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isSearchOpen)
                  _buildSearchBar()
                else
                  HomeHeader(
                    isGridMode: loaded?.viewMode == DocumentViewMode.grid,
                    onSearchPressed: () {
                      setState(() {
                        _isSearchOpen = true;
                      });
                    },
                    onViewModeToggle: () {
                      if (loaded != null) {
                        final next = loaded.viewMode == DocumentViewMode.grid
                            ? DocumentViewMode.list
                            : DocumentViewMode.grid;
                        cubit.setViewMode(next);
                      }
                    },
                    onSettingsPressed: () {
                      Navigator.pushNamed(context, AppRoutes.settings).then((_) {
                        if (mounted) cubit.loadDocuments();
                      });
                    },
                  ),

                // Status Filter Pills (All, Favorites, Archived, Private)
                StatusFilterPills(
                  activeTab: loaded?.activeTab ?? DocumentTab.all,
                  counts: loaded?.counts ?? const DocumentCounts(),
                  onTabSelected: (tab) => cubit.setActiveTab(tab),
                ),

                // Category Selector Card
                CategorySelectorCard(
                  selectedCategory: _selectedFilter,
                  onCategorySelected: (cat) {
                    setState(() {
                      _selectedFilter = cat;
                    });
                    cubit.setDocumentTypeFilter(cat);
                  },
                ),

                // Active Filter Summary row if active
                if (loaded != null && loaded.filter.hasActiveFilters)
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
                            _buildActiveFilterText(loaded.filter),
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

                // Hero Banner and Quick Actions (only on Home tab when not searching)
                if (_currentNavIndex == 0 &&
                    !_isSearchOpen &&
                    !(loaded?.filter.hasActiveFilters ?? false)) ...[
                  const SizedBox(height: 12),
                  HeroScanBanner(
                    onScanNow: _startCameraScan,
                  ),
                  const SizedBox(height: 14),
                  QuickActionsRow(
                    onImportGallery: _startGalleryImport,
                    onCreatePdf: _startCameraScan,
                    onCloudBackup: _showCloudBackupInfoSheet,
                    onAppLock: () {
                      Navigator.pushNamed(context, AppRoutes.settings);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),

          if (state is DocumentHistoryLoading || state is DocumentHistoryInitial)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: CircularProgressIndicator(),
                ),
              ),
            )
          else if (loaded != null) ...[
            // Section Header (Recent Documents or Search Results)
            if (loaded.documents.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isSearchOpen ||
                                (loaded.filter.searchQuery != null &&
                                    loaded.filter.searchQuery!.isNotEmpty)
                            ? 'Search Results (${loaded.documents.length})'
                            : 'Recent Documents',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '${loaded.documents.length} ${loaded.documents.length == 1 ? 'file' : 'files'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () => _showSortBottomSheet(loaded.sortOption),
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(
                                Icons.sort_rounded,
                                size: 18,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // Document Content
            if (loaded.documents.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyStateView(
                  onScanPressed: _startCameraScan,
                  onGalleryPressed: _startGalleryImport,
                ),
              )
            else if (loaded.viewMode == DocumentViewMode.grid)
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
                    final doc = loaded.documents[index];
                    final isSelected = loaded.selectedDocumentIds.contains(
                      doc.id,
                    );
                    return DocumentGridCard(
                      document: doc,
                      isSelected: isSelected,
                      isSelectionMode: loaded.isSelectionMode,
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
                  }, childCount: loaded.documents.length),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 88),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final doc = loaded.documents[index];
                    final isSelected = loaded.selectedDocumentIds.contains(
                      doc.id,
                    );
                    return DocumentCard(
                      document: doc,
                      isSelected: isSelected,
                      isSelectionMode: loaded.isSelectionMode,
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
                  }, childCount: loaded.documents.length),
                ),
              ),

            // Pagination loader indicator
            if (loaded.isLoadingMore)
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
        ],
      ),
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
