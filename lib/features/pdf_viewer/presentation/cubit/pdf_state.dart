import 'package:equatable/equatable.dart';
import '../../../../core/services/pdf_generator_service.dart';

/// Base state for the PDF generation pipeline.
sealed class PdfState extends Equatable {
  const PdfState();

  @override
  List<Object?> get props => [];
}

/// Initial idle state.
final class PdfInitial extends PdfState {
  const PdfInitial();
}

/// Generation in progress with real-time fractional progress (0.0 to 1.0).
final class PdfGenerating extends PdfState {
  const PdfGenerating({
    required this.progress,
    required this.currentPage,
    required this.totalPages,
    this.message,
  });

  final double progress;
  final int currentPage;
  final int totalPages;
  final String? message;

  @override
  List<Object?> get props => [progress, currentPage, totalPages, message];
}

/// Generation completed successfully.
final class PdfSuccess extends PdfState {
  const PdfSuccess({
    required this.pdfPath,
    required this.fileSizeBytes,
    required this.pageCount,
    this.pageSize = PdfPageSizeOption.a4,
    this.quality = PdfQualityOption.standard,
  });

  final String pdfPath;
  final int fileSizeBytes;
  final int pageCount;
  final PdfPageSizeOption pageSize;
  final PdfQualityOption quality;

  @override
  List<Object?> get props => [
    pdfPath,
    fileSizeBytes,
    pageCount,
    pageSize,
    quality,
  ];
}

/// Generation failed with an error message.
final class PdfFailureState extends PdfState {
  const PdfFailureState(this.errorMessage);

  final String errorMessage;

  @override
  List<Object?> get props => [errorMessage];
}
