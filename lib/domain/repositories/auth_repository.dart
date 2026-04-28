import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/user_entity.dart';

/// Abstract contract for authentication operations.
/// The data layer must implement this; domain/presentation never import Firebase.
abstract class AuthRepository {
  /// Sends an OTP to [phoneNumber] (e.g. "+919876543210").
  /// Returns the [verificationId] string on success.
  Future<Either<Failure, String>> sendOtp(String phoneNumber);

  /// Verifies [otp] using the [verificationId] received from [sendOtp].
  /// Returns the authenticated [UserEntity] (may be null on auto-verify edge cases).
  Future<Either<Failure, UserEntity?>> verifyOtp({
    required String verificationId,
    required String otp,
  });

  /// Creates or updates the user profile in Firestore after first login.
  Future<Either<Failure, UserEntity>> saveUserProfile({
    required String userId,
    required String name,
    required String phone,
    String? businessName,
  });

  /// Fetches the currently logged-in user's profile from Firestore.
  Future<Either<Failure, UserEntity?>> getCurrentUser();

  /// Signs out of Firebase.
  Future<Either<Failure, void>> signOut();

  /// Real-time auth state — emits [UserEntity] when signed in, null when signed out.
  Stream<UserEntity?> get authStateChanges;
}
