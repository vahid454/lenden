import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';

import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/transaction_remote_datasource.dart';
import '../models/transaction_model.dart';

/// Converts [AppException] from the data source into [Failure] objects
/// so domain and presentation stay Firebase-free.
class TransactionRepositoryImpl implements TransactionRepository {
  final TransactionRemoteDataSource _remote;
  final Logger _log;

  TransactionRepositoryImpl({
    required TransactionRemoteDataSource remote,
    Logger? logger,
  })  : _remote = remote,
        _log    = logger ?? Logger();

  // ── Watch ─────────────────────────────────────────────────────────────────

  @override
  Stream<Either<Failure, List<TransactionEntity>>> watchTransactions(
      String customerId) {
    return _remote
        .watchTransactions(customerId)
        .map<Either<Failure, List<TransactionEntity>>>(Right.new)
        .handleError((e) {
      _log.e('watchTransactions error: $e');
      return Left<Failure, List<TransactionEntity>>(
        e is AppException ? ServerFailure(e.message) : const UnknownFailure(),
      );
    });
  }

  // ── Add ───────────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, TransactionEntity>> addTransaction(
      TransactionEntity transaction) async {
    try {
      final model  = TransactionModel.fromEntity(transaction);
      final result = await _remote.addTransaction(model);
      return Right(result);
    } on AppException catch (e) {
      _log.e('addTransaction: ${e.message}');
      return Left(ServerFailure(e.message));
    } catch (e) {
      _log.e('addTransaction unknown: $e');
      return const Left(UnknownFailure());
    }
  }

  // ── Update ────────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, TransactionEntity>> updateTransaction({
    required TransactionEntity oldTransaction,
    required TransactionEntity newTransaction,
  }) async {
    try {
      final result = await _remote.updateTransaction(
        oldTx: TransactionModel.fromEntity(oldTransaction),
        newTx: TransactionModel.fromEntity(newTransaction),
      );
      return Right(result);
    } on AppException catch (e) {
      _log.e('updateTransaction: ${e.message}');
      return Left(ServerFailure(e.message));
    } catch (e) {
      _log.e('updateTransaction unknown: $e');
      return const Left(UnknownFailure());
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, void>> deleteTransaction(
      TransactionEntity transaction) async {
    try {
      await _remote.deleteTransaction(transaction);
      return const Right(null);
    } on AppException catch (e) {
      _log.e('deleteTransaction: ${e.message}');
      return Left(ServerFailure(e.message));
    } catch (e) {
      _log.e('deleteTransaction unknown: $e');
      return const Left(UnknownFailure());
    }
  }

  // ── Date range ────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<TransactionEntity>>> getTransactionsByDateRange({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final results = await _remote.getTransactionsByDateRange(
        userId: userId,
        from:   from,
        to:     to,
      );
      return Right(results);
    } on AppException catch (e) {
      _log.e('getByDateRange: ${e.message}');
      return Left(ServerFailure(e.message));
    } catch (e) {
      _log.e('getByDateRange unknown: $e');
      return const Left(UnknownFailure());
    }
  }

  // ── Count ─────────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, int>> getTransactionCount(String customerId) async {
    try {
      final count = await _remote.getTransactionCount(customerId);
      return Right(count);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return const Left(UnknownFailure());
    }
  }
}
