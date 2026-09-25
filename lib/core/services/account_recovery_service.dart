import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../constants/app_constants.dart';
import '../errors/exceptions.dart';

class AccountRecoveryService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AccountRecoveryService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  bool get isRecoveryConfigured =>
      _auth.currentUser?.providerData
          .any((provider) => provider.providerId == 'password') ==
      true;

  Future<void> saveContactEmail(String email) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AppException('Please sign in again.', code: 'signed-out');
    }
    final normalized = email.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalized)) {
      throw const AppException('Enter a valid email address.',
          code: 'invalid-email');
    }
    await _firestore
        .collection(AppConstants.colUsers)
        .doc(user.uid)
        .set({'email': normalized}, SetOptions(merge: true));
  }

  Future<void> configure({
    required String email,
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AppException('Please sign in again.', code: 'signed-out');
    }
    if (isRecoveryConfigured) {
      throw const AppException(
        'Recovery email is already configured for this account.',
        code: 'already-configured',
      );
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final result = await user.linkWithCredential(credential);
      await result.user?.sendEmailVerification();
      await _firestore
          .collection(AppConstants.colUsers)
          .doc(user.uid)
          .set({'email': email.trim().toLowerCase()}, SetOptions(merge: true));
    } on FirebaseAuthException catch (error) {
      throw AppException(_message(error), code: error.code);
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      await result.user?.reload();
      if (_auth.currentUser?.emailVerified != true) {
        await _auth.signOut();
        throw const AppException(
          'Verify your recovery email before using it to sign in.',
          code: 'email-not-verified',
        );
      }
    } on AppException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw AppException(_message(error), code: error.code);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
    } on FirebaseAuthException catch (error) {
      throw AppException(_message(error), code: error.code);
    }
  }

  String _message(FirebaseAuthException error) => switch (error.code) {
        'operation-not-allowed' =>
          'Enable Email/Password sign-in in Firebase Authentication first.',
        'email-already-in-use' =>
          'This email is already linked to another account.',
        'invalid-email' => 'Enter a valid email address.',
        'weak-password' =>
          'Use at least 8 characters for the recovery password.',
        'wrong-password' ||
        'invalid-credential' =>
          'Incorrect recovery email or password.',
        'too-many-requests' => 'Too many attempts. Please try again later.',
        'network-request-failed' => 'No internet connection.',
        _ => error.message ?? 'Recovery action failed. Please try again.',
      };
}
