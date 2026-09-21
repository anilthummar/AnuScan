import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/import_gallery_usecase.dart';
import '../../domain/usecases/scan_documents_usecase.dart';
import 'scanner_state.dart';

/// Cubit managing scanning actions (camera scan or gallery import).
class ScannerCubit extends Cubit<ScannerState> {
  ScannerCubit({
    required this.scanDocumentsUseCase,
    required this.importGalleryUseCase,
  }) : super(const ScannerInitial());

  final ScanDocumentsUseCase scanDocumentsUseCase;
  final ImportGalleryUseCase importGalleryUseCase;

  Future<void> scanWithCamera() async {
    emit(const ScannerScanning());
    try {
      final paths = await scanDocumentsUseCase();
      if (paths.isEmpty) {
        emit(const ScannerCancelled());
      } else {
        emit(ScannerSuccess(paths));
      }
    } catch (e) {
      emit(ScannerError('Camera scanning failed: $e'));
    }
  }

  Future<void> importFromGallery() async {
    emit(const ScannerImporting());
    try {
      final paths = await importGalleryUseCase();
      if (paths.isEmpty) {
        emit(const ScannerCancelled());
      } else {
        emit(ScannerSuccess(paths));
      }
    } catch (e) {
      emit(ScannerError('Gallery import failed: $e'));
    }
  }

  void reset() {
    emit(const ScannerInitial());
  }
}
