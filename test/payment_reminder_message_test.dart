import 'package:flutter_test/flutter_test.dart';
import 'package:lenden/core/utils/payment_reminder_message.dart';

void main() {
  test('writes a polite receivable reminder with customer and business names',
      () {
    final message = PaymentReminderMessage.build(
      customerName: 'Ramesh',
      senderName: 'Smart Plaza',
      amount: 500,
      ownerOwes: false,
      dueDate: DateTime(2026, 9, 25),
    );

    expect(
      message,
      'Hi Ramesh, you owe me ₹500, due 25 Sep 2026. '
      'Kindly arrange the payment. - Smart Plaza',
    );
  });

  test('uses the correct direction when the owner owes the customer', () {
    final message = PaymentReminderMessage.build(
      customerName: 'Ramesh',
      senderName: 'Smart Plaza',
      amount: 500,
      ownerOwes: true,
    );

    expect(
      message,
      'Hi Ramesh, I owe you ₹500. I will settle it soon. - Smart Plaza',
    );
  });

  test('builds an English-only reminder with full amount and default warning',
      () {
    final message = PaymentReminderMessage.buildEnglish(
      customerName: 'Ramesh',
      ownerName: 'Firoz Bhai',
      businessName: 'Smart Plaza',
      amount: 1000,
    );

    expect(message, contains('Hello Ramesh Ji'));
    expect(message, contains('₹1,000 (One Thousand rupees)'));
    expect(message, contains('pending on your account at Smart Plaza'));
    expect(message, contains('avoid the risk of becoming a bank defaulter'));
    expect(message, isNot(contains('Namaste')));
    expect(message, isNot(contains('Hindi')));
  });

  test('does not warn about bank default when the owner owes the customer', () {
    final message = PaymentReminderMessage.buildEnglish(
      customerName: 'Ramesh',
      ownerName: 'Firoz Bhai',
      businessName: 'Smart Plaza',
      amount: -1000,
    );

    expect(message, contains('is owed to you by Firoz Bhai'));
    expect(message, isNot(contains('bank defaulter')));
  });
}
