import 'package:equatable/equatable.dart';
import '../../domain/entities/ocr_entities.dart';

abstract class OcrState extends Equatable {
  const OcrState();

  @override
  List<Object?> get props => [];
}

class OcrInitial extends OcrState {
  const OcrInitial();
}

class OcrLoading extends OcrState {
  const OcrLoading({this.message = 'Preparing document text...'});

  final String message;

  @override
  List<Object?> get props => [message];
}

class OcrProgress extends OcrState {
  const OcrProgress({
    required this.currentPageIndex,
    required this.totalPages,
    required this.progress,
    required this.statusMessage,
    this.partialResults = const [],
  });

  final int currentPageIndex;
  final int totalPages;
  final double progress;
  final String statusMessage;
  final List<OcrPageResult> partialResults;

  @override
  List<Object?> get props => [
    currentPageIndex,
    totalPages,
    progress,
    statusMessage,
    partialResults,
  ];
}

class OcrSuccess extends OcrState {
  const OcrSuccess({
    required this.result,
    this.isFromCache = false,
    this.searchMatches = const [],
    this.activeSearchQuery,
  });

  final DocumentOcrResult result;
  final bool isFromCache;
  final List<OcrSearchMatch> searchMatches;
  final String? activeSearchQuery;

  OcrSuccess copyWith({
    DocumentOcrResult? result,
    bool? isFromCache,
    List<OcrSearchMatch>? searchMatches,
    String? activeSearchQuery,
    bool clearSearch = false,
  }) {
    return OcrSuccess(
      result: result ?? this.result,
      isFromCache: isFromCache ?? this.isFromCache,
      searchMatches: clearSearch
          ? const []
          : (searchMatches ?? this.searchMatches),
      activeSearchQuery: clearSearch
          ? null
          : (activeSearchQuery ?? this.activeSearchQuery),
    );
  }

  @override
  List<Object?> get props => [
    result,
    isFromCache,
    searchMatches,
    activeSearchQuery,
  ];
}

class OcrFailure extends OcrState {
  const OcrFailure({required this.message, this.partialResults = const []});

  final String message;
  final List<OcrPageResult> partialResults;

  @override
  List<Object?> get props => [message, partialResults];
}

class OcrCancelled extends OcrState {
  const OcrCancelled({this.partialResults = const []});

  final List<OcrPageResult> partialResults;

  @override
  List<Object?> get props => [partialResults];
}
