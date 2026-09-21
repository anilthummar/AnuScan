import 'package:equatable/equatable.dart';
import '../../../../core/services/pdf_generator_service.dart';

class PdfPreviewState extends Equatable {
  const PdfPreviewState({
    required this.documentId,
    required this.title,
    this.pdfPath,
    this.thumbnailPath,
    this.fileSizeBytes = 0,
    this.pageSize = PdfPageSizeOption.a4,
    this.isGenerating = false,
    this.isSaved = false,
    this.errorMessage,
  });

  final String documentId;
  final String title;
  final String? pdfPath;
  final String? thumbnailPath;
  final int fileSizeBytes;
  final PdfPageSizeOption pageSize;
  final bool isGenerating;
  final bool isSaved;
  final String? errorMessage;

  PdfPreviewState copyWith({
    String? documentId,
    String? title,
    String? pdfPath,
    String? thumbnailPath,
    int? fileSizeBytes,
    PdfPageSizeOption? pageSize,
    bool? isGenerating,
    bool? isSaved,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PdfPreviewState(
      documentId: documentId ?? this.documentId,
      title: title ?? this.title,
      pdfPath: pdfPath ?? this.pdfPath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      pageSize: pageSize ?? this.pageSize,
      isGenerating: isGenerating ?? this.isGenerating,
      isSaved: isSaved ?? this.isSaved,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        documentId,
        title,
        pdfPath,
        thumbnailPath,
        fileSizeBytes,
        pageSize,
        isGenerating,
        isSaved,
        errorMessage,
      ];
}
