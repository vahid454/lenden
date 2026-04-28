import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/transaction_remote_datasource.dart';
import '../../data/repositories/transaction_repository_impl.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/usecases/transaction_usecases.dart';
import 'auth_providers.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────

final transactionRemoteDataSourceProvider =
    Provider<TransactionRemoteDataSource>((ref) {
  return TransactionRemoteDataSource(
    firestore: ref.watch(firestoreProvider),
    logger:    ref.watch(loggerProvider),
  );
});

// ── Repository ────────────────────────────────────────────────────────────────

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepositoryImpl(
    remote: ref.watch(transactionRemoteDataSourceProvider),
    logger: ref.watch(loggerProvider),
  );
});

// ── Use cases ─────────────────────────────────────────────────────────────────

final watchTransactionsUseCaseProvider =
    Provider<WatchTransactionsUseCase>((ref) =>
        WatchTransactionsUseCase(ref.watch(transactionRepositoryProvider)));

final addTransactionUseCaseProvider =
    Provider<AddTransactionUseCase>((ref) =>
        AddTransactionUseCase(ref.watch(transactionRepositoryProvider)));

final updateTransactionUseCaseProvider =
    Provider<UpdateTransactionUseCase>((ref) =>
        UpdateTransactionUseCase(ref.watch(transactionRepositoryProvider)));

final deleteTransactionUseCaseProvider =
    Provider<DeleteTransactionUseCase>((ref) =>
        DeleteTransactionUseCase(ref.watch(transactionRepositoryProvider)));

final getTransactionsByDateRangeUseCaseProvider =
    Provider<GetTransactionsByDateRangeUseCase>((ref) =>
        GetTransactionsByDateRangeUseCase(
            ref.watch(transactionRepositoryProvider)));

// ── Stream per customer ───────────────────────────────────────────────────────

final transactionsStreamProvider = StreamProvider.autoDispose
    .family<List<TransactionEntity>, String>((ref, customerId) async* {
  // Emit a quick initial value so UI does not stay on shimmer
  // while Firestore establishes the first snapshot.
  yield const <TransactionEntity>[];

  // Guard: don't subscribe with empty id
  if (customerId.isEmpty) {
    return;
  }
  final useCase = ref.watch(watchTransactionsUseCaseProvider);
  await for (final either in useCase(customerId)) {
    yield either.fold((_) => <TransactionEntity>[], (list) => list);
  }
});
