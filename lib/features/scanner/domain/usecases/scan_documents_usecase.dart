import '../repositories/scanner_repository.dart';

/// Use case for invoking the physical document camera scanner.
class ScanDocumentsUseCase {
  const ScanDocumentsUseCase(this._repository);

  final ScannerRepository _repository;

  Future<List<String>> call() async {
    return await _repository.scanDocuments();
  }
}
