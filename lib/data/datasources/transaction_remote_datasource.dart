import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../domain/entities/transaction_entity.dart';
import '../models/transaction_model.dart';

class TransactionRemoteDataSource {
  final FirebaseFirestore _db;
  final Logger _log;

  TransactionRemoteDataSource({
    required FirebaseFirestore firestore,
    Logger? logger,
  })  : _db  = firestore,
        _log = logger ?? Logger();

  CollectionReference<Map<String, dynamic>> get _txCol =>
      _db.collection(AppConstants.colTransactions);
  CollectionReference<Map<String, dynamic>> get _custCol =>
      _db.collection(AppConstants.colCustomers);

  // ── Watch ─────────────────────────────────────────────────────────────────
  Stream<List<TransactionModel>> watchTransactions(String customerId) {
    return _txCol
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .handleError((e) => _log.e('watchTransactions error: $e'))
        .map((snap) {
          final list = snap.docs
              .map((d) => TransactionModel.fromFirestore(d))
              .toList();
          // Client-side sort newest-first — no composite index needed
          list.sort((a, b) => b.date.compareTo(a.date));
          return list;
        });
  }

  // ── Add (atomic) ──────────────────────────────────────────────────────────
  Future<TransactionModel> addTransaction(TransactionModel tx) async {
    try {
      late String newId;
      await _db.runTransaction((ftx) async {
        final txRef   = _txCol.doc();
        final custRef = _custCol.doc(tx.customerId);
        newId = txRef.id;
        await ftx.get(custRef);
        ftx.set(txRef, tx.toFirestore());
        ftx.update(custRef, {
          'balance':   FieldValue.increment(tx.balanceDelta),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      _log.i('Transaction added: $newId');
      return tx.copyWith(id: newId) as TransactionModel;
    } on FirebaseException catch (e) {
      _log.e('addTransaction: ${e.code}');
      throw AppException('Failed to add entry: ${e.message}', code: e.code);
    }
  }

  // ── Update (atomic) ───────────────────────────────────────────────────────
  Future<TransactionModel> updateTransaction({
    required TransactionModel oldTx,
    required TransactionModel newTx,
  }) async {
    try {
      await _db.runTransaction((ftx) async {
        final txRef   = _txCol.doc(oldTx.id);
        final custRef = _custCol.doc(oldTx.customerId);
        await ftx.get(custRef);
        final netDelta = newTx.balanceDelta - oldTx.balanceDelta;
        ftx.update(txRef, newTx.copyWith(id: oldTx.id).toFirestore());
        ftx.update(custRef, {
          'balance':   FieldValue.increment(netDelta),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      _log.i('Transaction updated: ${oldTx.id}');
      return newTx.copyWith(id: oldTx.id) as TransactionModel;
    } on FirebaseException catch (e) {
      _log.e('updateTransaction: ${e.code}');
      throw AppException('Failed to update entry: ${e.message}', code: e.code);
    }
  }

  // ── Delete (atomic) ───────────────────────────────────────────────────────
  Future<void> deleteTransaction(TransactionEntity tx) async {
    try {
      await _db.runTransaction((ftx) async {
        final txRef   = _txCol.doc(tx.id);
        final custRef = _custCol.doc(tx.customerId);
        await ftx.get(custRef);
        ftx.delete(txRef);
        ftx.update(custRef, {
          'balance':   FieldValue.increment(-tx.balanceDelta),
          'updatedAt': FieldValue.serverTimestamp(),
        });
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
      final list = snap.docs
          .map((d) => TransactionModel.fromFirestore(d))
          .toList();
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
              .where((t) =>
                  !t.date.isBefore(from) && !t.date.isAfter(to))
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
  Future<int> getTransactionCount(String customerId) async {
    try {
      final snap = await _txCol
          .where('customerId', isEqualTo: customerId)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
