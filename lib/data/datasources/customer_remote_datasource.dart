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
        _logger = logger ?? Logger();

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.colCustomers);
  CollectionReference<Map<String, dynamic>> get _phoneKeys =>
      _firestore.collection(AppConstants.colCustomerPhoneKeys);

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
    }).map((snapshot) {
      final list =
          snapshot.docs.map((doc) => CustomerModel.fromFirestore(doc)).toList();
      // Client-side sort — works even without Firestore index
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  Stream<List<CustomerModel>> watchCustomersByPhone(String phone) {
    return _col
        .where('phone', isEqualTo: phone)
        .snapshots()
        .handleError((error) {
      _logger.e('watchCustomersByPhone error: $error');
    }).map((snapshot) {
      final list =
          snapshot.docs.map((doc) => CustomerModel.fromFirestore(doc)).toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  /// Creates missing uniqueness records for customers saved before phone keys
  /// were introduced. Existing reservations are never overwritten.
  Future<void> ensurePhoneReservations(String userId) async {
    try {
      final results = await Future.wait([
        _col.where('userId', isEqualTo: userId).get(),
        _phoneKeys.where('userId', isEqualTo: userId).get(),
      ]);
      final customers = results[0];
      final reservedKeys = results[1].docs.map((doc) => doc.id).toSet();

      WriteBatch batch = _firestore.batch();
      var pendingWrites = 0;
      for (final customer in customers.docs) {
        final phone =
            _normalizePhone(customer.data()['phone'] as String? ?? '');
        if (phone.length != 10) continue;

        final key = _phoneKey(userId, phone);
        if (!reservedKeys.add(key)) continue;

        batch.set(_phoneKeys.doc(key), {
          'userId': userId,
          'phone': phone,
          'customerId': customer.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
        pendingWrites++;

        if (pendingWrites == 400) {
          await batch.commit();
          batch = _firestore.batch();
          pendingWrites = 0;
        }
      }

      if (pendingWrites > 0) await batch.commit();
    } on FirebaseException catch (e) {
      // Migration failure must not prevent access to the customer's ledger.
      _logger.w('ensurePhoneReservations: ${e.code}');
    }
  }

  // ── Add ───────────────────────────────────────────────────────────────────
  Future<CustomerModel> addCustomer(CustomerModel customer) async {
    try {
      final normalizedPhone = _normalizePhone(customer.phone);
      final duplicate = await _col
          .where('userId', isEqualTo: customer.userId)
          .where('phone', isEqualTo: normalizedPhone)
          .limit(1)
          .get();
      if (duplicate.docs.isNotEmpty) {
        throw const AppException(
          'A customer with this mobile number already exists.',
          code: 'customer-already-exists',
        );
      }

      // The ID is the server-enforced uniqueness key for this owner and phone.
      final docRef = _col.doc(_phoneKey(customer.userId, normalizedPhone));
      final customerData =
          customer.copyWith(phone: normalizedPhone).toFirestore();
      try {
        await docRef.set(customerData);
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied' && (await docRef.get()).exists) {
          throw const AppException(
            'A customer with this mobile number already exists.',
            code: 'customer-already-exists',
          );
        }
        rethrow;
      }
      final doc = await docRef.get();
      _logger.i('Customer added: ${docRef.id}');
      return CustomerModel.fromFirestore(doc);
    } on AppException {
      rethrow;
    } on FirebaseException catch (e) {
      _logger.e('addCustomer: ${e.code}');
      final message = e.code == 'permission-denied'
          ? 'Customer could not be saved. Please sign out, sign in again, and retry.'
          : 'Failed to add customer: ${e.message}';
      throw AppException(message, code: e.code);
    }
  }

  // ── Update ────────────────────────────────────────────────────────────────
  Future<CustomerModel> updateCustomer(CustomerModel customer) async {
    try {
      final normalizedPhone = _normalizePhone(customer.phone);
      final duplicates = await _col
          .where('userId', isEqualTo: customer.userId)
          .where('phone', isEqualTo: normalizedPhone)
          .limit(2)
          .get();
      if (duplicates.docs.any((doc) => doc.id != customer.id)) {
        throw const AppException(
          'A customer with this mobile number already exists.',
          code: 'customer-already-exists',
        );
      }

      final data = customer.copyWith(phone: normalizedPhone).toFirestore();
      if (customer.secondaryPhone == null || customer.secondaryPhone!.isEmpty) {
        data['secondaryPhone'] = FieldValue.delete();
      }
      if (customer.address == null || customer.address!.isEmpty) {
        data['address'] = FieldValue.delete();
      }
      if (customer.notes == null || customer.notes!.isEmpty) {
        data['notes'] = FieldValue.delete();
      }
      if (customer.photoPath == null || customer.photoPath!.isEmpty) {
        data['photoPath'] = FieldValue.delete();
      }
      final customerRef = _col.doc(customer.id);
      final phoneKeyRef = _phoneKeys.doc(
        _phoneKey(customer.userId, normalizedPhone),
      );
      final currentCustomer = await customerRef.get();
      if (!currentCustomer.exists) {
        throw const AppException('Customer not found.', code: 'not-found');
      }
      final currentPhone =
          _normalizePhone(currentCustomer.data()?['phone'] as String? ?? '');
      if (currentPhone == normalizedPhone) {
        await customerRef.update(data);
      } else {
        final batch = _firestore.batch();
        batch.set(phoneKeyRef, {
          'userId': customer.userId,
          'phone': normalizedPhone,
          'customerId': customer.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
        batch.update(customerRef, data);
        try {
          await batch.commit();
        } on FirebaseException catch (e) {
          if (e.code == 'permission-denied' &&
              (await phoneKeyRef.get()).exists) {
            throw const AppException(
              'A customer with this mobile number already exists.',
              code: 'customer-already-exists',
            );
          }
          rethrow;
        }
      }
      final doc = await _col.doc(customer.id).get();
      _logger.i('Customer updated: ${customer.id}');
      return CustomerModel.fromFirestore(doc);
    } on AppException {
      rethrow;
    } on FirebaseException catch (e) {
      _logger.e('updateCustomer: ${e.code}');
      throw AppException('Failed to update customer: ${e.message}',
          code: e.code);
    }
  }

  String _normalizePhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length <= 10 ? digits : digits.substring(digits.length - 10);
  }

  String _phoneKey(String userId, String phone) => '${userId}_$phone';

  // ── Delete (with cascade) ─────────────────────────────────────────────────
  Future<void> deleteCustomer(String customerId) async {
    try {
      final batch = _firestore.batch();
      batch.delete(_col.doc(customerId));

      final txSnap = await _firestore
          .collection(AppConstants.colTransactions)
          .where('customerId', isEqualTo: customerId)
          .get();
      for (final doc in txSnap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      _logger.i(
          'Customer $customerId deleted with ${txSnap.docs.length} transactions');
    } on FirebaseException catch (e) {
      _logger.e('deleteCustomer: ${e.code}');
      throw AppException('Failed to delete customer: ${e.message}',
          code: e.code);
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
      _logger.w(
          'searchCustomers Firestore query failed (${e.code}), falling back');
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
