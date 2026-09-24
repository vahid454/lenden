import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../domain/entities/payment_promise_entity.dart';
import '../models/payment_promise_model.dart';

class PaymentPromiseRemoteDataSource {
  final FirebaseFirestore _db;
  final Logger _log;

  PaymentPromiseRemoteDataSource({
    required FirebaseFirestore firestore,
    Logger? logger,
  })  : _db = firestore,
        _log = logger ?? Logger();

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection(AppConstants.colPaymentPromises);

  Stream<List<PaymentPromiseModel>> watchPromises(String userId) => _collection
          .where('userId', isEqualTo: userId)
          .snapshots()
          .handleError((error) => _log.e('watchPromises error: $error'))
          .map((snapshot) {
        final promises =
            snapshot.docs.map(PaymentPromiseModel.fromFirestore).toList();
        promises.sort((a, b) => a.promisedDate.compareTo(b.promisedDate));
        return promises;
      });

  Future<PaymentPromiseModel> addPromise(PaymentPromiseModel promise) async {
    try {
      final ref = _collection.doc();
      await ref.set(promise.toFirestore());
      return PaymentPromiseModel.fromEntity(promise.copyWith(id: ref.id));
    } on FirebaseException catch (error) {
      _log.e('addPromise: ${error.code}');
      throw AppException('Could not save payment promise: ${error.message}',
          code: error.code);
    }
  }

  Future<void> recordContact({
    required PaymentPromiseEntity promise,
    required String? note,
  }) async {
    try {
      await _collection.doc(promise.id).update({
        'lastContactedAt': FieldValue.serverTimestamp(),
        'followUpNote': note != null && note.trim().isNotEmpty
            ? note.trim()
            : FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      throw AppException('Could not update follow-up: ${error.message}',
          code: error.code);
    }
  }

  Future<void> recordPayment({
    required PaymentPromiseEntity promise,
    required double paymentAmount,
  }) async {
    try {
      final fulfilled = (promise.fulfilledAmount + paymentAmount)
          .clamp(0, promise.amount)
          .toDouble();
      await _collection.doc(promise.id).update({
        'fulfilledAmount': fulfilled,
        'status': fulfilled >= promise.amount
            ? PaymentPromiseStatus.paid.firestoreValue
            : PaymentPromiseStatus.partialPaid.firestoreValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      throw AppException(
          'Payment was saved, but promise status could not update: ${error.message}',
          code: error.code);
    }
  }

  Future<void> reschedule({
    required PaymentPromiseEntity promise,
    required PaymentPromiseModel replacement,
  }) async {
    try {
      final replacementRef = _collection.doc();
      final batch = _db.batch();
      batch.update(_collection.doc(promise.id), {
        'status': PaymentPromiseStatus.rescheduled.firestoreValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(
        replacementRef,
        PaymentPromiseModel.fromEntity(
          replacement.copyWith(id: replacementRef.id),
        ).toFirestore(),
      );
      await batch.commit();
    } on FirebaseException catch (error) {
      throw AppException('Could not reschedule promise: ${error.message}',
          code: error.code);
    }
  }

  Future<void> markMissed(PaymentPromiseEntity promise) async {
    try {
      await _collection.doc(promise.id).update({
        'status': PaymentPromiseStatus.missed.firestoreValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      throw AppException('Could not mark promise missed: ${error.message}',
          code: error.code);
    }
  }
}
