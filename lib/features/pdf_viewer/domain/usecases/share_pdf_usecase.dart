import '../../../../core/services/share_service.dart';

/// Use case for invoking native OS share sheet for a generated PDF.
class SharePdfUseCase {
  const SharePdfUseCase(this._shareService);

  final ShareService _shareService;

  Future<void> call(String pdfPath, {String? title}) async {
    await _shareService.shareFile(
      pdfPath,
      subject: title ?? 'Scanned Document',
      text: title != null ? 'Shared from AnuScan: $title' : 'Shared from AnuScan',
    );
  }
}
