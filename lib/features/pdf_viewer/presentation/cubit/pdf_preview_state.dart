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
    this.isSaving = false,
    this.isSaved = false,
    this.isSharing = false,
    this.isOpeningExternal = false,
    this.isDeleting = false,
    this.isDeleted = false,
    this.errorMessage,
    this.successMessage,
  });

  final String documentId;
  final String title;
  final String? pdfPath;
  final String? thumbnailPath;
  final int fileSizeBytes;
  final PdfPageSizeOption pageSize;
  final bool isGenerating;
  final bool isSaving;
  final bool isSaved;
  final bool isSharing;
  final bool isOpeningExternal;
  final bool isDeleting;
  final bool isDeleted;
  final String? errorMessage;
  final String? successMessage;

  PdfPreviewState copyWith({
    String? documentId,
    String? title,
    String? pdfPath,
    String? thumbnailPath,
    int? fileSizeBytes,
    PdfPageSizeOption? pageSize,
    bool? isGenerating,
    bool? isSaving,
    bool? isSaved,
    bool? isSharing,
    bool? isOpeningExternal,
    bool? isDeleting,
    bool? isDeleted,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return PdfPreviewState(
      documentId: documentId ?? this.documentId,
      title: title ?? this.title,
      pdfPath: pdfPath ?? this.pdfPath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      pageSize: pageSize ?? this.pageSize,
      isGenerating: isGenerating ?? this.isGenerating,
      isSaving: isSaving ?? this.isSaving,
      isSaved: isSaved ?? this.isSaved,
      isSharing: isSharing ?? this.isSharing,
      isOpeningExternal: isOpeningExternal ?? this.isOpeningExternal,
      isDeleting: isDeleting ?? this.isDeleting,
      isDeleted: isDeleted ?? this.isDeleted,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
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
    isSaving,
    isSaved,
    isSharing,
    isOpeningExternal,
    isDeleting,
    isDeleted,
    errorMessage,
    successMessage,
  ];
}
