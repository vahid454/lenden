import 'customer_entity.dart';
import 'payment_promise_entity.dart';

/// One customer-level row in a collection report.
///
/// [promise] is null when the customer owes money but has not committed to a
/// payment date yet. Keeping that row prevents outstanding money from being
/// omitted from collection exports.
class CollectionReportEntry {
  final CustomerEntity customer;
  final PaymentPromiseEntity? promise;
  final double? amountOverride;

  const CollectionReportEntry({
    required this.customer,
    this.promise,
    this.amountOverride,
  });

  double get collectionAmount =>
      amountOverride ?? promise?.remainingAmount ?? customer.absBalance;

  DateTime? get promisedDate => promise?.promisedDate;

  String get statusLabel => promise?.status.label ?? 'No promise';
}

/// Builds one collection row for every customer who currently owes money.
/// The earliest open promise is attached when one exists.
List<CollectionReportEntry> buildOutstandingCollectionEntries(
  Iterable<CustomerEntity> customers,
  Iterable<PaymentPromiseEntity> promises,
) {
  final nextPromise = <String, PaymentPromiseEntity>{};
  for (final promise in promises.where((item) => item.isOpen)) {
    final current = nextPromise[promise.customerId];
    if (current == null ||
        promise.promisedDate.isBefore(current.promisedDate)) {
      nextPromise[promise.customerId] = promise;
    }
  }

  return customers
      .where((customer) => customer.balance > 0)
      .map((customer) => CollectionReportEntry(
            customer: customer,
            promise: nextPromise[customer.id],
            amountOverride: customer.absBalance,
          ))
      .toList();
}
