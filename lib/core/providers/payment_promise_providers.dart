import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/payment_promise_remote_datasource.dart';
import '../../data/repositories/payment_promise_repository_impl.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/entities/payment_promise_entity.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/payment_promise_repository.dart';
import '../../domain/usecases/payment_promise_usecases.dart';
import 'auth_providers.dart';
import 'customer_providers.dart';
import 'transaction_providers.dart';

enum PaymentPromiseFilter {
  all,
  dueToday,
  dueTomorrow,
  dueThisWeek,
  overdue,
  noPromiseDate,
  paid,
  partialPaid,
  defaulters,
}

extension PaymentPromiseFilterX on PaymentPromiseFilter {
  String get label => switch (this) {
        PaymentPromiseFilter.all => 'All',
        PaymentPromiseFilter.dueToday => 'Due today',
        PaymentPromiseFilter.dueTomorrow => 'Tomorrow',
        PaymentPromiseFilter.dueThisWeek => 'This week',
        PaymentPromiseFilter.overdue => 'Overdue',
        PaymentPromiseFilter.noPromiseDate => 'No promise',
        PaymentPromiseFilter.paid => 'Paid',
        PaymentPromiseFilter.partialPaid => 'Partial paid',
        PaymentPromiseFilter.defaulters => 'Defaulters',
      };

  bool matches(PaymentPromiseEntity promise, DateTime now) => switch (this) {
        PaymentPromiseFilter.all => true,
        PaymentPromiseFilter.dueToday => promise.isOpen && promise.isDueOn(now),
        PaymentPromiseFilter.dueTomorrow =>
          promise.isOpen && promise.isDueOn(now.add(const Duration(days: 1))),
        PaymentPromiseFilter.dueThisWeek => promise.isDueThisWeek(now),
        PaymentPromiseFilter.overdue => promise.isOverdue(now),
        PaymentPromiseFilter.noPromiseDate => false,
        PaymentPromiseFilter.paid =>
          promise.status == PaymentPromiseStatus.paid,
        PaymentPromiseFilter.partialPaid =>
          promise.status == PaymentPromiseStatus.partialPaid,
        PaymentPromiseFilter.defaulters => false,
      };
}

final paymentPromiseRemoteDataSourceProvider =
    Provider<PaymentPromiseRemoteDataSource>(
        (ref) => PaymentPromiseRemoteDataSource(
              firestore: ref.watch(firestoreProvider),
              logger: ref.watch(loggerProvider),
            ));

final paymentPromiseRepositoryProvider =
    Provider<PaymentPromiseRepository>((ref) => PaymentPromiseRepositoryImpl(
          remote: ref.watch(paymentPromiseRemoteDataSourceProvider),
          logger: ref.watch(loggerProvider),
        ));

final watchPaymentPromisesUseCaseProvider =
    Provider<WatchPaymentPromisesUseCase>((ref) => WatchPaymentPromisesUseCase(
        ref.watch(paymentPromiseRepositoryProvider)));
final addPaymentPromiseUseCaseProvider = Provider<AddPaymentPromiseUseCase>(
    (ref) =>
        AddPaymentPromiseUseCase(ref.watch(paymentPromiseRepositoryProvider)));
final recordPromiseContactUseCaseProvider =
    Provider<RecordPromiseContactUseCase>((ref) => RecordPromiseContactUseCase(
        ref.watch(paymentPromiseRepositoryProvider)));
final recordPromisePaymentUseCaseProvider =
    Provider<RecordPromisePaymentUseCase>((ref) => RecordPromisePaymentUseCase(
        ref.watch(paymentPromiseRepositoryProvider)));
final reschedulePaymentPromiseUseCaseProvider =
    Provider<ReschedulePaymentPromiseUseCase>((ref) =>
        ReschedulePaymentPromiseUseCase(
            ref.watch(paymentPromiseRepositoryProvider)));
final markPaymentPromiseMissedUseCaseProvider =
    Provider<MarkPaymentPromiseMissedUseCase>((ref) =>
        MarkPaymentPromiseMissedUseCase(
            ref.watch(paymentPromiseRepositoryProvider)));
final cancelPaymentPromiseUseCaseProvider =
    Provider<CancelPaymentPromiseUseCase>((ref) => CancelPaymentPromiseUseCase(
        ref.watch(paymentPromiseRepositoryProvider)));

final paymentPromisesStreamProvider =
    StreamProvider<List<PaymentPromiseEntity>>((ref) async* {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null || userId.isEmpty) {
    yield const [];
    return;
  }
  await for (final result
      in ref.watch(watchPaymentPromisesUseCaseProvider)(userId)) {
    yield result.fold((_) => <PaymentPromiseEntity>[], (promises) => promises);
  }
});

final promisePaymentHistoryProvider =
    FutureProvider.autoDispose<List<TransactionEntity>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  final promises = ref.watch(paymentPromisesStreamProvider).valueOrNull;
  if (userId == null ||
      userId.isEmpty ||
      promises == null ||
      promises.isEmpty) {
    return const [];
  }

  final firstPromiseDate = promises
      .map((promise) => promise.createdAt)
      .reduce((a, b) => a.isBefore(b) ? a : b);
  final start = DateTime(
    firstPromiseDate.year,
    firstPromiseDate.month,
    firstPromiseDate.day,
  );
  final result = await ref.read(getTransactionsByDateRangeUseCaseProvider)(
    userId: userId,
    from: start,
    to: DateTime.now(),
  );
  return result.fold(
    (failure) => throw StateError(failure.message),
    (transactions) => transactions,
  );
});

final promisesForCustomerProvider =
    Provider.family<List<PaymentPromiseEntity>, String>((ref, customerId) {
  final promises =
      ref.watch(paymentPromisesStreamProvider).valueOrNull ?? const [];
  return promises.where((promise) => promise.customerId == customerId).toList()
    ..sort((a, b) => b.promisedDate.compareTo(a.promisedDate));
});

final nextOpenPromiseByCustomerProvider =
    Provider<Map<String, PaymentPromiseEntity>>((ref) {
  final promises =
      ref.watch(paymentPromisesStreamProvider).valueOrNull ?? const [];
  final customers = {
    for (final customer in ref.watch(visibleCustomersProvider))
      customer.id: customer,
  };
  final result = <String, PaymentPromiseEntity>{};
  for (final promise in promises.where((item) => item.isOpen)) {
    if ((customers[promise.customerId]?.balance ?? 0) <= 0) continue;
    final current = result[promise.customerId];
    if (current == null ||
        promise.promisedDate.isBefore(current.promisedDate)) {
      result[promise.customerId] = promise;
    }
  }
  return result;
});

final paymentPromiseFilterProvider =
    StateProvider<PaymentPromiseFilter>((ref) => PaymentPromiseFilter.all);

final filteredCustomersByPromiseProvider =
    Provider<List<CustomerEntity>>((ref) {
  final filter = ref.watch(paymentPromiseFilterProvider);
  final customers = ref.watch(visibleCustomersProvider);
  if (filter == PaymentPromiseFilter.all) return customers;
  if (filter == PaymentPromiseFilter.defaulters) {
    return customers.where((customer) => customer.isDefaulter).toList();
  }

  final now = DateTime.now();
  final promises =
      ref.watch(paymentPromisesStreamProvider).valueOrNull ?? const [];
  final byCustomer = <String, List<PaymentPromiseEntity>>{};
  for (final promise in promises) {
    byCustomer.putIfAbsent(promise.customerId, () => []).add(promise);
  }
  return customers.where((customer) {
    final customerPromises = byCustomer[customer.id] ?? const [];
    if (filter == PaymentPromiseFilter.noPromiseDate) {
      return customer.balance > 0 &&
          !customerPromises.any((item) => item.isOpen);
    }
    return customerPromises.any((promise) => filter.matches(promise, now));
  }).toList();
});

final followUpPromisesProvider = Provider<List<PaymentPromiseEntity>>((ref) {
  final now = DateTime.now();
  final promises =
      ref.watch(paymentPromisesStreamProvider).valueOrNull ?? const [];
  final customers = {
    for (final customer in ref.watch(visibleCustomersProvider))
      customer.id: customer,
  };
  return promises
      .where((promise) =>
          (customers[promise.customerId]?.balance ?? 0) > 0 &&
          (promise.isOverdue(now) || promise.isDueThisWeek(now)))
      .toList()
    ..sort((a, b) {
      final aPriority = a.isOverdue(now) ? 0 : 1;
      final bPriority = b.isOverdue(now) ? 0 : 1;
      return aPriority != bPriority
          ? aPriority.compareTo(bPriority)
          : a.promisedDate.compareTo(b.promisedDate);
    });
});

final paymentPromiseActionsProvider =
    Provider<PaymentPromiseActions>((ref) => PaymentPromiseActions(ref));

class PaymentPromiseActions {
  final Ref _ref;
  PaymentPromiseActions(this._ref);

  Future<String?> add(PaymentPromiseEntity promise) async {
    final result = await _ref.read(addPaymentPromiseUseCaseProvider)(promise);
    return result.fold((failure) => failure.message, (_) => null);
  }

  Future<String?> contact(PaymentPromiseEntity promise, {String? note}) async {
    final result = await _ref.read(recordPromiseContactUseCaseProvider)(
      promise: promise,
      note: note,
    );
    return result.fold((failure) => failure.message, (_) => null);
  }

  Future<String?> payment(PaymentPromiseEntity promise, double amount) async {
    final result = await _ref.read(recordPromisePaymentUseCaseProvider)(
      promise: promise,
      paymentAmount: amount,
    );
    return result.fold((failure) => failure.message, (_) => null);
  }

  Future<String?> reconcilePaymentHistory(
    PaymentPromiseEntity promise,
    List<TransactionEntity> transactions,
  ) {
    final created = DateTime(
      promise.createdAt.year,
      promise.createdAt.month,
      promise.createdAt.day,
    );
    final due = DateTime(
      promise.promisedDate.year,
      promise.promisedDate.month,
      promise.promisedDate.day,
    );
    final received = transactions.where((transaction) {
      final paymentDay = DateTime(
        transaction.date.year,
        transaction.date.month,
        transaction.date.day,
      );
      return transaction.customerId == promise.customerId &&
          transaction.userId == promise.userId &&
          transaction.isGot &&
          transaction.amount > 0 &&
          !paymentDay.isBefore(created) &&
          !paymentDay.isAfter(due);
    }).fold<double>(0, (sum, transaction) => sum + transaction.amount);
    return received > 0 ? payment(promise, received) : Future.value(null);
  }

  Future<String?> reschedule({
    required PaymentPromiseEntity promise,
    required PaymentPromiseEntity replacement,
  }) async {
    final result = await _ref.read(reschedulePaymentPromiseUseCaseProvider)(
      promise: promise,
      replacement: replacement,
    );
    return result.fold((failure) => failure.message, (_) => null);
  }

  Future<String?> markMissed(PaymentPromiseEntity promise) async {
    final result =
        await _ref.read(markPaymentPromiseMissedUseCaseProvider)(promise);
    return result.fold((failure) => failure.message, (_) => null);
  }

  Future<String?> cancel(PaymentPromiseEntity promise) async {
    final result =
        await _ref.read(cancelPaymentPromiseUseCaseProvider)(promise);
    return result.fold((failure) => failure.message, (_) => null);
  }
}
