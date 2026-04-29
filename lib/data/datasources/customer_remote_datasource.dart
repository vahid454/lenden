import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/exceptions.dart';
import '../models/customer_model.dart';

class CustomerRemoteDataSource {
  final FirebaseFirestore _firestore;
  final Logger _logger;

  CustomerRemoteDataSource({
    required FirebaseFirestore firestore,
    Logger? logger,
  })  : _firestore = firestore,
        _logger    = logger ?? Logger();

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.colCustomers);

  // ── Watch customers (real-time) ───────────────────────────────────────────
  // NOTE: orderBy('nameLower') requires a composite Firestore index.
  // If the index isn't deployed yet we fall back to client-side sort.
  Stream<List<CustomerModel>> watchCustomers(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .snapshots()
        .handleError((error) {
          _logger.e('watchCustomers error: $error');
          // Return empty snapshot on error rather than crashing
        })
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => CustomerModel.fromFirestore(doc))
              .toList();
          // Client-side sort — works even without Firestore index
          list.sort((a, b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          return list;
        });
  }

  Stream<List<CustomerModel>> watchCustomersByPhone(String phone) {
    return _col
        .where('phone', isEqualTo: phone)
        .snapshots()
        .handleError((error) {
          _logger.e('watchCustomersByPhone error: $error');
        })
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => CustomerModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          return list;
        });
  }

  // ── Add ───────────────────────────────────────────────────────────────────
  Future<CustomerModel> addCustomer(CustomerModel customer) async {
    try {
      final docRef = await _col.add(customer.toFirestore());
      final doc    = await docRef.get();
      _logger.i('Customer added: ${docRef.id}');
      return CustomerModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      _logger.e('addCustomer: ${e.code}');
      throw AppException('Failed to add customer: ${e.message}', code: e.code);
    }
  }

  // ── Update ────────────────────────────────────────────────────────────────
  Future<CustomerModel> updateCustomer(CustomerModel customer) async {
    try {
      await _col.doc(customer.id).update(customer.toFirestore());
      final doc = await _col.doc(customer.id).get();
      _logger.i('Customer updated: ${customer.id}');
      return CustomerModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      _logger.e('updateCustomer: ${e.code}');
      throw AppException('Failed to update customer: ${e.message}', code: e.code);
    }
  }

  // ── Delete (with cascade) ─────────────────────────────────────────────────
  Future<void> deleteCustomer(String customerId) async {
    try {
      final batch  = _firestore.batch();
      batch.delete(_col.doc(customerId));

      final txSnap = await _firestore
          .collection(AppConstants.colTransactions)
          .where('customerId', isEqualTo: customerId)
          .get();
      for (final doc in txSnap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      _logger.i('Customer $customerId deleted with ${txSnap.docs.length} transactions');
    } on FirebaseException catch (e) {
      _logger.e('deleteCustomer: ${e.code}');
      throw AppException('Failed to delete customer: ${e.message}', code: e.code);
    }
  }

  // ── Get single ────────────────────────────────────────────────────────────
  Future<CustomerModel> getCustomer(String customerId) async {
    try {
      final doc = await _col.doc(customerId).get();
      if (!doc.exists || doc.data() == null) {
        throw const AppException('Customer not found', code: 'not-found');
      }
      return CustomerModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      _logger.e('getCustomer: ${e.code}');
      throw AppException('Failed to load customer: ${e.message}', code: e.code);
    }
  }

  // ── Search (client-side fallback if index missing) ────────────────────────
  Future<List<CustomerModel>> searchCustomers({
    required String userId,
    required String query,
  }) async {
    try {
      final lower = query.toLowerCase().trim();
      // Try Firestore prefix query first
      final snapshot = await _col
          .where('userId', isEqualTo: userId)
          .where('nameLower', isGreaterThanOrEqualTo: lower)
          .where('nameLower', isLessThanOrEqualTo: '$lower\uf8ff')
          .limit(20)
          .get();
      return snapshot.docs
          .map((doc) => CustomerModel.fromFirestore(doc))
          .toList();
    } on FirebaseException catch (e) {
      _logger.w('searchCustomers Firestore query failed (${e.code}), falling back');
      // Fallback: fetch all and filter client-side
      try {
        final all = await _col.where('userId', isEqualTo: userId).get();
        return all.docs
            .map((doc) => CustomerModel.fromFirestore(doc))
            .where((c) => c.name.toLowerCase().contains(query.toLowerCase()))
            .take(20)
            .toList();
      } catch (_) {
        return [];
      }
    }
  }
}
