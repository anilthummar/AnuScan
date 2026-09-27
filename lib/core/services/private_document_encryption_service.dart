import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'secure_storage_service.dart';

/// Contract for encrypting and decrypting sensitive document files on local storage.
abstract class PrivateDocumentEncryptionService {
  Future<void> encryptFile(File file);
  Future<void> decryptFile(File file);
  Future<List<int>> encryptBytes(List<int> plainBytes);
  Future<List<int>> decryptBytes(List<int> cipherBytes);
  Future<bool> isEncrypted(File file);
}

/// Production implementation of [PrivateDocumentEncryptionService] using AEAD AES-GCM 256.
class PrivateDocumentEncryptionServiceImpl
    implements PrivateDocumentEncryptionService {
  PrivateDocumentEncryptionServiceImpl(this._secureStorage, {AesGcm? algorithm})
    : _algorithm = algorithm ?? AesGcm.with256bits();

  final SecureStorageService _secureStorage;
  final AesGcm _algorithm;

  static const String keyMasterEncryptionKey =
      'anuscan_private_docs_master_key';

  // 8-byte magic header: 'A', 'N', 'U', 'E', 'N', 'C', '1', 0x00
  static const List<int> magicHeader = [
    0x41,
    0x4E,
    0x55,
    0x45,
    0x4E,
    0x43,
    0x31,
    0x00,
  ];

  Future<SecretKey> _getMasterKey() async {
    final existing = await _secureStorage.read(keyMasterEncryptionKey);
    if (existing != null && existing.isNotEmpty) {
      final keyBytes = base64Decode(existing);
      return SecretKey(keyBytes);
    }

    final newKey = await _algorithm.newSecretKey();
    final newBytes = await newKey.extractBytes();
    await _secureStorage.write(keyMasterEncryptionKey, base64Encode(newBytes));
    return newKey;
  }

  @override
  Future<bool> isEncrypted(File file) async {
    if (!await file.exists()) return false;
    try {
      final len = await file.length();
      if (len < magicHeader.length + 28) return false;

      final raf = await file.open(mode: FileMode.read);
      try {
        final header = await raf.read(magicHeader.length);
        if (header.length < magicHeader.length) return false;
        for (var i = 0; i < magicHeader.length; i++) {
          if (header[i] != magicHeader[i]) return false;
        }
        return true;
      } finally {
        await raf.close();
      }
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<int>> encryptBytes(List<int> plainBytes) async {
    final key = await _getMasterKey();
    final secretBox = await _algorithm.encrypt(plainBytes, secretKey: key);

    final concatenated = secretBox.concatenation();
    return [...magicHeader, ...concatenated];
  }

  @override
  Future<List<int>> decryptBytes(List<int> cipherBytes) async {
    if (cipherBytes.length < magicHeader.length + 28) {
      throw const FormatException('Ciphertext too short to be valid.');
    }

    for (var i = 0; i < magicHeader.length; i++) {
      if (cipherBytes[i] != magicHeader[i]) {
        throw const FormatException('Invalid encryption magic header.');
      }
    }

    final concatenated = cipherBytes.sublist(magicHeader.length);
    final secretBox = SecretBox.fromConcatenation(
      concatenated,
      nonceLength: 12,
      macLength: 16,
    );

    final key = await _getMasterKey();
    return await _algorithm.decrypt(secretBox, secretKey: key);
  }

  @override
  Future<void> encryptFile(File file) async {
    if (!await file.exists()) return;
    if (await isEncrypted(file)) return; // Already encrypted

    final plainBytes = await file.readAsBytes();
    final encryptedBytes = await encryptBytes(plainBytes);

    final tempFile = File('${file.path}.enc');
    try {
      await tempFile.writeAsBytes(encryptedBytes, flush: true);

      // Verify round-trip before removing plain data
      final testDecrypted = await decryptBytes(await tempFile.readAsBytes());
      if (!_bytesEqual(plainBytes, testDecrypted)) {
        throw StateError(
          'Verification failed: decrypted bytes did not match original data.',
        );
      }

      // Safe replace
      await tempFile.copy(file.path);
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  @override
  Future<void> decryptFile(File file) async {
    if (!await file.exists()) return;
    if (!await isEncrypted(file)) return; // Not encrypted

    final cipherBytes = await file.readAsBytes();
    final decryptedBytes = await decryptBytes(cipherBytes);

    final tempFile = File('${file.path}.dec');
    try {
      await tempFile.writeAsBytes(decryptedBytes, flush: true);
      await tempFile.copy(file.path);
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  bool _bytesEqual(List<int> a, List<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
