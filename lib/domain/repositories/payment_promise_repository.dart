import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/payment_promise_entity.dart';

abstract class PaymentPromiseRepository {
  Stream<Either<Failure, List<PaymentPromiseEntity>>> watchPromises(
      String userId);

  Future<Either<Failure, PaymentPromiseEntity>> addPromise(
    PaymentPromiseEntity promise,
  );

  Future<Either<Failure, void>> recordContact({
    required PaymentPromiseEntity promise,
    String? note,
  });

  Future<Either<Failure, void>> recordPayment({
    required PaymentPromiseEntity promise,
    required double paymentAmount,
  });

  Future<Either<Failure, void>> reschedule({
    required PaymentPromiseEntity promise,
    required PaymentPromiseEntity replacement,
  });

  Future<Either<Failure, void>> markMissed(PaymentPromiseEntity promise);
}
