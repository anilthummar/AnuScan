import 'package:flutter_test/flutter_test.dart';
import 'package:anuscan/core/errors/failures.dart';
import 'package:anuscan/core/services/image_processing_service.dart';
import 'package:anuscan/core/utils/result.dart';
import 'package:anuscan/features/document_editor/domain/entities/scanned_page.dart';
import 'package:anuscan/features/gallery/domain/repositories/gallery_repository.dart';
import 'package:anuscan/features/gallery/domain/usecases/import_gallery_images_usecase.dart';
import 'package:anuscan/features/gallery/presentation/cubit/gallery_cubit.dart';
import 'package:anuscan/features/gallery/presentation/cubit/gallery_state.dart';

class StubGalleryRepository implements GalleryRepository {
  Result<bool> permissionResult = const Result.success(true);
  Result<List<String>> pickResult = const Result.success(['/path/image1.jpg']);
  Result<List<ScannedPage>> processResult = Result.success([
    ScannedPage(
      id: 'page-1',
      documentId: 'doc-1',
      pageIndex: 0,
      originalImagePath: '/path/orig_1.jpg',
      processedImagePath: '/path/proc_1.jpg',
      filterType: DocumentFilterType.original,
      createdAt: DateTime.now(),
    ),
  ]);

  @override
  Future<Result<bool>> checkPermission() async => permissionResult;

  @override
  Future<Result<bool>> requestPermission() async => permissionResult;

  @override
  Future<Result<List<String>>> pickImages() async => pickResult;

  @override
  Future<Result<String?>> pickSingleImage() async =>
      const Result.success('/path/single.jpg');

  @override
  Future<Result<List<ScannedPage>>> processImportedImages({
    required List<String> rawPaths,
    required String documentId,
    int startIndex = 0,
    void Function(int current, int total)? onProgress,
  }) async {
    for (int i = 0; i < rawPaths.length; i++) {
      onProgress?.call(i + 1, rawPaths.length);
    }
    return processResult;
  }
}

void main() {
  late StubGalleryRepository repository;
  late ImportGalleryImagesUseCase useCase;
  late GalleryCubit cubit;

  setUp(() {
    repository = StubGalleryRepository();
    useCase = ImportGalleryImagesUseCase(repository);
    cubit = GalleryCubit(importGalleryImagesUseCase: useCase);
  });

  tearDown(() {
    cubit.close();
  });

  group('GalleryCubit', () {
    test('initial state is GalleryInitial', () {
      expect(cubit.state, equals(const GalleryInitial()));
    });

    test(
      'pickAndProcessImages emits [GalleryPicking, GalleryProcessing, GallerySuccess] on success',
      () async {
        final states = <GalleryState>[];
        cubit.stream.listen(states.add);

        await cubit.pickAndProcessImages(documentId: 'doc-1');
        await pumpEventQueue();

        expect(states.length, equals(3));
        expect(states[0], isA<GalleryPicking>());
        expect(states[1], isA<GalleryProcessing>());
        final processing = states[1] as GalleryProcessing;
        expect(processing.current, equals(1));
        expect(processing.total, equals(1));
        expect(processing.progress, equals(1.0));

        expect(states[2], isA<GallerySuccess>());
        final success = states[2] as GallerySuccess;
        expect(success.pages.length, equals(1));
        expect(success.pages.first.id, equals('page-1'));
      },
    );

    test(
      'pickAndProcessImages emits [GalleryPicking, GalleryCancelled] when user cancels picker',
      () async {
        repository.pickResult = const Result.success([]);
        final states = <GalleryState>[];
        cubit.stream.listen(states.add);

        await cubit.pickAndProcessImages(documentId: 'doc-1');
        await pumpEventQueue();

        expect(states.length, equals(2));
        expect(states[0], isA<GalleryPicking>());
        expect(states[1], isA<GalleryCancelled>());
      },
    );

    test(
      'pickAndProcessImages emits GalleryFailure with isPermissionDenied=true on permission denial',
      () async {
        repository.permissionResult = const Result<bool>.failure(
          PermissionFailure('Photos permission denied'),
        );
        final states = <GalleryState>[];
        cubit.stream.listen(states.add);

        await cubit.pickAndProcessImages(documentId: 'doc-1');
        await pumpEventQueue();

        expect(states.length, equals(2));
        expect(states[0], isA<GalleryPicking>());
        expect(states[1], isA<GalleryFailure>());
        final failure = states[1] as GalleryFailure;
        expect(failure.isPermissionDenied, isTrue);
        expect(failure.message, contains('permission denied'));
      },
    );

    test(
      'processRawPaths emits [GalleryProcessing, GallerySuccess] for pre-selected paths',
      () async {
        final states = <GalleryState>[];
        cubit.stream.listen(states.add);

        await cubit.processRawPaths(
          paths: ['/image1.jpg', '/image2.jpg'],
          documentId: 'doc-2',
        );
        await pumpEventQueue();

        expect(states.first, isA<GalleryProcessing>());
        expect(states.last, isA<GallerySuccess>());
      },
    );

    test(
      'processRawPaths emits GalleryCancelled when paths is empty',
      () async {
        final states = <GalleryState>[];
        cubit.stream.listen(states.add);

        await cubit.processRawPaths(paths: [], documentId: 'doc-2');

        expect(states, equals([const GalleryCancelled()]));
      },
    );

    test('cancel emits GalleryCancelled and stops progress updates', () async {
      cubit.cancel();
      expect(cubit.state, equals(const GalleryCancelled()));
    });

    test('reset restores state to GalleryInitial', () {
      cubit.cancel();
      expect(cubit.state, equals(const GalleryCancelled()));
      cubit.reset();
      expect(cubit.state, equals(const GalleryInitial()));
    });
  });
}
