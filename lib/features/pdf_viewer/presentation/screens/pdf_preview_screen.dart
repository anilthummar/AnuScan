import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart' hide PdfPreviewState;
import '../../../../core/di/injection.dart';
import '../../../../core/services/file_storage_service.dart';
import '../../../../core/services/image_processing_service.dart';
import '../../../../core/services/pdf_generator_service.dart';
import '../../../../core/services/share_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/file_utils.dart';
import '../../../document_editor/domain/entities/scanned_page.dart';
import '../../../document_history/domain/repositories/document_repository.dart';
import '../../../document_history/domain/usecases/document_usecases.dart';
import '../../domain/usecases/generate_pdf_usecase.dart';
import '../../domain/usecases/share_pdf_usecase.dart';
import '../cubit/pdf_preview_cubit.dart';
import '../cubit/pdf_preview_state.dart';

/// Screen for previewing generated PDF, changing page formats, renaming, and sharing.
class PdfPreviewScreen extends StatelessWidget {
  const PdfPreviewScreen({
    super.key,
    required this.documentId,
    required this.title,
    required this.pages,
    this.existingPdfPath,
  });

  final String documentId;
  final String title;
  final List<ScannedPage> pages;
  final String? existingPdfPath;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = PdfPreviewCubit(
          generatePdfUseCase: GeneratePdfUseCase(
            pdfGeneratorService: sl<PdfGeneratorService>(),
            fileStorageService: sl<FileStorageService>(),
            imageProcessingService: sl<ImageProcessingService>(),
          ),
          sharePdfUseCase: SharePdfUseCase(sl<ShareService>()),
          saveDocumentUseCase: SaveDocumentUseCase(sl<DocumentRepository>()),
          documentId: documentId,
          title: title,
          pages: pages,
        );
        cubit.compilePdf();
        return cubit;
      },
      child: _PdfPreviewView(pagesCount: pages.length),
    );
  }
}

class _PdfPreviewView extends StatelessWidget {
  const _PdfPreviewView({required this.pagesCount});

  final int pagesCount;

  void _showRenameDialog(BuildContext context, String currentTitle) {
    final controller = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename PDF'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'PDF Title',
            hintText: 'Enter new filename',
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
                context.read<PdfPreviewCubit>().renameDocument(text);
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PdfPreviewCubit, PdfPreviewState>(
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
        final cubit = context.read<PdfPreviewCubit>();

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
              IconButton(
                tooltip: 'Share PDF',
                icon: const Icon(Icons.share, color: AppColors.primary),
                onPressed: state.pdfPath != null ? () => cubit.sharePdf() : null,
              ),
              IconButton(
                tooltip: 'Done',
                icon: const Icon(Icons.check),
                onPressed: () {
                  // Return to home root
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // PDF Viewer Canvas
              Expanded(
                child: state.isGenerating || state.pdfPath == null
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(
                              'Compiling high-resolution PDF...',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      )
                    : PdfPreview(
                        build: (format) async => await File(state.pdfPath!).readAsBytes(),
                        canChangeOrientation: false,
                        canChangePageFormat: false,
                        canDebug: false,
                        allowPrinting: true,
                        allowSharing: false, // Handled through our ShareService
                        pdfFileName: '${FileUtils.sanitizeFileName(state.title)}.pdf',
                      ),
              ),

              // Bottom Info and Page Format Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: const Border(
                    top: BorderSide(color: AppColors.borderLight),
                  ),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      // Document Metadata
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle, size: 16, color: AppColors.success),
                                const SizedBox(width: 6),
                                Text(
                                  state.isSaved ? 'Saved Locally' : 'Ready',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$pagesCount Pages • ${FileUtils.formatBytes(state.fileSizeBytes)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Page Size Format Selector Dropdown
                      DropdownButton<PdfPageSizeOption>(
                        value: state.pageSize,
                        underline: const SizedBox.shrink(),
                        icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                        items: PdfPageSizeOption.values.map((option) {
                          return DropdownMenuItem(
                            value: option,
                            child: Text(
                              option.displayName,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          );
                        }).toList(),
                        onChanged: state.isGenerating
                            ? null
                            : (newSize) {
                                if (newSize != null) {
                                  cubit.compilePdf(pageSize: newSize);
                                }
                              },
                      ),
                    ],
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
