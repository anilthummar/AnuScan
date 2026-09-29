import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:anuscan/core/services/secure_storage_service.dart';
import 'package:anuscan/core/services/private_document_encryption_service.dart';

class InMemorySecureStorageService implements SecureStorageService {
  final Map<String, String> _storage = {};

  @override
  Future<void> write(String key, String value) async {
    _storage[key] = value;
  }

  @override
  Future<String?> read(String key) async {
    return _storage[key];
  }

  @override
  Future<void> delete(String key) async {
    _storage.remove(key);
  }

  @override
  Future<void> clear() async {
    _storage.clear();
  }

  @override
  Future<bool> containsKey(String key) async {
    return _storage.containsKey(key);
  }
}

void main() {
  late InMemorySecureStorageService secureStorage;
  late PrivateDocumentEncryptionServiceImpl encryptionService;
  late Directory tempDir;

  setUp(() async {
    secureStorage = InMemorySecureStorageService();
    encryptionService = PrivateDocumentEncryptionServiceImpl(secureStorage);
    tempDir = await Directory.systemTemp.createTemp('anuscan_crypto_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('PrivateDocumentEncryptionService Tests', () {
    test('encryptBytes and decryptBytes round trip correctly', () async {
      const originalText = 'Highly confidential legal contract payload';
      final plainBytes = utf8.encode(originalText);

      final cipherBytes = await encryptionService.encryptBytes(plainBytes);

      // Verify magic header is present
      expect(
        cipherBytes.sublist(0, PrivateDocumentEncryptionServiceImpl.magicHeader.length),
        equals(PrivateDocumentEncryptionServiceImpl.magicHeader),
      );
      expect(cipherBytes, isNot(equals(plainBytes)));

      final decryptedBytes = await encryptionService.decryptBytes(cipherBytes);
      final decryptedText = utf8.decode(decryptedBytes);

      expect(decryptedText, equals(originalText));
    });

    test('encryptFile and decryptFile encrypt in place with isEncrypted detection', () async {
      final file = File('${tempDir.path}/test_doc.pdf');
      const originalContent = '%PDF-1.4 Mock confidential PDF document body';
      await file.writeAsString(originalContent);

      expect(await encryptionService.isEncrypted(file), isFalse);

      await encryptionService.encryptFile(file);
      expect(await encryptionService.isEncrypted(file), isTrue);
      final cipherBytes = await file.readAsBytes();
      expect(cipherBytes, isNot(equals(utf8.encode(originalContent))));

      await encryptionService.decryptFile(file);
      expect(await encryptionService.isEncrypted(file), isFalse);
      expect(await file.readAsString(), equals(originalContent));
    });
  });
}
