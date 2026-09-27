import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/pdf_generator_service.dart';
import '../../../document_editor/domain/entities/scanned_page.dart';
import '../../../document_history/domain/entities/document_entity.dart';
import '../../../document_history/domain/usecases/document_usecases.dart';
import '../../domain/usecases/delete_pdf_usecase.dart';
import '../../domain/usecases/generate_pdf_usecase.dart';
import '../../domain/usecases/rename_pdf_usecase.dart';
import '../../domain/usecases/share_pdf_usecase.dart';
import 'pdf_preview_state.dart';

class PdfPreviewCubit extends Cubit<PdfPreviewState> {
  PdfPreviewCubit({
    required this.generatePdfUseCase,
    required this.sharePdfUseCase,
    required this.saveDocumentUseCase,
    this.renamePdfUseCase,
    this.deletePdfUseCase,
    required this.pages,
    required String documentId,
    required String title,
    String? existingPdfPath,
  }) : super(
         PdfPreviewState(
           documentId: documentId,
           title: title,
           pdfPath: existingPdfPath,
           fileSizeBytes:
               existingPdfPath != null && File(existingPdfPath).existsSync()
               ? File(existingPdfPath).lengthSync()
               : 0,
           isSaved: existingPdfPath != null,
         ),
       );

  final GeneratePdfUseCase generatePdfUseCase;
  final SharePdfUseCase sharePdfUseCase;
  final SaveDocumentUseCase saveDocumentUseCase;
  final RenamePdfUseCase? renamePdfUseCase;
  final DeletePdfUseCase? deletePdfUseCase;
  final List<ScannedPage> pages;

  Future<void> compilePdf({PdfPageSizeOption? pageSize, String? title}) async {
    final effectivePageSize = pageSize ?? state.pageSize;
    final effectiveTitle = title ?? state.title;

    emit(
      state.copyWith(
        isGenerating: true,
        pageSize: effectivePageSize,
        title: effectiveTitle,
        clearError: true,
        clearSuccess: true,
      ),
    );

    try {
      final result = await generatePdfUseCase(
        documentId: state.documentId,
        title: effectiveTitle,
        pages: pages,
        pageSize: effectivePageSize,
      );

      emit(
        state.copyWith(
          pdfPath: result.pdfPath,
          thumbnailPath: result.thumbnailPath,
          fileSizeBytes: result.fileSizeBytes,
          isGenerating: false,
        ),
      );

      // Automatically persist to local SQLite database
      await _autoSaveDocument();
    } catch (e) {
      emit(
        state.copyWith(
          isGenerating: false,
          errorMessage: 'Failed to compile PDF: $e',
        ),
      );
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
    } catch (_) {
      // Non-critical auto-save error
    }
  }

  Future<void> savePdf() async {
    if (state.pdfPath == null) {
      emit(
        state.copyWith(
          errorMessage: 'No PDF available to save. Please wait for generation.',
        ),
      );
      return;
    }

    emit(state.copyWith(isSaving: true, clearError: true));

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
      emit(
        state.copyWith(
          isSaving: false,
          isSaved: true,
          successMessage: 'Document saved successfully',
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isSaving: false,
          errorMessage: 'Failed to save document: $e',
        ),
      );
    }
  }

  Future<void> renameDocument(String newTitle) async {
    final sanitized = newTitle.trim();
    if (sanitized.isEmpty) {
      emit(state.copyWith(errorMessage: 'Document title cannot be empty'));
      return;
    }
    if (sanitized == state.title) return;

    if (renamePdfUseCase != null && state.pdfPath != null) {
      final result = await renamePdfUseCase!(
        documentId: state.documentId,
        currentPdfPath: state.pdfPath!,
        newTitle: sanitized,
      );

      result.fold(
        onFailure: (failure) {
          emit(state.copyWith(errorMessage: failure.message));
        },
        onSuccess: (newPath) {
          emit(
            state.copyWith(
              title: sanitized,
              pdfPath: newPath,
              successMessage: 'Document renamed to "$sanitized"',
              clearError: true,
            ),
          );
        },
      );
    } else {
      await compilePdf(title: sanitized);
    }
  }

  Future<void> sharePdf() async {
    if (state.pdfPath == null) {
      emit(
        state.copyWith(
          errorMessage:
              'No PDF available to share. Please wait for generation.',
        ),
      );
      return;
    }

    final file = File(state.pdfPath!);
    if (!await file.exists()) {
      emit(
        state.copyWith(
          errorMessage:
              'PDF file not found. It may have been moved or deleted.',
        ),
      );
      return;
    }

    emit(state.copyWith(isSharing: true, clearError: true));
    try {
      final result = await sharePdfUseCase(state.pdfPath!, title: state.title);
      result.fold(
        onFailure: (failure) {
          emit(state.copyWith(isSharing: false, errorMessage: failure.message));
        },
        onSuccess: (_) {
          emit(state.copyWith(isSharing: false));
        },
      );
    } catch (e) {
      emit(
        state.copyWith(isSharing: false, errorMessage: 'Failed to share: $e'),
      );
    }
  }

  Future<void> openExternal() async {
    if (state.pdfPath == null) {
      emit(
        state.copyWith(
          errorMessage: 'No PDF available to open. Please wait for generation.',
        ),
      );
      return;
    }

    final file = File(state.pdfPath!);
    if (!await file.exists()) {
      emit(
        state.copyWith(
          errorMessage:
              'PDF file not found. It may have been moved or deleted.',
        ),
      );
      return;
    }

    emit(state.copyWith(isOpeningExternal: true, clearError: true));
    try {
      final result = await sharePdfUseCase.openExternal(state.pdfPath!);
      result.fold(
        onFailure: (failure) {
          emit(
            state.copyWith(
              isOpeningExternal: false,
              errorMessage: failure.message,
            ),
          );
        },
        onSuccess: (_) {
          emit(state.copyWith(isOpeningExternal: false));
        },
      );
    } catch (e) {
      emit(
        state.copyWith(
          isOpeningExternal: false,
          errorMessage: 'Failed to open with external app: $e',
        ),
      );
    }
  }

  Future<void> deletePdf() async {
    emit(state.copyWith(isDeleting: true, clearError: true));

    if (deletePdfUseCase != null) {
      final result = await deletePdfUseCase!(
        documentId: state.documentId,
        pdfPath: state.pdfPath,
      );

      result.fold(
        onFailure: (failure) {
          emit(
            state.copyWith(isDeleting: false, errorMessage: failure.message),
          );
        },
        onSuccess: (_) {
          emit(
            state.copyWith(
              isDeleting: false,
              isDeleted: true,
              successMessage: 'Document deleted successfully',
            ),
          );
        },
      );
    } else {
      emit(
        state.copyWith(
          isDeleting: false,
          isDeleted: true,
          successMessage: 'Document deleted',
        ),
      );
    }
  }
}
