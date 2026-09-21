import 'package:equatable/equatable.dart';
import '../../domain/entities/scanned_page.dart';

class DocumentEditorState extends Equatable {
  const DocumentEditorState({
    required this.documentId,
    required this.title,
    this.pages = const [],
    this.selectedPageIndex = 0,
    this.isProcessing = false,
    this.processingMessage,
    this.errorMessage,
  });

  final String documentId;
  final String title;
  final List<ScannedPage> pages;
  final int selectedPageIndex;
  final bool isProcessing;
  final String? processingMessage;
  final String? errorMessage;

  ScannedPage? get selectedPage {
    if (pages.isEmpty || selectedPageIndex < 0 || selectedPageIndex >= pages.length) {
      return pages.isNotEmpty ? pages.first : null;
    }
    return pages[selectedPageIndex];
  }

  DocumentEditorState copyWith({
    String? documentId,
    String? title,
    List<ScannedPage>? pages,
    int? selectedPageIndex,
    bool? isProcessing,
    String? processingMessage,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DocumentEditorState(
      documentId: documentId ?? this.documentId,
      title: title ?? this.title,
      pages: pages ?? this.pages,
      selectedPageIndex: selectedPageIndex ?? this.selectedPageIndex,
      isProcessing: isProcessing ?? this.isProcessing,
      processingMessage: processingMessage ?? this.processingMessage,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        documentId,
        title,
        pages,
        selectedPageIndex,
        isProcessing,
        processingMessage,
        errorMessage,
      ];
}
