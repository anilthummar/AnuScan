import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../errors/exceptions.dart';

/// Available page formats for PDF compilation.
enum PdfPageSizeOption { a4, letter, fitImage }

extension PdfPageSizeOptionExtension on PdfPageSizeOption {
  String get displayName {
    switch (this) {
      case PdfPageSizeOption.a4:
        return 'A4 Standard';
      case PdfPageSizeOption.letter:
        return 'US Letter';
      case PdfPageSizeOption.fitImage:
        return 'Auto Fit';
    }
  }
}

/// Quality and compression profiles for PDF rendering.
enum PdfQualityOption { low, standard, high }

extension PdfQualityOptionExtension on PdfQualityOption {
  String get displayName {
    switch (this) {
      case PdfQualityOption.low:
        return 'Low (Smallest file)';
      case PdfQualityOption.standard:
        return 'Standard (Recommended)';
      case PdfQualityOption.high:
        return 'High (Maximum fidelity)';
    }
  }
}

/// Progress callback reporting current progress ratio (0.0 - 1.0) and page numbers.
typedef PdfProgressCallback =
    void Function(double progress, int currentPage, int totalPages);

/// Abstract service interface for generating multi-page PDF documents.
abstract class PdfGeneratorService {
  /// Compiles [imagePaths] into a single PDF document at [outputPath].
  ///
  /// - [pageSize]: A4, US Letter, or Auto Fit.
  /// - [quality]: Compression profile (Low, Standard, High).
  /// - [onProgress]: Real-time progress callback.
  ///
  /// Returns the generated PDF file path.
  Future<String> generatePdf({
    required List<String> imagePaths,
    required String outputPath,
    PdfPageSizeOption pageSize = PdfPageSizeOption.a4,
    PdfQualityOption quality = PdfQualityOption.standard,
    String? title,
    PdfProgressCallback? onProgress,
  });
}

/// Concrete implementation of [PdfGeneratorService] utilizing isolates for non-blocking UI
/// and real-time progress communication.
class PdfGeneratorServiceImpl implements PdfGeneratorService {
  const PdfGeneratorServiceImpl();

  @override
  Future<String> generatePdf({
    required List<String> imagePaths,
    required String outputPath,
    PdfPageSizeOption pageSize = PdfPageSizeOption.a4,
    PdfQualityOption quality = PdfQualityOption.standard,
    String? title,
    PdfProgressCallback? onProgress,
  }) async {
    if (imagePaths.isEmpty) {
      throw const PdfGenerationException('Cannot generate PDF from zero pages');
    }

    final completer = Completer<String>();
    final receivePort = ReceivePort();

    final params = _PdfIsolateParams(
      sendPort: receivePort.sendPort,
      imagePaths: List<String>.unmodifiable(imagePaths),
      outputPath: outputPath,
      pageSize: pageSize,
      quality: quality,
      title: title,
    );

    late Isolate isolate;
    StreamSubscription? subscription;

    void cleanup() {
      subscription?.cancel();
      receivePort.close();
    }

    subscription = receivePort.listen(
      (message) {
        if (message is Map<String, dynamic>) {
          final type = message['type'] as String?;
          switch (type) {
            case 'progress':
              final progress = (message['progress'] as num).toDouble();
              final current = message['current'] as int;
              final total = message['total'] as int;
              onProgress?.call(progress, current, total);
              break;

            case 'success':
              cleanup();
              if (!completer.isCompleted) {
                completer.complete(message['outputPath'] as String);
              }
              break;

            case 'error':
              cleanup();
              if (!completer.isCompleted) {
                completer.completeError(
                  PdfGenerationException(message['error'] as String),
                );
              }
              break;
          }
        }
      },
      onError: (Object error) {
        cleanup();
        if (!completer.isCompleted) {
          completer.completeError(
            PdfGenerationException(
              'Isolate communication error: $error',
              error,
            ),
          );
        }
      },
    );

    try {
      isolate = await Isolate.spawn(_generatePdfWorker, params);
      isolate.addOnExitListener(
        receivePort.sendPort,
        response: {
          'type': 'error',
          'error': 'Worker isolate exited unexpectedly',
        },
      );
    } catch (e) {
      cleanup();
      throw PdfGenerationException('Failed to launch PDF isolate: $e', e);
    }

    return completer.future;
  }
}

class _PdfIsolateParams {
  const _PdfIsolateParams({
    required this.sendPort,
    required this.imagePaths,
    required this.outputPath,
    required this.pageSize,
    required this.quality,
    this.title,
  });

  final SendPort sendPort;
  final List<String> imagePaths;
  final String outputPath;
  final PdfPageSizeOption pageSize;
  final PdfQualityOption quality;
  final String? title;
}

/// Worker running in separate background isolate.
Future<void> _generatePdfWorker(_PdfIsolateParams params) async {
  final sendPort = params.sendPort;

  try {
    final pdf = pw.Document(
      title: params.title ?? 'AnuScan Document',
      author: 'AnuScan',
      creator: 'AnuScan Document Scanner',
    );

    final total = params.imagePaths.length;

    for (int i = 0; i < total; i++) {
      final imagePath = params.imagePaths[i];
      final file = File(imagePath);

      if (!await file.exists()) {
        throw PdfGenerationException('Source image not found at $imagePath');
      }

      Uint8List? rawBytes = await file.readAsBytes();
      final processedBytes = _compressImageBytes(rawBytes, params.quality);
      rawBytes = null; // Release unneeded buffer early for GC

      final imageProvider = pw.MemoryImage(processedBytes);

      PdfPageFormat format;
      switch (params.pageSize) {
        case PdfPageSizeOption.a4:
          format = PdfPageFormat.a4;
          break;
        case PdfPageSizeOption.letter:
          format = PdfPageFormat.letter;
          break;
        case PdfPageSizeOption.fitImage:
          final w = imageProvider.width?.toDouble() ?? 595.0;
          final h = imageProvider.height?.toDouble() ?? 842.0;
          format = PdfPageFormat(w, h, marginAll: 0);
          break;
      }

      pdf.addPage(
        pw.Page(
          pageFormat: format,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Center(
                child: pw.Image(imageProvider, fit: pw.BoxFit.contain),
              ),
            );
          },
        ),
      );

      final progress = (i + 1) / total;
      sendPort.send({
        'type': 'progress',
        'current': i + 1,
        'total': total,
        'progress': progress,
      });
    }

    final pdfBytes = await pdf.save();
    final outputFile = File(params.outputPath);

    // Ensure parent folder exists
    final parentDir = outputFile.parent;
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }

    await outputFile.writeAsBytes(pdfBytes, flush: true);

    sendPort.send({'type': 'success', 'outputPath': params.outputPath});
  } catch (e) {
    sendPort.send({'type': 'error', 'error': e.toString()});
  }
}

/// Applies quality compression and memory bounds based on [quality] option.
/// Maximum A4 dimension at 300 DPI is capped at 2480x3508.
Uint8List _compressImageBytes(Uint8List rawBytes, PdfQualityOption quality) {
  try {
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) {
      return rawBytes;
    }

    final maxDimension = switch (quality) {
      PdfQualityOption.low => 1200,
      PdfQualityOption.standard => 1800,
      PdfQualityOption.high => 2480,
    };

    final jpegQuality = switch (quality) {
      PdfQualityOption.low => 60,
      PdfQualityOption.standard => 80,
      PdfQualityOption.high => 92,
    };

    if (quality == PdfQualityOption.high &&
        decoded.width <= maxDimension &&
        decoded.height <= maxDimension) {
      return rawBytes;
    }

    img.Image toProcess = decoded;
    if (decoded.width > maxDimension || decoded.height > maxDimension) {
      if (decoded.width >= decoded.height) {
        toProcess = img.copyResize(decoded, width: maxDimension);
      } else {
        toProcess = img.copyResize(decoded, height: maxDimension);
      }
    }

    return Uint8List.fromList(img.encodeJpg(toProcess, quality: jpegQuality));
  } catch (_) {
    return rawBytes;
  }
}
