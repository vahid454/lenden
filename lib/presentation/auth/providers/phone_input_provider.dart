import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_providers.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class PhoneInputState {
  final bool isLoading;
  final String? errorMessage;

  const PhoneInputState({
    this.isLoading = false,
    this.errorMessage,
  });

  PhoneInputState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PhoneInputState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class PhoneInputNotifier extends StateNotifier<PhoneInputState> {
  final Ref _ref;

  PhoneInputNotifier(this._ref) : super(const PhoneInputState());

  /// Sends OTP to [phoneNumber] (E.164 format).
  /// Returns the verificationId on success, null on failure.
  Future<String?> sendOtp(String phoneNumber) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final useCase = _ref.read(sendOtpUseCaseProvider);
    final result = await useCase(phoneNumber);

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return null;
      },
      (verificationId) {
        state = state.copyWith(isLoading: false);
        return verificationId;
      },
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final phoneInputProvider =
    StateNotifierProvider.autoDispose<PhoneInputNotifier, PhoneInputState>(
  (ref) => PhoneInputNotifier(ref),
);
