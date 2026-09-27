import 'package:equatable/equatable.dart';

/// Represents a recognized text block within an OCR scan.
class OcrTextBlock extends Equatable {
  const OcrTextBlock({
    required this.text,
    this.confidence = 1.0,
    this.boundingBox,
  });

  final String text;
  final double confidence;
  final List<double>? boundingBox; // [left, top, right, bottom]

  @override
  List<Object?> get props => [text, confidence, boundingBox];
}

/// Result of an OCR text extraction session.
class OcrResult extends Equatable {
  const OcrResult({
    required this.fullText,
    this.blocks = const [],
    this.suggestedTitle,
    this.language,
    this.processingDurationMs,
  });

  final String fullText;
  final List<OcrTextBlock> blocks;
  final String? suggestedTitle;
  final String? language;
  final int? processingDurationMs;

  @override
  List<Object?> get props => [
    fullText,
    blocks,
    suggestedTitle,
    language,
    processingDurationMs,
  ];
}

/// Abstract contract for Optical Character Recognition (OCR) and text extraction.
abstract class OcrService {
  /// Whether OCR is supported and enabled on the current device.
  Future<bool> isSupported();

  /// Extracts plain text and blocks from an image path.
  Future<OcrResult> extractText(String imagePath);

  /// Suggests a document title from document contents.
  Future<String?> generateTitleFromContent(String imagePath);

  /// Releases any underlying OCR engine resources.
  Future<void> dispose();
}

/// Default stub implementation of [OcrService] ready for extension.
class StubOcrServiceImpl implements OcrService {
  const StubOcrServiceImpl();

  @override
  Future<bool> isSupported() async => false;

  @override
  Future<OcrResult> extractText(String imagePath) async {
    return const OcrResult(fullText: '', blocks: []);
  }

  @override
  Future<String?> generateTitleFromContent(String imagePath) async {
    return null;
  }

  @override
  Future<void> dispose() async {}
}
