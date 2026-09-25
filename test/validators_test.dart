import 'package:flutter_test/flutter_test.dart';
import 'package:lenden/core/utils/validators.dart';

void main() {
  group('email validation', () {
    test('requires an email when used for owner profile completion', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email('owner@example.com'), isNull);
    });

    test('keeps optional email validation available for optional forms', () {
      expect(Validators.optionalEmail(''), isNull);
      expect(Validators.optionalEmail('owner@example.com'), isNull);
    });
  });
}
