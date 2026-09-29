import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart' hide PdfPreviewState;
import '../../../../core/di/injection.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/pdf_generator_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/file_utils.dart';
import '../../../document_editor/domain/entities/scanned_page.dart';
import '../../../document_history/domain/usecases/document_usecases.dart';
import '../../../smart_document/domain/usecases/smart_document_usecases.dart';
import '../../../smart_document/presentation/cubit/smart_document_cubit.dart';
import '../../../smart_document/presentation/widgets/smart_document_card.dart';
import '../../domain/usecases/delete_pdf_usecase.dart';
import '../../domain/usecases/generate_pdf_usecase.dart';
import '../../domain/usecases/rename_pdf_usecase.dart';
import '../../domain/usecases/share_pdf_usecase.dart';
import '../cubit/pdf_preview_cubit.dart';
import '../cubit/pdf_preview_state.dart';
import '../../../../core/services/feature_access_service.dart';
import '../../../../core/constants/premium_constants.dart';
import '../../../subscription/presentation/widgets/feature_gate_sheet.dart';

/// Screen for previewing generated PDF, changing page formats, renaming, sharing,
/// opening with external applications, saving, and deleting documents.
class PdfPreviewScreen extends StatelessWidget {
  const PdfPreviewScreen({
    super.key,
    required this.documentId,
    required this.title,
    required this.pages,
    this.existingPdfPath,
    this.customCubit,
  });

  final String documentId;
  final String title;
  final List<ScannedPage> pages;
  final String? existingPdfPath;
  final PdfPreviewCubit? customCubit;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<PdfPreviewCubit>(
          create: (context) {
            if (customCubit != null) return customCubit!;
            final cubit = sl.isRegistered<PdfPreviewCubit>()
                ? sl<PdfPreviewCubit>(
                    param1: PdfPreviewArgs(
                      documentId: documentId,
                      title: title,
                      pages: pages,
                      existingPdfPath: existingPdfPath,
                    ),
                  )
                : PdfPreviewCubit(
                    generatePdfUseCase: sl<GeneratePdfUseCase>(),
                    sharePdfUseCase: sl<SharePdfUseCase>(),
                    saveDocumentUseCase: sl<SaveDocumentUseCase>(),
                    renamePdfUseCase: sl<RenamePdfUseCase>(),
                    deletePdfUseCase: sl<DeletePdfUseCase>(),
                    documentId: documentId,
                    title: title,
                    pages: pages,
                    existingPdfPath: existingPdfPath,
                  );
            if (existingPdfPath == null ||
                !File(existingPdfPath!).existsSync()) {
              cubit.compilePdf();
            }
            return cubit;
          },
        ),
        BlocProvider<SmartDocumentCubit>(
          create: (context) {
            final cubit = sl.isRegistered<SmartDocumentCubit>()
                ? sl<SmartDocumentCubit>()
                : SmartDocumentCubit(
                    recognizeDocumentUseCase: sl<RecognizeDocumentUseCase>(),
                    getDocumentRecognitionUseCase:
                        sl<GetDocumentRecognitionUseCase>(),
                    overrideDocumentTypeUseCase:
                        sl<OverrideDocumentTypeUseCase>(),
                    updateDocumentMetadataUseCase:
                        sl<UpdateDocumentMetadataUseCase>(),
                    suggestDocumentNameUseCase:
                        sl<SuggestDocumentNameUseCase>(),
                  );
            cubit.loadOrRecognize(documentId: documentId, pages: pages);
            return cubit;
          },
        ),
      ],
      child: _PdfPreviewView(
        documentId: documentId,
        pages: pages,
        pagesCount: pages.length,
      ),
    );
  }
}

class _PdfPreviewView extends StatelessWidget {
  const _PdfPreviewView({
    required this.documentId,
    required this.pages,
    required this.pagesCount,
  });

  final String documentId;
  final List<ScannedPage> pages;
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

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text(
          'Are you sure you want to permanently delete this document and all its scanned pages? This action cannot be undone.',
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
              context.read<PdfPreviewCubit>().deletePdf();
            },
            child: const Text('Delete'),
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
        } else if (state.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.successMessage!),
              backgroundColor: AppColors.success,
            ),
          );
        }

        if (state.isDeleted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
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
              // Open with external application
              IconButton(
                tooltip: 'Open with external app',
                icon: state.isOpeningExternal
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.open_in_new),
                onPressed:
                    (state.pdfPath != null &&
                        !state.isOpeningExternal &&
                        !state.isGenerating)
                    ? () => cubit.openExternal()
                    : null,
              ),

              // Advanced PDF Options
              IconButton(
                tooltip: PremiumConstants.isMonetizationHidden
                    ? 'Advanced PDF Options'
                    : 'Advanced PDF Options (Pro)',
                icon: const Icon(Icons.tune),
                onPressed: () {
                  final accessService = sl<FeatureAccessService>();
                  if (accessService.canUse(PremiumFeature.advancedPdfExport)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          PremiumConstants.isMonetizationHidden
                              ? 'Advanced PDF options active.'
                              : 'Advanced PDF options active (Pro).',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  } else {
                    FeatureGateSheet.show(
                      context,
                      feature: PremiumFeature.advancedPdfExport,
                    );
                  }
                },
              ),

              // Extract text (OCR)
              IconButton(
                tooltip: 'Extract Text (OCR)',
                icon: const Icon(Icons.document_scanner_outlined),
                onPressed: pages.isEmpty || state.isGenerating
                    ? null
                    : () {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.ocrViewer,
                          arguments: OcrViewerArgs(
                            documentId: documentId,
                            title: state.title,
                            pages: pages,
                          ),
                        );
                      },
              ),

              // Share PDF
              IconButton(
                tooltip: 'Share PDF',
                icon: state.isSharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.share, color: AppColors.primary),
                onPressed:
                    (state.pdfPath != null &&
                        !state.isSharing &&
                        !state.isGenerating)
                    ? () => cubit.sharePdf()
                    : null,
              ),

              // Delete document
              IconButton(
                tooltip: 'Delete document',
                icon: state.isDeleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.error,
                        ),
                      )
                    : const Icon(Icons.delete_outline, color: AppColors.error),
                onPressed: !state.isDeleting && !state.isGenerating
                    ? () => _showDeleteDialog(context)
                    : null,
              ),

              // Done
              IconButton(
                tooltip: 'Done',
                icon: const Icon(Icons.check),
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Smart Document Recognition Banner
              SmartDocumentCard(
                currentTitle: state.title,
                onApplyName: (newName) {
                  cubit.renameDocument(newName);
                },
                onEditName: () => _showRenameDialog(context, state.title),
              ),

              // PDF Viewer Canvas
              Expanded(
                child: BlocBuilder<PdfPreviewCubit, PdfPreviewState>(
                  buildWhen: (prev, curr) =>
                      prev.pdfPath != curr.pdfPath ||
                      prev.isGenerating != curr.isGenerating ||
                      prev.title != curr.title,
                  builder: (context, previewState) {
                    if (previewState.isGenerating ||
                        previewState.pdfPath == null) {
                      return const Center(
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
                      );
                    }
                    return PdfPreview(
                      build: (format) async =>
                          await File(previewState.pdfPath!).readAsBytes(),
                      canChangeOrientation: false,
                      canChangePageFormat: false,
                      canDebug: false,
                      allowPrinting: true,
                      allowSharing:
                          false, // Handled through native AnuScan ShareService
                      pdfFileName:
                          '${FileUtils.sanitizeFileName(previewState.title)}.pdf',
                    );
                  },
                ),
              ),

              // Bottom Info and Page Format Bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
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
                                Icon(
                                  state.isSaved
                                      ? Icons.check_circle
                                      : Icons.info_outline,
                                  size: 16,
                                  color: state.isSaved
                                      ? AppColors.success
                                      : AppColors.textSecondaryLight,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  state.isSaved ? 'Saved Locally' : 'Unsaved',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: state.isSaved
                                        ? AppColors.success
                                        : AppColors.textSecondaryLight,
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

                      // Manual Save Action Button
                      if (!state.isSaved) ...[
                        OutlinedButton.icon(
                          onPressed: (!state.isSaving && state.pdfPath != null)
                              ? () => cubit.savePdf()
                              : null,
                          icon: state.isSaving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_alt, size: 16),
                          label: const Text('Save'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],

                      // Page Size Format Selector Dropdown
                      DropdownButton<PdfPageSizeOption>(
                        value: state.pageSize,
                        underline: const SizedBox.shrink(),
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: AppColors.primary,
                        ),
                        items: PdfPageSizeOption.values.map((option) {
                          return DropdownMenuItem(
                            value: option,
                            child: Text(
                              option.displayName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (state.isGenerating || state.isDeleting)
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
