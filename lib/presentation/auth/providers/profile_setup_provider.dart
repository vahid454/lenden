import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_providers.dart';

class ProfileSetupState {
  final bool isLoading;
  final String? errorMessage;
  const ProfileSetupState({this.isLoading = false, this.errorMessage});

  ProfileSetupState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) => ProfileSetupState(
    isLoading:    isLoading    ?? this.isLoading,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );
}

class ProfileSetupNotifier extends StateNotifier<ProfileSetupState> {
  final Ref _ref;
  ProfileSetupNotifier(this._ref) : super(const ProfileSetupState());

  Future<bool> saveProfile({
    required String userId,
    required String name,
    required String phone,
    String? email,
    String? businessName,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final useCase = _ref.read(saveUserProfileUseCaseProvider);
    final result  = await useCase(
      userId:       userId,
      name:         name,
      phone:        phone,
      email:        email,
      businessName: businessName,
    );

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false);
        return true;
      },
    );
  }
}

final profileSetupProvider =
    StateNotifierProvider.autoDispose<ProfileSetupNotifier, ProfileSetupState>(
  (ref) => ProfileSetupNotifier(ref),
);
