import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:lenden/core/errors/exceptions.dart';
import 'package:lenden/core/services/customer_photo_service.dart';

void main() {
  test('compresses a customer photo to a small square JPEG', () {
    final source = image_lib.Image(width: 900, height: 600);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        source.setPixelRgba(x, y, x % 256, y % 256, (x + y) % 256, 255);
      }
    }

    final compressed = CustomerPhotoService.compress(
      Uint8List.fromList(image_lib.encodePng(source)),
    );
    final decoded = image_lib.decodeJpg(compressed);

    expect(compressed.lengthInBytes, lessThanOrEqualTo(20 * 1024));
    expect(decoded, isNotNull);
    expect(decoded!.width, decoded.height);
    expect(decoded.width, lessThanOrEqualTo(320));
  });

  test('rejects unreadable photo bytes', () {
    expect(
      () => CustomerPhotoService.compress(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<AppException>()),
    );
  });
}
