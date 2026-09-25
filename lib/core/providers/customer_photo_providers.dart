import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/customer_photo_service.dart';

final customerPhotoServiceProvider = Provider<CustomerPhotoService>(
  (_) => CustomerPhotoService(),
);

final customerPhotoBytesProvider =
    FutureProvider.family<Uint8List?, String>((ref, path) {
  return ref.watch(customerPhotoServiceProvider).load(path);
});
