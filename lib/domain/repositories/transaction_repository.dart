import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/transaction_entity.dart';

/// Abstract contract for all transaction data operations.
/// Domain and presentation depend ONLY on this — never on Firebase.
abstract class TransactionRepository {
  /// Real-time stream of transactions for [customerId], newest first.
  Stream<Either<Failure, List<TransactionEntity>>> watchTransactions(
      String customerId);

  /// Adds a new transaction AND atomically updates the customer balance.
  /// Returns the saved entity with a Firestore-generated ID.
  Future<Either<Failure, TransactionEntity>> addTransaction(
      TransactionEntity transaction);

  /// Updates a transaction AND recalculates the customer balance delta.
  /// [oldTransaction] is needed to reverse its previous balance effect.
  Future<Either<Failure, TransactionEntity>> updateTransaction({
    required TransactionEntity oldTransaction,
    required TransactionEntity newTransaction,
  });

  /// Deletes a transaction AND reverses its balance effect on the customer.
  Future<Either<Failure, void>> deleteTransaction(
      TransactionEntity transaction);

  /// Fetches all transactions for a user within a date range (for reports).
  Future<Either<Failure, List<TransactionEntity>>> getTransactionsByDateRange({
    required String userId,
    required DateTime from,
    required DateTime to,
  });

  /// Returns the count of transactions for a given customer.
  Future<Either<Failure, int>> getTransactionCount(String customerId);
}
