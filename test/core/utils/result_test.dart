import 'package:flutter_test/flutter_test.dart';
import 'package:anuscan/core/errors/failures.dart';
import 'package:anuscan/core/utils/result.dart';

void main() {
  group('Result<T> and Failure hierarchy', () {
    test('Success holds value and reports isSuccess = true', () {
      const result = Result<int>.success(42);

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.dataOrNull, equals(42));
      expect(result.failureOrNull, isNull);
    });

    test('Error holds Failure and reports isFailure = true', () {
      const failure = StorageFailure('Disk full');
      const result = Result<int>.failure(failure);

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.dataOrNull, isNull);
      expect(result.failureOrNull, equals(failure));
    });

    test('fold correctly routes to onSuccess or onFailure', () {
      const successResult = Result<String>.success('hello');
      final successValue = successResult.fold(
        onFailure: (f) => 'failed',
        onSuccess: (val) => '$val world',
      );
      expect(successValue, equals('hello world'));

      const errorResult = Result<String>.failure(ScannerFailure('cancelled'));
      final errorValue = errorResult.fold(
        onFailure: (f) => f.message,
        onSuccess: (val) => val,
      );
      expect(errorValue, equals('cancelled'));
    });

    test('map transforms value on success and preserves failure on error', () {
      const successResult = Result<int>.success(10);
      final mappedSuccess = successResult.map((n) => n * 2);
      expect(mappedSuccess, equals(const Result.success(20)));

      const errorResult = Result<int>.failure(AppDatabaseFailure('Corrupted'));
      final mappedError = errorResult.map((n) => n * 2);
      expect(
        mappedError,
        equals(const Result<int>.failure(AppDatabaseFailure('Corrupted'))),
      );
    });

    test(
      'Failure subclasses instantiate with default messages and equality',
      () {
        expect(const ScannerFailure().message, contains('scanning'));
        expect(const StorageFailure().message, contains('Storage'));
        expect(
          const ImageProcessingFailure().message,
          contains('Image processing'),
        );
        expect(const PdfGenerationFailure().message, contains('PDF'));
        expect(const ShareFailure().message, contains('share'));
        expect(const AppDatabaseFailure().message, contains('Database'));
        expect(const PermissionFailure().message, contains('permission'));

        expect(
          const StorageFailure('err'),
          equals(const StorageFailure('err')),
        );
        expect(
          const StorageFailure('err'),
          isNot(equals(const StorageFailure('other'))),
        );
      },
    );
  });
}
