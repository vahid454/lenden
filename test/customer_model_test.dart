import 'package:flutter_test/flutter_test.dart';
import 'package:lenden/data/models/customer_model.dart';

void main() {
  test('shared ledger projection includes ledger facts but omits private data',
      () {
    final customer = CustomerModel(
      id: 'owner_9876543210',
      userId: 'owner',
      name: 'Ramesh Kumar',
      phone: '9876543210',
      address: '12 Gandhi Nagar',
      ledgerPurpose: 'Samsung TV down payment',
      notes: 'Private collection note',
      photoPath: 'users/owner/customers/customer/profile.jpg',
      balance: 2500,
      ownerName: 'Firoz Bhai',
      ownerPhone: '+919999999999',
      isDefaulter: true,
      defaulterNote: 'Private risk note',
      createdAt: DateTime(2026, 9, 30),
    );

    final shared = customer.toSharedLedgerFirestore();

    expect(shared['phoneE164'], '+919876543210');
    expect(shared['ledgerPurpose'], 'Samsung TV down payment');
    expect(shared['address'], '12 Gandhi Nagar');
    expect(shared['balance'], 2500);
    expect(shared, isNot(contains('notes')));
    expect(shared, isNot(contains('photoPath')));
    expect(shared, isNot(contains('isDefaulter')));
    expect(shared, isNot(contains('defaulterNote')));
  });
}
