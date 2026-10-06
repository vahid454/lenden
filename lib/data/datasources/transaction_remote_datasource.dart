import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../domain/entities/payment_promise_entity.dart';
import '../../domain/entities/transaction_entity.dart';
import '../models/customer_model.dart';
import '../models/payment_promise_model.dart';
import '../models/transaction_model.dart';

class TransactionRemoteDataSource {
  final FirebaseFirestore _db;
  final Logger _log;

  TransactionRemoteDataSource({
    required FirebaseFirestore firestore,
    Logger? logger,
  })  : _db = firestore,
        _log = logger ?? Logger();

  CollectionReference<Map<String, dynamic>> get _txCol =>
      _db.collection(AppConstants.colTransactions);
  CollectionReference<Map<String, dynamic>> get _custCol =>
      _db.collection(AppConstants.colCustomers);
  CollectionReference<Map<String, dynamic>> get _promiseCol =>
      _db.collection(AppConstants.colPaymentPromises);
  CollectionReference<Map<String, dynamic>> get _sharedLedgerCol =>
      _db.collection(AppConstants.colSharedLedgers);

  // ── Watch ─────────────────────────────────────────────────────────────────
  Stream<List<TransactionModel>> watchTransactions({
    required String customerId,
    required String userId,
  }) {
    return _txCol
        .where('customerId', isEqualTo: customerId)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .handleError((e) => _log.e('watchTransactions error: $e'))
        .map((snap) {
      final list =
          snap.docs.map((d) => TransactionModel.fromFirestore(d)).toList();
      // Client-side sort newest-first — no composite index needed
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  // ── Add (atomic) ──────────────────────────────────────────────────────────
  Future<TransactionModel> addTransaction(
    TransactionModel tx, {
    String? promiseIdToFulfill,
  }) async {
    try {
      late String newId;
      late CustomerModel updatedCustomer;
      final promiseRef = await _resolvePromiseForPayment(
        tx,
        preferredPromiseId: promiseIdToFulfill,
      );

      // The money entry and balance are the authoritative ledger state. Keep
      // them atomic, while allowing derived promise/share updates to recover
      // independently instead of blocking a valid payment.
      await _db.runTransaction((ftx) async {
        final txRef = _txCol.doc();
        final custRef = _custCol.doc(tx.customerId);
        newId = txRef.id;
        final customerSnapshot = await ftx.get(custRef);
        if (!customerSnapshot.exists) {
          throw const AppException(
            'This customer no longer exists. Refresh the ledger and retry.',
            code: 'customer-not-found',
          );
        }
        final customer = CustomerModel.fromFirestore(customerSnapshot);
        if (customer.userId != tx.userId) {
          throw const AppException(
            'This customer belongs to a different account.',
            code: 'customer-owner-mismatch',
          );
        }
        updatedCustomer =
            customer.copyWith(balance: customer.balance + tx.balanceDelta);
        ftx.set(txRef, tx.toFirestore());
        ftx.update(custRef, {
          'balance': FieldValue.increment(tx.balanceDelta),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      await _syncSharedLedger(updatedCustomer);
      if (promiseRef != null) {
        await _fulfillPromiseAfterPayment(promiseRef, tx);
      }
      _log.i('Transaction added: $newId');
      return tx.copyWith(id: newId);
    } on AppException {
      rethrow;
    } on FirebaseException catch (e) {
      _log.e('addTransaction: ${e.code}');
      throw AppException('Failed to add entry: ${e.message}', code: e.code);
    } catch (error, stackTrace) {
      _log.e(
        'addTransaction unexpected',
        error: error,
        stackTrace: stackTrace,
      );
      throw const AppException(
        'This customer ledger needs repair before an entry can be saved.',
        code: 'customer-ledger-invalid',
      );
    }
  }

  Future<DocumentReference<Map<String, dynamic>>?> _resolvePromiseForPayment(
    TransactionModel tx, {
    String? preferredPromiseId,
  }) async {
    if (!tx.isGot) return null;

    try {
      final snapshot = await _promiseCol
          .where('userId', isEqualTo: tx.userId)
          .where('customerId', isEqualTo: tx.customerId)
          .get();
      final promises = <PaymentPromiseModel>[];
      for (final document in snapshot.docs) {
        try {
          promises.add(PaymentPromiseModel.fromFirestore(document));
        } catch (error, stackTrace) {
          _log.w(
            'Skipping malformed promise ${document.id}',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
      final selected = selectPromiseForPayment(
        promises: promises,
        customerId: tx.customerId,
        paymentDate: tx.date,
        preferredPromiseId: preferredPromiseId,
      );
      return selected == null ? null : _promiseCol.doc(selected.id);
    } on FirebaseException catch (error) {
      _log.w('Promise lookup skipped: ${error.code}');
      return null;
    } catch (error, stackTrace) {
      _log.w(
        'Promise lookup skipped',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> _syncSharedLedger(CustomerModel customer) async {
    final reference = _sharedLedgerCol.doc(customer.id);
    try {
      final existing = await reference.get();
      final data = customer.toSharedLedgerFirestore();
      if (existing.exists) {
        // Preserve the projection's immutable creation timestamp. This also
        // repairs older shared records without rejecting the money entry.
        data.remove('createdAt');
        await reference.set(data, SetOptions(merge: true));
      } else {
        await reference.set(data);
      }
    } catch (error, stackTrace) {
      _log.w(
        'Shared ledger sync deferred for ${customer.id}',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _fulfillPromiseAfterPayment(
    DocumentReference<Map<String, dynamic>> promiseRef,
    TransactionModel tx,
  ) async {
    try {
      await _db.runTransaction((ftx) async {
        final snapshot = await ftx.get(promiseRef);
        if (!_canFulfillPromise(snapshot, tx)) return;
        final data = snapshot.data()!;
        final promisedAmount = (data['amount'] as num).toDouble();
        final previouslyFulfilled =
            (data['fulfilledAmount'] as num?)?.toDouble() ?? 0;
        ftx.update(promiseRef, {
          'fulfilledAmount':
              (previouslyFulfilled + tx.amount).clamp(0, promisedAmount),
          'status': PaymentPromiseStatus.paid.firestoreValue,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (error, stackTrace) {
      _log.w(
        'Promise fulfillment deferred for ${promiseRef.id}',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  bool _canFulfillPromise(
    DocumentSnapshot<Map<String, dynamic>>? snapshot,
    TransactionModel tx,
  ) {
    if (snapshot == null || !snapshot.exists || !tx.isGot) return false;
    final data = snapshot.data();
    if (data == null ||
        data['userId'] != tx.userId ||
        data['customerId'] != tx.customerId ||
        data['status'] != PaymentPromiseStatus.pending.firestoreValue ||
        data['amount'] is! num ||
        data['createdAt'] is! Timestamp ||
        data['promisedDate'] is! Timestamp) {
      return false;
    }
    final promiseCreatedAt = (data['createdAt'] as Timestamp).toDate();
    final promisedDate = (data['promisedDate'] as Timestamp).toDate();
    final paymentDay = DateTime(tx.date.year, tx.date.month, tx.date.day);
    final promiseCreatedDay = DateTime(
      promiseCreatedAt.year,
      promiseCreatedAt.month,
      promiseCreatedAt.day,
    );
    final promisedDay =
        DateTime(promisedDate.year, promisedDate.month, promisedDate.day);
    return !paymentDay.isBefore(promiseCreatedDay) &&
        !paymentDay.isAfter(promisedDay);
  }

  // ── Update (atomic) ───────────────────────────────────────────────────────
  Future<TransactionModel> updateTransaction({
    required TransactionModel oldTx,
    required TransactionModel newTx,
  }) async {
    try {
      late CustomerModel updatedCustomer;
      await _db.runTransaction((ftx) async {
        final txRef = _txCol.doc(oldTx.id);
        final custRef = _custCol.doc(oldTx.customerId);
        final customerSnapshot = await ftx.get(custRef);
        if (!customerSnapshot.exists) {
          throw const AppException(
            'This customer no longer exists. Refresh the ledger and retry.',
            code: 'customer-not-found',
          );
        }
        final customer = CustomerModel.fromFirestore(customerSnapshot);
        if (customer.userId != newTx.userId) {
          throw const AppException(
            'This customer belongs to a different account.',
            code: 'customer-owner-mismatch',
          );
        }
        final netDelta = newTx.balanceDelta - oldTx.balanceDelta;
        updatedCustomer =
            customer.copyWith(balance: customer.balance + netDelta);
        ftx.update(txRef, newTx.copyWith(id: oldTx.id).toFirestore());
        ftx.update(custRef, {
          'balance': FieldValue.increment(netDelta),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      await _syncSharedLedger(updatedCustomer);
      _log.i('Transaction updated: ${oldTx.id}');
      return newTx.copyWith(id: oldTx.id);
    } on AppException {
      rethrow;
    } on FirebaseException catch (e) {
      _log.e('updateTransaction: ${e.code}');
      throw AppException('Failed to update entry: ${e.message}', code: e.code);
    } catch (error, stackTrace) {
      _log.e(
        'updateTransaction unexpected',
        error: error,
        stackTrace: stackTrace,
      );
      throw const AppException(
        'This customer ledger needs repair before the entry can be updated.',
        code: 'customer-ledger-invalid',
      );
    }
  }

  // ── Delete (atomic) ───────────────────────────────────────────────────────
  Future<void> deleteTransaction(TransactionEntity tx) async {
    try {
      await _db.runTransaction((ftx) async {
        final txRef = _txCol.doc(tx.id);
        final custRef = _custCol.doc(tx.customerId);
        final sharedLedgerRef = _sharedLedgerCol.doc(tx.customerId);
        final customerSnapshot = await ftx.get(custRef);
        final customer = CustomerModel.fromFirestore(customerSnapshot);
        ftx.delete(txRef);
        ftx.update(custRef, {
          'balance': FieldValue.increment(-tx.balanceDelta),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        ftx.set(
          sharedLedgerRef,
          customer
              .copyWith(balance: customer.balance - tx.balanceDelta)
              .toSharedLedgerFirestore(),
        );
      });
      _log.i('Transaction deleted: ${tx.id}');
    } on FirebaseException catch (e) {
      _log.e('deleteTransaction: ${e.code}');
      throw AppException('Failed to delete entry: ${e.message}', code: e.code);
    }
  }

  // ── Date range (for reports) ──────────────────────────────────────────────
  Future<List<TransactionModel>> getTransactionsByDateRange({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final snap = await _txCol
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(to))
          .get();
      final list =
          snap.docs.map((d) => TransactionModel.fromFirestore(d)).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    } on FirebaseException catch (e) {
      _log.e('getByDateRange: ${e.code}');
      // If index missing, fetch all user transactions and filter client-side
      if (e.code == 'failed-precondition') {
        _log.w('Index missing — falling back to client-side date filter');
        try {
          final all = await _txCol.where('userId', isEqualTo: userId).get();
          final list = all.docs
              .map((d) => TransactionModel.fromFirestore(d))
              .where((t) => !t.date.isBefore(from) && !t.date.isAfter(to))
              .toList();
          list.sort((a, b) => b.date.compareTo(a.date));
          return list;
        } catch (_) {
          return [];
        }
      }
      throw AppException('Failed to load report: ${e.message}', code: e.code);
    }
  }

  // ── Count ─────────────────────────────────────────────────────────────────
  Future<int> getTransactionCount({
    required String customerId,
    required String userId,
  }) async {
    try {
      final snap = await _txCol
          .where('customerId', isEqualTo: customerId)
          .where('userId', isEqualTo: userId)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
