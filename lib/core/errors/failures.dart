import 'package:equatable/equatable.dart';

/// Base failure class — all domain-level errors extend this.
abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object> get props => [message];
}

// ── Auth Failures ─────────────────────────────────────────────────────────────

class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'No internet connection. Please check your network.',
  ]);
}

class ServerFailure extends Failure {
  const ServerFailure([
    super.message = 'Server error. Please try again later.',
  ]);
}

class AuthFailure extends Failure {
  const AuthFailure([
    super.message = 'Authentication failed. Please try again.',
  ]);
}

class OtpSendFailure extends Failure {
  const OtpSendFailure([
    super.message = 'Failed to send OTP. Please check your phone number.',
  ]);
}

class OtpVerifyFailure extends Failure {
  const OtpVerifyFailure([
    super.message = 'Incorrect OTP. Please try again.',
  ]);
}

class OtpExpiredFailure extends Failure {
  const OtpExpiredFailure([
    super.message = 'OTP has expired. Please request a new one.',
  ]);
}

class TooManyRequestsFailure extends Failure {
  const TooManyRequestsFailure([
    super.message =
        'Too many attempts. Please wait a few minutes and try again.',
  ]);
}

// ── General Failures ──────────────────────────────────────────────────────────

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Item not found.']);
}

class PermissionFailure extends Failure {
  const PermissionFailure([super.message = 'Permission denied.']);
}

class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'Invalid input data.']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Local storage error.']);
}

class UnknownFailure extends Failure {
  const UnknownFailure([
    super.message = 'An unexpected error occurred. Please try again.',
  ]);
}
