import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/transaction_entity.dart';
import '../repositories/transaction_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Each class = one business action. Presentation calls these; they call repo.
// ─────────────────────────────────────────────────────────────────────────────

/// Streams real-time transactions for a customer.
class WatchTransactionsUseCase {
  final TransactionRepository _repo;
  const WatchTransactionsUseCase(this._repo);

  Stream<Either<Failure, List<TransactionEntity>>> call(String customerId) =>
      _repo.watchTransactions(customerId);
}

/// Adds a transaction and updates the customer balance atomically.
class AddTransactionUseCase {
  final TransactionRepository _repo;
  const AddTransactionUseCase(this._repo);

  Future<Either<Failure, TransactionEntity>> call(
          TransactionEntity transaction) =>
      _repo.addTransaction(transaction);
}

/// Updates a transaction — reverses old balance delta, applies new one.
class UpdateTransactionUseCase {
  final TransactionRepository _repo;
  const UpdateTransactionUseCase(this._repo);

  Future<Either<Failure, TransactionEntity>> call({
    required TransactionEntity oldTransaction,
    required TransactionEntity newTransaction,
  }) =>
      _repo.updateTransaction(
        oldTransaction: oldTransaction,
        newTransaction: newTransaction,
      );
}

/// Deletes a transaction and reverses its balance effect.
class DeleteTransactionUseCase {
  final TransactionRepository _repo;
  const DeleteTransactionUseCase(this._repo);

  Future<Either<Failure, void>> call(TransactionEntity transaction) =>
      _repo.deleteTransaction(transaction);
}

/// Fetches transactions within a date range (used by Reports in Phase 4).
class GetTransactionsByDateRangeUseCase {
  final TransactionRepository _repo;
  const GetTransactionsByDateRangeUseCase(this._repo);

  Future<Either<Failure, List<TransactionEntity>>> call({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) =>
      _repo.getTransactionsByDateRange(userId: userId, from: from, to: to);
}

/// Returns the transaction count for a customer.
class GetTransactionCountUseCase {
  final TransactionRepository _repo;
  const GetTransactionCountUseCase(this._repo);

  Future<Either<Failure, int>> call(String customerId) =>
      _repo.getTransactionCount(customerId);
}
