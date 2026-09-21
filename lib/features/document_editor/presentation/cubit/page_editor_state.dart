import 'package:equatable/equatable.dart';
import '../../../../core/services/image_processing_service.dart';
import '../../domain/entities/scanned_page.dart';

class PageEditorState extends Equatable {
  const PageEditorState({
    required this.currentPage,
    required this.selectedFilter,
    required this.currentRotation,
    this.currentCorners,
    this.isProcessing = false,
    this.hasUnsavedChanges = false,
    this.errorMessage,
  });

  final ScannedPage currentPage;
  final DocumentFilterType selectedFilter;
  final int currentRotation;
  final DocumentCornerPoints? currentCorners;
  final bool isProcessing;
  final bool hasUnsavedChanges;
  final String? errorMessage;

  PageEditorState copyWith({
    ScannedPage? currentPage,
    DocumentFilterType? selectedFilter,
    int? currentRotation,
    DocumentCornerPoints? currentCorners,
    bool? isProcessing,
    bool? hasUnsavedChanges,
    String? errorMessage,
    bool clearCorners = false,
    bool clearError = false,
  }) {
    return PageEditorState(
      currentPage: currentPage ?? this.currentPage,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      currentRotation: currentRotation ?? this.currentRotation,
      currentCorners: clearCorners ? null : (currentCorners ?? this.currentCorners),
      isProcessing: isProcessing ?? this.isProcessing,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        currentPage,
        selectedFilter,
        currentRotation,
        currentCorners,
        isProcessing,
        hasUnsavedChanges,
        errorMessage,
      ];
}
