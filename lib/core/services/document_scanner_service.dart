import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import '../errors/exceptions.dart';

/// Abstract service interface for capturing physical documents using device camera scanner.
abstract class DocumentScannerService {
  /// Launches native physical document camera scanner.
  /// Returns a list of captured document image file paths.
  /// Returns an empty list if user cancelled without scanning.
  Future<List<String>> scanDocuments({int maxPages = 100});
}

/// Implementation of [DocumentScannerService] using `cunning_document_scanner`.
class DocumentScannerServiceImpl implements DocumentScannerService {
  const DocumentScannerServiceImpl();

  @override
  Future<List<String>> scanDocuments({int maxPages = 100}) async {
    try {
      final List<String>? pictures = await CunningDocumentScanner.getPictures(
        noOfPages: maxPages,
      );

      return pictures ?? <String>[];
    } catch (e) {
      // Check if user cancelled or error occurred
      final msg = e.toString().toLowerCase();
      if (msg.contains('cancel') || msg.contains('user_cancelled')) {
        return <String>[];
      }
      throw ScannerException('Document scanning failed: $e', e);
    }
  }
}
