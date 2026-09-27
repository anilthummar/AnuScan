import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:anuscan/core/services/gallery_service.dart';

void main() {
  late GalleryServiceImpl galleryService;
  late Directory tempDir;

  setUp(() async {
    galleryService = GalleryServiceImpl();
    tempDir = await Directory.systemTemp.createTemp('gallery_service_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('GalleryService image validation', () {
    test('returns false for non-existent file path', () async {
      final isValid = await galleryService.isImageValid(
        '${tempDir.path}/non_existent.jpg',
      );
      expect(isValid, isFalse);
    });

    test('returns false for zero-byte empty file', () async {
      final emptyFile = File('${tempDir.path}/empty.jpg');
      await emptyFile.writeAsBytes([], flush: true);

      final isValid = await galleryService.isImageValid(emptyFile.path);
      expect(isValid, isFalse);
    });

    test('returns false for non-image / corrupted text file', () async {
      final textFile = File('${tempDir.path}/corrupt.jpg');
      await textFile.writeAsString(
        'This is not an image file at all!',
        flush: true,
      );

      final isValid = await galleryService.isImageValid(textFile.path);
      expect(isValid, isFalse);
    });

    test('returns true for valid JPEG header bytes', () async {
      final jpegFile = File('${tempDir.path}/valid.jpg');
      // Standard JPEG SOI marker FF D8 FF E0
      final jpegBytes = Uint8List.fromList([
        0xFF,
        0xD8,
        0xFF,
        0xE0,
        0x00,
        0x10,
        0x4A,
        0x46,
        0x49,
        0x46,
        0x00,
        0x01,
      ]);
      await jpegFile.writeAsBytes(jpegBytes, flush: true);

      final isValid = await galleryService.isImageValid(jpegFile.path);
      expect(isValid, isTrue);
    });

    test('returns true for valid PNG header bytes', () async {
      final pngFile = File('${tempDir.path}/valid.png');
      // Standard PNG header: 89 50 4E 47 0D 0A 1A 0A
      final pngBytes = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
      ]);
      await pngFile.writeAsBytes(pngBytes, flush: true);

      final isValid = await galleryService.isImageValid(pngFile.path);
      expect(isValid, isTrue);
    });
  });
}
