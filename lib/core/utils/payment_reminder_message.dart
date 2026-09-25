import 'app_formatters.dart';

class PaymentReminderMessage {
  PaymentReminderMessage._();

  static String build({
    required String customerName,
    required String senderName,
    required double amount,
    required bool ownerOwes,
    DateTime? dueDate,
  }) {
    final name = customerName.trim();
    final sender = senderName.trim().isEmpty ? 'LenDen' : senderName.trim();
    final amountText = AppFormatters.rupee(amount.abs());

    if (ownerOwes) {
      return 'Hi $name, I owe you $amountText. I will settle it soon. - $sender';
    }

    final dueText =
        dueDate == null ? '' : ', due ${AppFormatters.shortDate(dueDate)}';
    return 'Hi $name, you owe me $amountText$dueText. '
        'Kindly arrange the payment. - $sender';
  }
}
