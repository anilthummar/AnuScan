import 'package:equatable/equatable.dart';
import '../../domain/entities/document_entity.dart';

abstract class DocumentHistoryState extends Equatable {
  const DocumentHistoryState();

  @override
  List<Object?> get props => [];
}

class DocumentHistoryInitial extends DocumentHistoryState {
  const DocumentHistoryInitial();
}

class DocumentHistoryLoading extends DocumentHistoryState {
  const DocumentHistoryLoading();
}

class DocumentHistoryLoaded extends DocumentHistoryState {
  const DocumentHistoryLoaded({
    required this.documents,
    this.searchQuery = '',
  });

  final List<DocumentEntity> documents;
  final String searchQuery;

  bool get isSearching => searchQuery.isNotEmpty;

  @override
  List<Object?> get props => [documents, searchQuery];
}

class DocumentHistoryError extends DocumentHistoryState {
  const DocumentHistoryError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
