import 'package:flutter_test/flutter_test.dart';
import 'package:lenden/domain/entities/collection_report_entry.dart';
import 'package:lenden/domain/entities/customer_entity.dart';
import 'package:lenden/domain/entities/payment_promise_entity.dart';

void main() {
  final now = DateTime(2026, 9, 25);

  CustomerEntity customer(String id, double balance) => CustomerEntity(
        id: id,
        userId: 'owner',
        name: 'Customer $id',
        phone: '900000000$id',
        createdAt: now,
        balance: balance,
      );

  PaymentPromiseEntity promise(
    String id,
    String customerId,
    DateTime date,
  ) =>
      PaymentPromiseEntity(
        id: id,
        userId: 'owner',
        customerId: customerId,
        amount: 500,
        promisedDate: date,
        createdAt: now,
        updatedAt: now,
      );

  test('all due report includes outstanding customer without a promise', () {
    final entries = buildOutstandingCollectionEntries(
      [customer('1', 1200), customer('2', 0), customer('3', -400)],
      const [],
    );

    expect(entries, hasLength(1));
    expect(entries.single.customer.id, '1');
    expect(entries.single.promise, isNull);
    expect(entries.single.collectionAmount, 1200);
    expect(entries.single.statusLabel, 'No promise');
  });

  test('all due report uses earliest open promise but full customer due', () {
    final entries = buildOutstandingCollectionEntries(
      [customer('1', 2000)],
      [
        promise('later', '1', DateTime(2026, 10, 20)),
        promise('earlier', '1', DateTime(2026, 10, 10)),
      ],
    );

    expect(entries.single.promise?.id, 'earlier');
    expect(entries.single.collectionAmount, 2000);
  });
}
