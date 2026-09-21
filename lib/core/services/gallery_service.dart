import 'package:image_picker/image_picker.dart';
import '../errors/exceptions.dart';

/// Abstract service interface for importing documents/images from device gallery.
abstract class GalleryService {
  /// Picks multiple images from the device gallery.
  /// Returns a list of absolute file paths.
  Future<List<String>> pickMultipleImages();

  /// Picks a single image from the device gallery.
  /// Returns the absolute file path, or null if cancelled.
  Future<String?> pickSingleImage();
}

/// Implementation of [GalleryService] using `image_picker`.
class GalleryServiceImpl implements GalleryService {
  GalleryServiceImpl({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<List<String>> pickMultipleImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        imageQuality: 100, // Retain high resolution as required
      );
      return pickedFiles.map((x) => x.path).toList();
    } catch (e) {
      throw StorageException('Failed to pick images from gallery: $e', e);
    }
  }

  @override
  Future<String?> pickSingleImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      return pickedFile?.path;
    } catch (e) {
      throw StorageException('Failed to pick image from gallery: $e', e);
    }
  }
}
