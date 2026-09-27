import 'package:equatable/equatable.dart';
import '../../../../core/services/image_processing_service.dart';
import '../../domain/entities/scanned_page.dart';

/// State representation for the [PageEditorCubit].
class PageEditorState extends Equatable {
  const PageEditorState({
    required this.currentPage,
    required this.selectedFilter,
    required this.currentRotation,
    this.currentCorners,
    this.bwIntensity = BwIntensity.medium,
    this.isProcessing = false,
    this.hasUnsavedChanges = false,
    this.errorMessage,
  });

  final ScanPage currentPage;
  final ScanFilter selectedFilter;
  final int currentRotation;
  final CropCorners? currentCorners;
  final BwIntensity bwIntensity;
  final bool isProcessing;
  final bool hasUnsavedChanges;
  final String? errorMessage;

  bool get canReset => hasUnsavedChanges;
  bool get isRotated => currentRotation != 0;
  bool get hasCrop => currentCorners != null && !currentCorners!.isFullBounds;

  PageEditorState copyWith({
    ScanPage? currentPage,
    ScanFilter? selectedFilter,
    int? currentRotation,
    CropCorners? currentCorners,
    BwIntensity? bwIntensity,
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
      currentCorners: clearCorners
          ? null
          : (currentCorners ?? this.currentCorners),
      bwIntensity: bwIntensity ?? this.bwIntensity,
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
    bwIntensity,
    isProcessing,
    hasUnsavedChanges,
    errorMessage,
  ];
}
