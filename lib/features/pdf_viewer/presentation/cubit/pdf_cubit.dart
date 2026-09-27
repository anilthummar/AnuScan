import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/pdf_generator_service.dart';
import '../../../document_editor/domain/entities/document_session.dart';
import '../../../document_editor/domain/entities/scanned_page.dart';
import '../../domain/usecases/generate_pdf_usecase.dart';
import 'pdf_state.dart';

/// Cubit managing the multi-page PDF generation pipeline.
class PdfCubit extends Cubit<PdfState> {
  PdfCubit({required this.generatePdfUseCase}) : super(const PdfInitial());

  final GeneratePdfUseCase generatePdfUseCase;

  /// Generates a single PDF document from a [DocumentSession] with real-time progress updates.
  Future<void> generatePdfFromSession({
    required DocumentSession session,
    PdfPageSizeOption pageSize = PdfPageSizeOption.a4,
    PdfQualityOption quality = PdfQualityOption.standard,
  }) async {
    emit(
      PdfGenerating(
        progress: 0.0,
        currentPage: 0,
        totalPages: session.pageCount,
        message: 'Initializing PDF generation...',
      ),
    );

    try {
      final result = await generatePdfUseCase.fromSession(
        session: session,
        pageSize: pageSize,
        quality: quality,
        onProgress: (progress, current, total) {
          emit(
            PdfGenerating(
              progress: progress,
              currentPage: current,
              totalPages: total,
              message: 'Generating page $current of $total...',
            ),
          );
        },
      );

      result.fold(
        onFailure: (failure) {
          emit(PdfFailureState(failure.message));
        },
        onSuccess: (pdfPath) {
          final file = File(pdfPath);
          final size = file.existsSync() ? file.lengthSync() : 0;
          emit(
            PdfSuccess(
              pdfPath: pdfPath,
              fileSizeBytes: size,
              pageCount: session.pageCount,
              pageSize: pageSize,
              quality: quality,
            ),
          );
        },
      );
    } catch (e) {
      emit(PdfFailureState('Unexpected error during PDF compilation: $e'));
    }
  }

  /// Generates a single PDF document from a list of [ScanPage] objects.
  Future<void> generatePdfFromPages({
    required String documentId,
    required String title,
    required List<ScanPage> pages,
    PdfPageSizeOption pageSize = PdfPageSizeOption.a4,
    PdfQualityOption quality = PdfQualityOption.standard,
  }) async {
    emit(
      PdfGenerating(
        progress: 0.0,
        currentPage: 0,
        totalPages: pages.length,
        message: 'Initializing PDF generation...',
      ),
    );

    try {
      final result = await generatePdfUseCase.fromPages(
        documentId: documentId,
        title: title,
        pages: pages,
        pageSize: pageSize,
        quality: quality,
        onProgress: (progress, current, total) {
          emit(
            PdfGenerating(
              progress: progress,
              currentPage: current,
              totalPages: total,
              message: 'Generating page $current of $total...',
            ),
          );
        },
      );

      result.fold(
        onFailure: (failure) {
          emit(PdfFailureState(failure.message));
        },
        onSuccess: (pdfPath) {
          final file = File(pdfPath);
          final size = file.existsSync() ? file.lengthSync() : 0;
          emit(
            PdfSuccess(
              pdfPath: pdfPath,
              fileSizeBytes: size,
              pageCount: pages.length,
              pageSize: pageSize,
              quality: quality,
            ),
          );
        },
      );
    } catch (e) {
      emit(PdfFailureState('Unexpected error during PDF compilation: $e'));
    }
  }

  /// Resets back to [PdfInitial].
  void reset() => emit(const PdfInitial());
}
