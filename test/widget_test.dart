import 'package:flutter_test/flutter_test.dart';
import 'package:lenden/domain/entities/customer_entity.dart';
import 'package:lenden/domain/entities/transaction_entity.dart';

void main() {
  test('customer initials and balance helpers work', () {
    final customer = CustomerEntity(
      id: 'c1',
      userId: 'u1',
      name: 'Rahul Sharma',
      phone: '9999999999',
      createdAt: DateTime(2024),
      balance: 1250,
    );

    expect(customer.initials, 'RS');
    expect(customer.isCreditor, isTrue);
    expect(customer.absBalance, 1250);
  });

  test('transaction type keeps balance direction correct', () {
    final gave = TransactionEntity(
      id: 't1',
      customerId: 'c1',
      userId: 'u1',
      amount: 500,
      type: TransactionType.gave,
      date: DateTime(2024),
      createdAt: DateTime(2024),
    );

    final got = TransactionEntity(
      id: 't2',
      customerId: 'c1',
      userId: 'u1',
      amount: 300,
      type: TransactionType.got,
      date: DateTime(2024),
      createdAt: DateTime(2024),
    );

    expect(gave.balanceDelta, 500);
    expect(got.balanceDelta, -300);
  });
}
