import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../errors/exceptions.dart';
import 'ocr_service.dart';

/// Concrete on-device OCR service powered by Google ML Kit Text Recognition.
/// Operates 100% offline with zero network connectivity or document uploading.
class MlKitOcrServiceImpl implements OcrService {
  MlKitOcrServiceImpl({
    TextRecognitionScript script = TextRecognitionScript.latin,
  }) : _recognizer = TextRecognizer(script: script);

  final TextRecognizer _recognizer;
  bool _isDisposed = false;

  @override
  Future<bool> isSupported() async {
    return Platform.isAndroid || Platform.isIOS;
  }

  @override
  Future<OcrResult> extractText(String imagePath) async {
    if (_isDisposed) {
      throw const StorageException(
        'Cannot extract text from disposed OCR engine',
      );
    }

    final file = File(imagePath);
    if (!await file.exists()) {
      throw StorageException('Image file not found for OCR: $imagePath');
    }

    final stopwatch = Stopwatch()..start();
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _recognizer.processImage(inputImage);
      stopwatch.stop();

      final blocks = <OcrTextBlock>[];
      for (final block in recognizedText.blocks) {
        final box = block.boundingBox;
        blocks.add(
          OcrTextBlock(
            text: block.text,
            confidence: 1.0,
            boundingBox: [box.left, box.top, box.right, box.bottom],
          ),
        );
      }

      return OcrResult(
        fullText: recognizedText.text,
        blocks: blocks,
        processingDurationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      throw StorageException('Failed to extract text using ML Kit: $e');
    }
  }

  @override
  Future<String?> generateTitleFromContent(String imagePath) async {
    try {
      final result = await extractText(imagePath);
      final lines = result.fullText
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && l.length > 3)
          .toList();
      if (lines.isNotEmpty) {
        final candidate = lines.first;
        return candidate.length > 30 ? candidate.substring(0, 30) : candidate;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> dispose() async {
    _isDisposed = true;
    await _recognizer.close();
  }
}
