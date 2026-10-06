import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/customer_remote_datasource.dart';
import '../../data/repositories/customer_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/repositories/customer_repository.dart';
import '../../domain/usecases/customer_usecases.dart';
import 'auth_providers.dart';

// ── Data source ───────────────────────────────────────────────────────────────

final customerRemoteDataSourceProvider =
    Provider<CustomerRemoteDataSource>((ref) {
  return CustomerRemoteDataSource(
    firestore: ref.watch(firestoreProvider),
    logger: ref.watch(loggerProvider),
  );
});

// ── Repository ────────────────────────────────────────────────────────────────

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepositoryImpl(
    remote: ref.watch(customerRemoteDataSourceProvider),
    logger: ref.watch(loggerProvider),
  );
});

// ── Use cases ─────────────────────────────────────────────────────────────────

final watchCustomersUseCaseProvider = Provider<WatchCustomersUseCase>(
    (ref) => WatchCustomersUseCase(ref.watch(customerRepositoryProvider)));
final addCustomerUseCaseProvider = Provider<AddCustomerUseCase>(
    (ref) => AddCustomerUseCase(ref.watch(customerRepositoryProvider)));
final updateCustomerUseCaseProvider = Provider<UpdateCustomerUseCase>(
    (ref) => UpdateCustomerUseCase(ref.watch(customerRepositoryProvider)));
final deleteCustomerUseCaseProvider = Provider<DeleteCustomerUseCase>(
    (ref) => DeleteCustomerUseCase(ref.watch(customerRepositoryProvider)));
final getCustomerUseCaseProvider = Provider<GetCustomerUseCase>(
    (ref) => GetCustomerUseCase(ref.watch(customerRepositoryProvider)));
final searchCustomersUseCaseProvider = Provider<SearchCustomersUseCase>(
    (ref) => SearchCustomersUseCase(ref.watch(customerRepositoryProvider)));

// ── Customers stream ──────────────────────────────────────────────────────────

final customersStreamProvider =
    StreamProvider<List<CustomerEntity>>((ref) async* {
  final user = ref.watch(currentUserProvider);
  // Guard: don't subscribe if user is null or has no id
  if (user == null || user.id.isEmpty) {
    yield [];
    return;
  }

  final remote = ref.watch(customerRemoteDataSourceProvider);
  await remote.ensurePhoneReservations(user.id);
  await remote.ensureSharedLedgerProjections(user.id);

  final useCase = ref.watch(watchCustomersUseCaseProvider);
  await for (final either in useCase(user.id)) {
    yield either.fold((_) => <CustomerEntity>[], (list) => list);
  }
});

final sharedCustomersStreamProvider =
    StreamProvider<List<CustomerEntity>>((ref) async* {
  final user = ref.watch(currentUserProvider);
  final phoneE164 = _phoneE164(user);
  if (user == null || user.id.isEmpty || phoneE164.isEmpty) {
    yield [];
    return;
  }

  final remote = ref.watch(customerRemoteDataSourceProvider);
  await for (final customers in remote.watchSharedLedgersByPhone(phoneE164)) {
    yield customers.where((customer) => customer.userId != user.id).toList();
  }
});

final visibleCustomersProvider = Provider<List<CustomerEntity>>((ref) {
  final owned = ref.watch(customersStreamProvider).valueOrNull ?? const [];
  final shared =
      ref.watch(sharedCustomersStreamProvider).valueOrNull ?? const [];

  final byId = <String, CustomerEntity>{
    for (final customer in owned) customer.id: customer,
  };
  for (final customer in shared) {
    byId[customer.id] = customer;
  }

  final merged = byId.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return merged;
});

// ── Derived stats ─────────────────────────────────────────────────────────────

final totalToReceiveProvider = Provider<double>((ref) {
  final customers = ref.watch(customersStreamProvider).valueOrNull ?? [];
  return customers
      .where((c) => c.balance > 0)
      .fold(0.0, (sum, c) => sum + c.balance);
});

final totalToPayProvider = Provider<double>((ref) {
  final customers = ref.watch(customersStreamProvider).valueOrNull ?? [];
  return customers
      .where((c) => c.balance < 0)
      .fold(0.0, (sum, c) => sum + c.absBalance);
});

final netBalanceProvider = Provider<double>((ref) {
  return ref.watch(totalToReceiveProvider) - ref.watch(totalToPayProvider);
});

String _phoneE164(UserEntity? user) {
  final digits = user?.phone.replaceAll(RegExp(r'\D'), '') ?? '';
  if (digits.length < 10) return '';
  return '+91${digits.substring(digits.length - 10)}';
}
