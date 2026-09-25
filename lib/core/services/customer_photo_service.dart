import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as image_lib;
import 'package:image_picker/image_picker.dart';

import '../errors/exceptions.dart';

class CustomerPhotoService {
  final FirebaseStorage _storage;
  final ImagePicker _picker;

  CustomerPhotoService({
    FirebaseStorage? storage,
    ImagePicker? picker,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _picker = picker ?? ImagePicker();

  Future<Uint8List?> pickAndCompress(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 88,
      requestFullMetadata: false,
    );
    if (picked == null) return null;

    return compress(await picked.readAsBytes());
  }

  static Uint8List compress(Uint8List sourceBytes) {
    image_lib.Image? decoded;
    try {
      decoded = image_lib.decodeImage(sourceBytes);
    } catch (_) {
      throw const AppException(
        'This photo could not be read. Please choose another image.',
        code: 'invalid-image',
      );
    }
    if (decoded == null) {
      throw const AppException(
        'This photo could not be read. Please choose another image.',
        code: 'invalid-image',
      );
    }

    final oriented = image_lib.bakeOrientation(decoded);
    Uint8List? smallest;
    for (final size in [320, 280, 240, 200, 160]) {
      final square = image_lib.copyResizeCropSquare(oriented, size: size);
      for (final quality in [72, 58, 46, 36, 28, 20]) {
        final bytes = Uint8List.fromList(
          image_lib.encodeJpg(square, quality: quality),
        );
        smallest = bytes;
        if (bytes.lengthInBytes <= 20 * 1024) return bytes;
      }
    }

    return smallest!;
  }

  Future<String> upload({
    required String userId,
    required String customerId,
    required Uint8List bytes,
  }) async {
    final path = 'users/$userId/customers/$customerId/profile.jpg';
    try {
      await _storage.ref(path).putData(
            bytes,
            SettableMetadata(
              contentType: 'image/jpeg',
              cacheControl: 'private,max-age=604800',
            ),
          );
      return path;
    } on FirebaseException catch (error) {
      final detail = (error.message ?? '').toLowerCase();
      final storageNotReady = error.code == 'storage/bucket-not-found' ||
          detail.contains('bucket') ||
          detail.contains('not been set up');
      throw AppException(
        storageNotReady
            ? 'Customer was saved, but Firebase Storage is not set up yet.'
            : 'Customer was saved, but the photo could not upload: ${error.message}',
        code: error.code,
      );
    }
  }

  Future<Uint8List?> load(String path) async {
    if (path.isEmpty) return null;
    try {
      return await _storage.ref(path).getData(100 * 1024);
    } on FirebaseException {
      return null;
    }
  }
}
