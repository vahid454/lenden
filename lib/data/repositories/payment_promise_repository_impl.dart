import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';

import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/payment_promise_entity.dart';
import '../../domain/repositories/payment_promise_repository.dart';
import '../datasources/payment_promise_remote_datasource.dart';
import '../models/payment_promise_model.dart';

class PaymentPromiseRepositoryImpl implements PaymentPromiseRepository {
  final PaymentPromiseRemoteDataSource _remote;
  final Logger _log;

  PaymentPromiseRepositoryImpl({
    required PaymentPromiseRemoteDataSource remote,
    Logger? logger,
  })  : _remote = remote,
        _log = logger ?? Logger();

  @override
  Stream<Either<Failure, List<PaymentPromiseEntity>>> watchPromises(
          String userId) =>
      _remote
          .watchPromises(userId)
          .map<Either<Failure, List<PaymentPromiseEntity>>>(
            (promises) => Right<Failure, List<PaymentPromiseEntity>>(
              promises.cast<PaymentPromiseEntity>(),
            ),
          )
          .handleError((error) {
        _log.e('watchPromises error: $error');
        return Left<Failure, List<PaymentPromiseEntity>>(
          error is AppException
              ? ServerFailure(error.message)
              : const UnknownFailure(),
        );
      });

  @override
  Future<Either<Failure, PaymentPromiseEntity>> addPromise(
    PaymentPromiseEntity promise,
  ) async {
    try {
      return Right(
          await _remote.addPromise(PaymentPromiseModel.fromEntity(promise)));
    } on AppException catch (error) {
      return Left(ServerFailure(error.message));
    } catch (error) {
      _log.e('addPromise error: $error');
      return const Left(UnknownFailure());
    }
  }

  @override
  Future<Either<Failure, void>> recordContact({
    required PaymentPromiseEntity promise,
    String? note,
  }) =>
      _run(() => _remote.recordContact(promise: promise, note: note));

  @override
  Future<Either<Failure, void>> recordPayment({
    required PaymentPromiseEntity promise,
    required double paymentAmount,
  }) =>
      _run(() => _remote.recordPayment(
            promise: promise,
            paymentAmount: paymentAmount,
          ));

  @override
  Future<Either<Failure, void>> reschedule({
    required PaymentPromiseEntity promise,
    required PaymentPromiseEntity replacement,
  }) =>
      _run(() => _remote.reschedule(
            promise: promise,
            replacement: PaymentPromiseModel.fromEntity(replacement),
          ));

  @override
  Future<Either<Failure, void>> markMissed(PaymentPromiseEntity promise) =>
      _run(() => _remote.markMissed(promise));

  Future<Either<Failure, void>> _run(Future<void> Function() operation) async {
    try {
      await operation();
      return const Right(null);
    } on AppException catch (error) {
      return Left(ServerFailure(error.message));
    } catch (error) {
      _log.e('payment promise operation error: $error');
      return const Left(UnknownFailure());
    }
  }
}
