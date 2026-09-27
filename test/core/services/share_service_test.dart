import 'package:flutter_test/flutter_test.dart';
import 'package:anuscan/core/errors/exceptions.dart';
import 'package:anuscan/core/services/share_service.dart';

void main() {
  late ShareServiceImpl shareService;

  setUp(() {
    shareService = const ShareServiceImpl();
  });

  group('ShareServiceImpl', () {
    test(
      'shareFile throws StorageException when file does not exist',
      () async {
        expect(
          () => shareService.shareFile('/non_existent/path/to/doc.pdf'),
          throwsA(isA<StorageException>()),
        );
      },
    );

    test(
      'shareFiles throws StorageException when no valid files found',
      () async {
        expect(
          () => shareService.shareFiles([
            '/non_existent/file1.pdf',
            '/non_existent/file2.pdf',
          ]),
          throwsA(isA<StorageException>()),
        );
      },
    );

    test('openFile throws StorageException when file does not exist', () async {
      expect(
        () => shareService.openFile('/non_existent/path/to/doc.pdf'),
        throwsA(isA<StorageException>()),
      );
    });
  });
}
