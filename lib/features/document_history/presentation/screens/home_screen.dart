import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/share_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../document_editor/presentation/screens/document_editor_screen.dart';
import '../../../pdf_viewer/presentation/screens/pdf_preview_screen.dart';
import '../../../scanner/domain/usecases/import_gallery_usecase.dart';
import '../../../scanner/domain/usecases/scan_documents_usecase.dart';
import '../../domain/entities/document_entity.dart';
import '../cubit/document_history_cubit.dart';
import '../cubit/document_history_state.dart';
import '../widgets/document_card.dart';
import '../widgets/empty_state_view.dart';

/// Main landing home screen displaying saved document history, search, and scan triggers.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<DocumentHistoryCubit>().loadDocuments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _startCameraScan() async {
    try {
      final useCase = ScanDocumentsUseCase(sl());
      final paths = await useCase();
      if (paths.isNotEmpty && mounted) {
        _navigateToEditor(paths);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start scanner: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _startGalleryImport() async {
    try {
      final useCase = ImportGalleryUseCase(sl());
      final paths = await useCase();
      if (paths.isNotEmpty && mounted) {
        _navigateToEditor(paths);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import images: $e'), backgroundColor: AppColors.error),
        );
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

  void _showRenameDialog(DocumentEntity doc) {
    final controller = TextEditingController(text: doc.title);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename Document'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Document Name',
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
                context.read<DocumentHistoryCubit>().renameDocument(doc.id, newTitle);
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
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Delete "${doc.title}"? This cannot be undone.'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearchOpen
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search documents...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onChanged: (query) {
                  context.read<DocumentHistoryCubit>().searchDocuments(query);
                },
              )
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.document_scanner, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'AnuScan',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
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
                  context.read<DocumentHistoryCubit>().loadDocuments();
                } else {
                  _isSearchOpen = true;
                }
              });
            },
          ),
        ],
      ),
      body: BlocBuilder<DocumentHistoryCubit, DocumentHistoryState>(
        builder: (context, state) {
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
                      onPressed: () => context.read<DocumentHistoryCubit>().loadDocuments(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is DocumentHistoryLoaded) {
            if (state.documents.isEmpty) {
              return EmptyStateView(
                onScanPressed: _startCameraScan,
                onGalleryPressed: _startGalleryImport,
              );
            }

            return RefreshIndicator(
              onRefresh: () => context.read<DocumentHistoryCubit>().loadDocuments(),
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 88),
                itemCount: state.documents.length,
                itemBuilder: (context, index) {
                  final doc = state.documents[index];
                  return DocumentCard(
                    document: doc,
                    onTap: () {
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
                        if (context.mounted) {
                          context.read<DocumentHistoryCubit>().loadDocuments();
                        }
                      });
                    },
                    onShare: () async {
                      if (await File(doc.pdfPath).exists()) {
                        await sl<ShareService>().shareFile(doc.pdfPath, subject: doc.title);
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('PDF file not found on device'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
                    onRename: () => _showRenameDialog(doc),
                    onDelete: () => _confirmDelete(doc),
                  );
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.camera_alt),
        label: const Text('Scan'),
        onPressed: _startCameraScan,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
