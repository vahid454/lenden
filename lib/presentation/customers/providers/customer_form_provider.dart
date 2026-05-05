import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/customer_providers.dart';
import '../../../domain/entities/customer_entity.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Add / Edit Customer Form State
// ─────────────────────────────────────────────────────────────────────────────

class CustomerFormState {
  final bool isLoading;
  final bool isSuccess;
  final String? errorMessage;

  const CustomerFormState({
    this.isLoading = false,
    this.isSuccess = false,
    this.errorMessage,
  });

  CustomerFormState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CustomerFormState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class CustomerFormNotifier extends StateNotifier<CustomerFormState> {
  final Ref _ref;

  CustomerFormNotifier(this._ref) : super(const CustomerFormState());

  /// Saves a new customer. Returns true on success.
  Future<bool> addCustomer({
    required String name,
    required String phone,
    String? address,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final userId = _ref.read(currentUserProvider)?.id;
    if (userId == null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'You must be signed in to add a customer.',
      );
      return false;
    }

    final currentUser = _ref.read(currentUserProvider);
    final customer = CustomerEntity(
      id: '', // Firestore will generate this
      userId: userId,
      name: name.trim(),
      phone: phone.trim(),
      address: address?.trim().isEmpty == true ? null : address?.trim(),
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      createdAt: DateTime.now(),
      // Store owner info so the other party sees who added them
      ownerName:  currentUser?.name,
      ownerPhone: currentUser?.phone,
    );

    final useCase = _ref.read(addCustomerUseCaseProvider);
    final result = await useCase(customer);

    return result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: failure.message,
        );
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, isSuccess: true);
        return true;
      },
    );
  }

  /// Updates an existing customer. Returns true on success.
  Future<bool> updateCustomer({
    required CustomerEntity existing,
    required String name,
    required String phone,
    String? address,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final updated = existing.copyWith(
      name: name.trim(),
      phone: phone.trim(),
      address: address?.trim().isEmpty == true ? null : address?.trim(),
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      updatedAt: DateTime.now(),
    );

    final useCase = _ref.read(updateCustomerUseCaseProvider);
    final result = await useCase(updated);

    return result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: failure.message,
        );
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, isSuccess: true);
        return true;
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final customerFormProvider =
    StateNotifierProvider.autoDispose<CustomerFormNotifier, CustomerFormState>(
  (ref) => CustomerFormNotifier(ref),
);
