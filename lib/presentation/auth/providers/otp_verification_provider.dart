import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../domain/entities/user_entity.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class OtpVerificationState {
  final bool    isLoading;
  final String? errorMessage;
  final String  verificationId;

  const OtpVerificationState({
    required this.verificationId,
    this.isLoading    = false,
    this.errorMessage,
  });

  OtpVerificationState copyWith({
    bool?   isLoading,
    String? errorMessage,
    bool    clearError      = false,
    String? verificationId,
  }) => OtpVerificationState(
    verificationId: verificationId ?? this.verificationId,
    isLoading:      isLoading      ?? this.isLoading,
    errorMessage:   clearError ? null : errorMessage ?? this.errorMessage,
  );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class OtpVerificationNotifier
    extends StateNotifier<OtpVerificationState> {
  final Ref _ref;

  OtpVerificationNotifier(this._ref, String verificationId)
      : super(OtpVerificationState(verificationId: verificationId));

  /// Returns [UserEntity] for existing users, null for new users.
  Future<UserEntity?> verifyOtp({required String otp}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final useCase = _ref.read(verifyOtpUseCaseProvider);
    final result  = await useCase(
      verificationId: state.verificationId,
      otp: otp,
    );

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return null;
      },
      (user) {
        state = state.copyWith(isLoading: false);
        return user;
      },
    );
  }

  /// Resends OTP and updates verificationId. Returns new verificationId.
  Future<String?> resendOtp(String phoneNumber) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final useCase = _ref.read(sendOtpUseCaseProvider);
    final result  = await useCase(phoneNumber);

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return null;
      },
      (newVerificationId) {
        state = state.copyWith(
          isLoading:      false,
          verificationId: newVerificationId,
        );
        return newVerificationId;
      },
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Scoped per verificationId — each OTP flow has its own instance.
final otpVerificationProvider = StateNotifierProvider.autoDispose
    .family<OtpVerificationNotifier, OtpVerificationState, String>(
  (ref, verificationId) => OtpVerificationNotifier(ref, verificationId),
);

/// Convenience: current Firebase UID (available after OTP sign-in).
final currentFirebaseUidProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.id;
});
