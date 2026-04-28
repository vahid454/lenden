import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';

import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/repositories/customer_repository.dart';
import '../datasources/customer_remote_datasource.dart';
import '../models/customer_model.dart';

/// Concrete implementation of [CustomerRepository].
/// Converts [AppException] thrown by the data source into [Failure] objects
/// so the domain and presentation layers stay decoupled from Firebase.
class CustomerRepositoryImpl implements CustomerRepository {
  final CustomerRemoteDataSource _remote;
  final Logger _logger;

  CustomerRepositoryImpl({
    required CustomerRemoteDataSource remote,
    Logger? logger,
  })  : _remote = remote,
        _logger = logger ?? Logger();

  // ── Watch ─────────────────────────────────────────────────────────────────

  @override
  Stream<Either<Failure, List<CustomerEntity>>> watchCustomers(String userId) {
    return _remote.watchCustomers(userId).map<Either<Failure, List<CustomerEntity>>>(
      (models) => Right(models),
    ).handleError((error) {
      _logger.e('watchCustomers stream error: $error');
      return Left<Failure, List<CustomerEntity>>(
        error is AppException
            ? ServerFailure(error.message)
            : const UnknownFailure(),
      );
    });
  }

  // ── Add ───────────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, CustomerEntity>> addCustomer(
      CustomerEntity customer) async {
    try {
      final model = CustomerModel.fromEntity(customer);
      final saved = await _remote.addCustomer(model);
      return Right(saved);
    } on AppException catch (e) {
      _logger.e('addCustomer: ${e.message}');
      return Left(ServerFailure(e.message));
    } catch (e) {
      _logger.e('addCustomer unknown: $e');
      return const Left(UnknownFailure());
    }
  }

  // ── Update ────────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, CustomerEntity>> updateCustomer(
      CustomerEntity customer) async {
    try {
      final model = CustomerModel.fromEntity(customer);
      final updated = await _remote.updateCustomer(model);
      return Right(updated);
    } on AppException catch (e) {
      _logger.e('updateCustomer: ${e.message}');
      return Left(ServerFailure(e.message));
    } catch (e) {
      _logger.e('updateCustomer unknown: $e');
      return const Left(UnknownFailure());
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, void>> deleteCustomer(String customerId) async {
    try {
      await _remote.deleteCustomer(customerId);
      return const Right(null);
    } on AppException catch (e) {
      _logger.e('deleteCustomer: ${e.message}');
      return Left(ServerFailure(e.message));
    } catch (e) {
      _logger.e('deleteCustomer unknown: $e');
      return const Left(UnknownFailure());
    }
  }

  // ── Get ───────────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, CustomerEntity>> getCustomer(
      String customerId) async {
    try {
      final model = await _remote.getCustomer(customerId);
      return Right(model);
    } on AppException catch (e) {
      _logger.e('getCustomer: ${e.message}');
      return e.code == 'not-found'
          ? const Left(NotFoundFailure())
          : Left(ServerFailure(e.message));
    } catch (e) {
      _logger.e('getCustomer unknown: $e');
      return const Left(UnknownFailure());
    }
  }

  // ── Search ────────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<CustomerEntity>>> searchCustomers({
    required String userId,
    required String query,
  }) async {
    try {
      final models = await _remote.searchCustomers(
        userId: userId,
        query: query,
      );
      return Right(models);
    } on AppException catch (e) {
      _logger.e('searchCustomers: ${e.message}');
      return Left(ServerFailure(e.message));
    } catch (e) {
      _logger.e('searchCustomers unknown: $e');
      return const Left(UnknownFailure());
    }
  }
}
