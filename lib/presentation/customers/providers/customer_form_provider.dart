import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/customer_photo_providers.dart';
import '../../../core/providers/customer_providers.dart';
import '../../../domain/entities/customer_entity.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Add / Edit Customer Form State
// ─────────────────────────────────────────────────────────────────────────────

class CustomerFormState {
  final bool isLoading;
  final bool isSuccess;
  final String? errorMessage;
  final String? noticeMessage;

  const CustomerFormState({
    this.isLoading = false,
    this.isSuccess = false,
    this.errorMessage,
    this.noticeMessage,
  });

  CustomerFormState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? errorMessage,
    String? noticeMessage,
    bool clearError = false,
    bool clearNotice = false,
  }) {
    return CustomerFormState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      noticeMessage: clearNotice ? null : noticeMessage ?? this.noticeMessage,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class CustomerFormNotifier extends StateNotifier<CustomerFormState> {
  final Ref _ref;

  CustomerFormNotifier(this._ref) : super(const CustomerFormState());

  /// Saves a new customer and returns the persisted record on success.
  Future<CustomerEntity?> addCustomer({
    required String name,
    required String phone,
    String? secondaryPhone,
    String? address,
    String? notes,
    Uint8List? photoBytes,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearNotice: true,
    );

    final firebaseUser = _ref.read(firebaseAuthProvider).currentUser;
    if (firebaseUser == null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'You must be signed in to add a customer.',
      );
      return null;
    }
    final userId = firebaseUser.uid;
    try {
      await firebaseUser.getIdToken(true);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            'Your sign-in session could not be refreshed. Please sign in again.',
      );
      return null;
    }

    final currentUser = _ref.read(currentUserProvider);
    final customer = CustomerEntity(
      id: '', // Firestore will generate this
      userId: userId,
      name: name.trim(),
      phone: phone.trim(),
      secondaryPhone: secondaryPhone?.trim().isEmpty == true
          ? null
          : secondaryPhone?.trim(),
      address: address?.trim().isEmpty == true ? null : address?.trim(),
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      createdAt: DateTime.now(),
      // Store owner info so the other party sees who added them
      ownerName: currentUser?.name,
      ownerPhone: currentUser?.phone,
    );

    final useCase = _ref.read(addCustomerUseCaseProvider);
    final result = await useCase(customer);

    return result.fold<Future<CustomerEntity?>>(
      (failure) async {
        state = state.copyWith(
          isLoading: false,
          errorMessage: failure.message,
        );
        return null;
      },
      (saved) async {
        String? notice;
        var customerToOpen = saved;
        if (photoBytes != null) {
          try {
            final path = await _ref.read(customerPhotoServiceProvider).upload(
                  userId: saved.userId,
                  customerId: saved.id,
                  bytes: photoBytes,
                );
            final photoUpdate = await _ref.read(updateCustomerUseCaseProvider)(
              saved.copyWith(photoPath: path, updatedAt: DateTime.now()),
            );
            photoUpdate.fold<void>(
              (failure) => notice = failure.message,
              (updated) => customerToOpen = updated,
            );
          } catch (error) {
            notice = error.toString().replaceFirst(RegExp(r'^.*?:\s*'), '');
          }
        }
        state = state.copyWith(isLoading: false, isSuccess: true);
        if (notice != null) {
          state = state.copyWith(noticeMessage: notice);
        }
        return customerToOpen;
      },
    );
  }

  /// Updates an existing customer. Returns true on success.
  Future<bool> updateCustomer({
    required CustomerEntity existing,
    required String name,
    required String phone,
    String? secondaryPhone,
    String? address,
    String? notes,
    Uint8List? photoBytes,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearNotice: true,
    );

    final updated = existing.copyWith(
      name: name.trim(),
      phone: phone.trim(),
      secondaryPhone: secondaryPhone?.trim().isEmpty == true
          ? null
          : secondaryPhone?.trim(),
      clearSecondaryPhone: secondaryPhone?.trim().isEmpty == true,
      address: address?.trim().isEmpty == true ? null : address?.trim(),
      clearAddress: address?.trim().isEmpty == true,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      clearNotes: notes?.trim().isEmpty == true,
      updatedAt: DateTime.now(),
    );

    final useCase = _ref.read(updateCustomerUseCaseProvider);
    final result = await useCase(updated);

    String? photoNotice;
    if (result.isRight() && photoBytes != null) {
      try {
        final path = await _ref.read(customerPhotoServiceProvider).upload(
              userId: updated.userId,
              customerId: updated.id,
              bytes: photoBytes,
            );
        final photoResult = await useCase(
          updated.copyWith(photoPath: path, updatedAt: DateTime.now()),
        );
        photoResult.fold(
          (failure) => photoNotice = failure.message,
          (_) {},
        );
      } catch (error) {
        photoNotice = error.toString().replaceFirst(RegExp(r'^.*?:\s*'), '');
      }
    }

    return result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: failure.message,
        );
        return false;
      },
      (_) {
        state = state.copyWith(
          isLoading: false,
          isSuccess: true,
          noticeMessage: photoNotice,
        );
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
