import '../../../../core/utils/result.dart';
import '../repositories/scanner_repository.dart';

/// Use case for executing document camera capture.
class ScanDocumentUseCase {
  const ScanDocumentUseCase(this._repository);

  final DocumentScannerRepository _repository;

  /// Captures a single document photograph and returns its file path.
  Future<Result<String>> call() async {
    return await _repository.captureDocument();
  }
}
