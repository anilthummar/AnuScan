/// Base class for all application exceptions.
class AppException implements Exception {
  const AppException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'AppException: $message${cause != null ? ' (Cause: $cause)' : ''}';
}

class ScannerException extends AppException {
  const ScannerException([super.message = 'Scanner operation failed or cancelled', super.cause]);
}

class StorageException extends AppException {
  const StorageException([super.message = 'Storage access or I/O failure', super.cause]);
}

class ImageProcessingException extends AppException {
  const ImageProcessingException([super.message = 'Image transformation failed', super.cause]);
}

class PdfGenerationException extends AppException {
  const PdfGenerationException([super.message = 'PDF compilation failed', super.cause]);
}

class ShareException extends AppException {
  const ShareException([super.message = 'Sharing operation failed', super.cause]);
}

class AppDatabaseException extends AppException {
  const AppDatabaseException([super.message = 'Database operation failed', super.cause]);
}

class PermissionException extends AppException {
  const PermissionException([super.message = 'Permission denied', super.cause]);
}
