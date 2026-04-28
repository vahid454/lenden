import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Use Cases follow the Single Responsibility Principle.
// Each class encapsulates exactly ONE business operation.
// ─────────────────────────────────────────────────────────────────────────────

/// Sends OTP to a given phone number.
class SendOtpUseCase {
  final AuthRepository _repository;
  const SendOtpUseCase(this._repository);

  /// [phoneNumber] must be in E.164 format: "+919876543210"
  Future<Either<Failure, String>> call(String phoneNumber) {
    return _repository.sendOtp(phoneNumber);
  }
}

/// Verifies an OTP and returns the signed-in user (or null for auto-verify).
class VerifyOtpUseCase {
  final AuthRepository _repository;
  const VerifyOtpUseCase(this._repository);

  Future<Either<Failure, UserEntity?>> call({
    required String verificationId,
    required String otp,
  }) {
    return _repository.verifyOtp(
      verificationId: verificationId,
      otp: otp,
    );
  }
}

/// Saves or updates a user profile in Firestore after OTP verification.
class SaveUserProfileUseCase {
  final AuthRepository _repository;
  const SaveUserProfileUseCase(this._repository);

  Future<Either<Failure, UserEntity>> call({
    required String userId,
    required String name,
    required String phone,
    String? email,
    String? businessName,
  }) {
    return _repository.saveUserProfile(
      userId: userId,
      name: name,
      phone: phone,
      email: email,
      businessName: businessName,
    );
  }
}

/// Returns the current user's profile from Firestore (null if not found).
class GetCurrentUserUseCase {
  final AuthRepository _repository;
  const GetCurrentUserUseCase(this._repository);

  Future<Either<Failure, UserEntity?>> call() {
    return _repository.getCurrentUser();
  }
}

/// Signs the user out of Firebase.
class SignOutUseCase {
  final AuthRepository _repository;
  const SignOutUseCase(this._repository);

  Future<Either<Failure, void>> call() {
    return _repository.signOut();
  }
}
