import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;
  final Logger _log;

  AuthRepositoryImpl({required AuthRemoteDataSource remote, Logger? logger})
      : _remote = remote,
        _log    = logger ?? Logger();

  @override
  Future<Either<Failure, String>> sendOtp(String phoneNumber) async {
    try {
      return Right(await _remote.sendOtp(phoneNumber));
    } on AppException catch (e) {
      return Left(_fromException(e));
    } catch (e) {
      return Left(OtpSendFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    try {
      final fbUser = await _remote.verifyOtp(
          verificationId: verificationId, otp: otp);
      final profile = await _remote.getUserProfile(fbUser.uid);
      return Right(profile); // null = new user
    } on AppException catch (e) {
      return Left(_fromException(e));
    } catch (e) {
      return Left(OtpVerifyFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> saveUserProfile({
    required String userId,
    required String name,
    required String phone,
    String? email,
    String? businessName,
  }) async {
    try {
      final model = await _remote.saveUserProfile(
        userId: userId, name: name, phone: phone,
        email: email,
        businessName: businessName,
      );
      return Right(model);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async {
    try {
      final fb = _remote.currentFirebaseUser;
      if (fb == null) return const Right(null);
      return Right(await _remote.getUserProfile(fb.uid));
    } catch (_) {
      return const Right(null);
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await _remote.signOut();
      return const Right(null);
    } catch (_) {
      return const Left(UnknownFailure());
    }
  }

  @override
  Stream<UserEntity?> get authStateChanges {
    return _remote.firebaseAuthStateChanges.asyncMap((fbUser) async {
      if (fbUser == null) return null;
      try {
        final profile = await _remote.getUserProfile(fbUser.uid);
        if (profile != null) return profile;

        // Firebase signed in but no Firestore profile yet.
        // Return a skeleton entity with EMPTY name so the router
        // knows to send the user to profile setup.
        return UserEntity(
          id:        fbUser.uid,
          name:      '',           // ← empty name = no profile yet
          phone:     fbUser.phoneNumber ?? '',
          createdAt: DateTime.now(),
        );
      } catch (_) {
        // On any error, return skeleton so app doesn't get stuck on splash
        return UserEntity(
          id:        fbUser.uid,
          name:      '',
          phone:     fbUser.phoneNumber ?? '',
          createdAt: DateTime.now(),
        );
      }
    });
  }

  Failure _fromException(AppException e) {
    switch (e.code) {
      case 'invalid-verification-code':
      case 'invalid-verification-id': return OtpVerifyFailure(e.message);
      case 'session-expired':          return const OtpExpiredFailure();
      case 'too-many-requests':        return const TooManyRequestsFailure();
      case 'network-request-failed':   return const NetworkFailure();
      default:                         return AuthFailure(e.message);
    }
  }
}
