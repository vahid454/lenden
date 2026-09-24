import 'package:flutter_test/flutter_test.dart';
import 'package:lenden/domain/entities/payment_promise_entity.dart';

void main() {
  final now = DateTime(2026, 9, 24, 9);

  PaymentPromiseEntity promise({
    required DateTime date,
    PaymentPromiseStatus status = PaymentPromiseStatus.pending,
    double amount = 5000,
    double fulfilled = 0,
  }) =>
      PaymentPromiseEntity(
        id: 'promise-1',
        userId: 'user-1',
        customerId: 'customer-1',
        amount: amount,
        fulfilledAmount: fulfilled,
        promisedDate: date,
        status: status,
        createdAt: now,
        updatedAt: now,
      );

  test('classifies due, overdue and upcoming payment promises', () {
    final overdue = promise(date: DateTime(2026, 9, 23));
    final today = promise(date: DateTime(2026, 9, 24, 20));
    final upcoming = promise(date: DateTime(2026, 9, 30));

    expect(overdue.isOverdue(now), isTrue);
    expect(today.isDueOn(now), isTrue);
    expect(today.isDueThisWeek(now), isTrue);
    expect(upcoming.isDueThisWeek(now), isTrue);
    expect(upcoming.isOverdue(now), isFalse);
  });

  test('paid and partial promises preserve the correct remaining amount', () {
    final partial = promise(
      date: now,
      status: PaymentPromiseStatus.partialPaid,
      fulfilled: 3000,
    );
    final paid = promise(
      date: now,
      status: PaymentPromiseStatus.paid,
      fulfilled: 5000,
    );

    expect(partial.isOpen, isTrue);
    expect(partial.remainingAmount, 2000);
    expect(paid.isOpen, isFalse);
    expect(paid.remainingAmount, 0);
  });
}
