import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/pdf_generator_service.dart';
import '../../../document_editor/domain/entities/scanned_page.dart';
import '../../../document_history/domain/entities/document_entity.dart';
import '../../../document_history/domain/usecases/document_usecases.dart';
import '../../domain/usecases/generate_pdf_usecase.dart';
import '../../domain/usecases/share_pdf_usecase.dart';
import 'pdf_preview_state.dart';

class PdfPreviewCubit extends Cubit<PdfPreviewState> {
  PdfPreviewCubit({
    required this.generatePdfUseCase,
    required this.sharePdfUseCase,
    required this.saveDocumentUseCase,
    required this.pages,
    required String documentId,
    required String title,
  }) : super(PdfPreviewState(
          documentId: documentId,
          title: title,
        ));

  final GeneratePdfUseCase generatePdfUseCase;
  final SharePdfUseCase sharePdfUseCase;
  final SaveDocumentUseCase saveDocumentUseCase;
  final List<ScannedPage> pages;

  Future<void> compilePdf({PdfPageSizeOption? pageSize, String? title}) async {
    final effectivePageSize = pageSize ?? state.pageSize;
    final effectiveTitle = title ?? state.title;

    emit(state.copyWith(
      isGenerating: true,
      pageSize: effectivePageSize,
      title: effectiveTitle,
      clearError: true,
    ));

    try {
      final result = await generatePdfUseCase(
        documentId: state.documentId,
        title: effectiveTitle,
        pages: pages,
        pageSize: effectivePageSize,
      );

      emit(state.copyWith(
        pdfPath: result.pdfPath,
        thumbnailPath: result.thumbnailPath,
        fileSizeBytes: result.fileSizeBytes,
        isGenerating: false,
      ));

      // Automatically persist to local SQLite database
      await _autoSaveDocument();
    } catch (e) {
      emit(state.copyWith(
        isGenerating: false,
        errorMessage: 'Failed to compile PDF: $e',
      ));
    }
  }

  Future<void> _autoSaveDocument() async {
    if (state.pdfPath == null) return;

    try {
      final entity = DocumentEntity(
        id: state.documentId,
        title: state.title,
        pdfPath: state.pdfPath!,
        thumbnailPath: state.thumbnailPath,
        pageCount: pages.length,
        fileSizeBytes: state.fileSizeBytes,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        pages: pages,
      );

      await saveDocumentUseCase(entity);
      emit(state.copyWith(isSaved: true));
    } catch (e) {
      // Non-critical auto-save error
    }
  }

  Future<void> renameDocument(String newTitle) async {
    final sanitized = newTitle.trim();
    if (sanitized.isEmpty || sanitized == state.title) return;
    await compilePdf(title: sanitized);
  }

  Future<void> sharePdf() async {
    if (state.pdfPath == null) return;
    try {
      await sharePdfUseCase(state.pdfPath!, title: state.title);
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to share: $e'));
    }
  }
}
