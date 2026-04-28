import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/exceptions.dart';
import '../models/user_model.dart';

class AuthRemoteDataSource {
  final FirebaseAuth      _auth;
  final FirebaseFirestore _firestore;
  final Logger            _logger;

  AuthRemoteDataSource({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    Logger? logger,
  })  : _auth      = auth,
        _firestore = firestore,
        _logger    = logger ?? Logger();

  // ── Send OTP ──────────────────────────────────────────────────────────────

  Future<String> sendOtp(String phoneNumber) async {
    final completer = Completer<String>();
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: AppConstants.otpTimeout,
        verificationCompleted: (PhoneAuthCredential credential) async {
          _logger.i('Auto-verification triggered');
        },
        verificationFailed: (FirebaseAuthException e) {
          _logger.e('OTP send failed: ${e.code}');
          if (!completer.isCompleted) {
            completer.completeError(
              AppException(_mapAuthError(e.code, e.message), code: e.code));
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          _logger.i('OTP sent to $phoneNumber');
          if (!completer.isCompleted) completer.complete(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (!completer.isCompleted) completer.complete(verificationId);
        },
      );
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError(AppException('Failed to send OTP: $e'));
      }
    }
    return completer.future;
  }

  // ── Verify OTP ────────────────────────────────────────────────────────────

  Future<User> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
          verificationId: verificationId, smsCode: otp);
      final result = await _auth.signInWithCredential(credential);
      if (result.user == null) {
        throw const AppException('Sign-in returned null user');
      }
      _logger.i('OTP verified: ${result.user!.uid}');
      return result.user!;
    } on FirebaseAuthException catch (e) {
      throw AppException(_mapAuthError(e.code, e.message), code: e.code);
    }
  }

  // ── Save user profile — with retry on permission-denied ───────────────────

  Future<UserModel> saveUserProfile({
    required String userId,
    required String name,
    required String phone,
    String? email,
    String? businessName,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw const AppException(
          'Not authenticated. Please restart and try again.',
          code: 'not-authenticated');
    }

    final model = UserModel(
      id:           userId,
      name:         name.trim(),
      phone:        phone,
      email:        (email?.trim().isEmpty ?? true) ? null : email!.trim(),
      businessName: (businessName?.trim().isEmpty ?? true)
                    ? null
                    : businessName!.trim(),
      createdAt:    DateTime.now(),
    );

    Exception? lastError;
    for (int attempt = 1; attempt <= 4; attempt++) {
      try {
        // Always force-refresh token — critical on first sign-in
        await currentUser.getIdToken(true);

        if (attempt > 1) {
          // Progressive delay: 1s, 2s, 3s
          await Future.delayed(Duration(seconds: attempt - 1));
          _logger.i('saveUserProfile retry attempt $attempt');
        }

        await _firestore
            .collection(AppConstants.colUsers)
            .doc(userId)
            .set(model.toFirestore(), SetOptions(merge: true));

        _logger.i('Profile saved successfully on attempt $attempt');
        return model;

      } on FirebaseException catch (e) {
        _logger.w('saveUserProfile attempt $attempt: ${e.code} — ${e.message}');
        lastError = AppException(_mapFirestoreError(e.code, e.message), code: e.code);

        // Only retry on permission-denied (token timing issue)
        // Other errors (network, invalid data) fail fast
        if (e.code != 'permission-denied') break;
      }
    }

    throw lastError ?? const AppException('Failed to save profile');
  }

  // ── Get user profile ──────────────────────────────────────────────────────

  Future<UserModel?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.colUsers)
          .doc(userId)
          .get();
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromFirestore(doc);
    } catch (e) {
      _logger.w('getUserProfile failed (returning null): $e');
      return null; // graceful — don't crash app on read fail
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _logger.i('Signed out');
  }

  Stream<User?> get firebaseAuthStateChanges => _auth.authStateChanges();
  User? get currentFirebaseUser => _auth.currentUser;

  // ── Error mapping ─────────────────────────────────────────────────────────

  String _mapAuthError(String? code, String? message) {
    switch (code) {
      case 'invalid-phone-number':   return 'Invalid phone number.';
      case 'too-many-requests':      return 'Too many attempts. Please wait a few minutes.';
      case 'invalid-verification-code': return 'Incorrect OTP. Please try again.';
      case 'invalid-verification-id':   return 'OTP expired. Please request a new one.';
      case 'session-expired':        return 'OTP expired. Please request a new one.';
      case 'quota-exceeded':         return 'SMS quota exceeded. Try again tomorrow.';
      case 'network-request-failed': return 'No internet. Please check your connection.';
      case 'app-not-authorized':     return 'App not authorised. Add SHA-1 to Firebase.';
      default: return message ?? 'Authentication failed. Please try again.';
    }
  }

  String _mapFirestoreError(String? code, String? message) {
    switch (code) {
      case 'permission-denied': return 'Permission denied. Retrying…';
      case 'unavailable':       return 'Server unavailable. Check your internet.';
      default: return message ?? 'Failed to save. Please try again.';
    }
  }
}
