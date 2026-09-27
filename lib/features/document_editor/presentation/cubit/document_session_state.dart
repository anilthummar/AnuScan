import 'package:equatable/equatable.dart';
import '../../domain/entities/document_session.dart';

/// State representation for an active [DocumentSession].
class DocumentSessionState extends Equatable {
  const DocumentSessionState({
    required this.session,
    this.selectedPageIndex = 0,
    this.isProcessing = false,
    this.processingMessage,
    this.errorMessage,
  });

  final DocumentSession session;
  final int selectedPageIndex;
  final bool isProcessing;
  final String? processingMessage;
  final String? errorMessage;

  int get pageCount => session.pageCount;
  bool get isEmpty => session.isEmpty;
  bool get isNotEmpty => session.isNotEmpty;

  DocumentSessionPage? get selectedPage {
    if (session.pages.isEmpty ||
        selectedPageIndex < 0 ||
        selectedPageIndex >= session.pages.length) {
      return session.pages.isNotEmpty ? session.pages.first : null;
    }
    return session.pages[selectedPageIndex];
  }

  DocumentSessionState copyWith({
    DocumentSession? session,
    int? selectedPageIndex,
    bool? isProcessing,
    String? processingMessage,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DocumentSessionState(
      session: session ?? this.session,
      selectedPageIndex: selectedPageIndex ?? this.selectedPageIndex,
      isProcessing: isProcessing ?? this.isProcessing,
      processingMessage: processingMessage ?? this.processingMessage,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    session,
    selectedPageIndex,
    isProcessing,
    processingMessage,
    errorMessage,
  ];
}
