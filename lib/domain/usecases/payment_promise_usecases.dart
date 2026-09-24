import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/payment_promise_entity.dart';
import '../repositories/payment_promise_repository.dart';

class WatchPaymentPromisesUseCase {
  final PaymentPromiseRepository _repository;
  const WatchPaymentPromisesUseCase(this._repository);
  Stream<Either<Failure, List<PaymentPromiseEntity>>> call(String userId) =>
      _repository.watchPromises(userId);
}

class AddPaymentPromiseUseCase {
  final PaymentPromiseRepository _repository;
  const AddPaymentPromiseUseCase(this._repository);
  Future<Either<Failure, PaymentPromiseEntity>> call(
          PaymentPromiseEntity promise) =>
      _repository.addPromise(promise);
}

class RecordPromiseContactUseCase {
  final PaymentPromiseRepository _repository;
  const RecordPromiseContactUseCase(this._repository);
  Future<Either<Failure, void>> call({
    required PaymentPromiseEntity promise,
    String? note,
  }) =>
      _repository.recordContact(promise: promise, note: note);
}

class RecordPromisePaymentUseCase {
  final PaymentPromiseRepository _repository;
  const RecordPromisePaymentUseCase(this._repository);
  Future<Either<Failure, void>> call({
    required PaymentPromiseEntity promise,
    required double paymentAmount,
  }) =>
      _repository.recordPayment(
        promise: promise,
        paymentAmount: paymentAmount,
      );
}

class ReschedulePaymentPromiseUseCase {
  final PaymentPromiseRepository _repository;
  const ReschedulePaymentPromiseUseCase(this._repository);
  Future<Either<Failure, void>> call({
    required PaymentPromiseEntity promise,
    required PaymentPromiseEntity replacement,
  }) =>
      _repository.reschedule(promise: promise, replacement: replacement);
}

class MarkPaymentPromiseMissedUseCase {
  final PaymentPromiseRepository _repository;
  const MarkPaymentPromiseMissedUseCase(this._repository);
  Future<Either<Failure, void>> call(PaymentPromiseEntity promise) =>
      _repository.markMissed(promise);
}
