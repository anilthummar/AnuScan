import 'package:equatable/equatable.dart';

/// Base class for all failure representations in the domain layer.
abstract class Failure extends Equatable {
  const Failure(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  List<Object?> get props => [message, cause];
}

class ScannerFailure extends Failure {
  const ScannerFailure([
    super.message = 'Document scanning failed or was cancelled',
    super.cause,
  ]);
}

class StorageFailure extends Failure {
  const StorageFailure([
    super.message = 'Storage operation failed',
    super.cause,
  ]);
}

class ImageProcessingFailure extends Failure {
  const ImageProcessingFailure([
    super.message = 'Image processing operation failed',
    super.cause,
  ]);
}

class PdfGenerationFailure extends Failure {
  const PdfGenerationFailure([
    super.message = 'PDF compilation failed',
    super.cause,
  ]);
}

class ShareFailure extends Failure {
  const ShareFailure([super.message = 'Failed to share document', super.cause]);
}

class AppDatabaseFailure extends Failure {
  const AppDatabaseFailure([
    super.message = 'Database operation failed',
    super.cause,
  ]);
}

class PermissionFailure extends Failure {
  const PermissionFailure([
    super.message = 'Required permission was denied',
    super.cause,
  ]);
}

class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'Validation failed', super.cause]);
}
