import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/customer_providers.dart';
import '../../../core/providers/transaction_providers.dart';
import '../../../domain/entities/transaction_entity.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class TransactionFormState {
  final bool isLoading;
  final bool isSuccess;
  final String? errorMessage;
  final TransactionType selectedType;

  const TransactionFormState({
    this.isLoading = false,
    this.isSuccess = false,
    this.errorMessage,
    this.selectedType = TransactionType.gave,
  });

  TransactionFormState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? errorMessage,
    bool clearError = false,
    TransactionType? selectedType,
  }) =>
      TransactionFormState(
        isLoading: isLoading ?? this.isLoading,
        isSuccess: isSuccess ?? this.isSuccess,
        errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
        selectedType: selectedType ?? this.selectedType,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class TransactionFormNotifier extends StateNotifier<TransactionFormState> {
  final Ref _ref;

  TransactionFormNotifier(this._ref) : super(const TransactionFormState());

  void setType(TransactionType type) =>
      state = state.copyWith(selectedType: type);

  // ── Add ─────────────────────────────────────────────────────────────────

  Future<TransactionEntity?> addTransaction({
    required String customerId,
    required double amount,
    required TransactionType type,
    required DateTime date,
    String? note,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final userId = _ref.read(currentUserProvider)?.id;
    if (userId == null) {
      state = state.copyWith(isLoading: false, errorMessage: 'Not signed in.');
      return null;
    }

    final tx = TransactionEntity(
      id: '',
      customerId: customerId,
      userId: userId,
      amount: amount,
      type: type,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      date: date,
      createdAt: DateTime.now(),
    );

    final useCase = _ref.read(addTransactionUseCaseProvider);
    final result = await useCase(tx);

    return result.fold(
      (f) {
        state = state.copyWith(isLoading: false, errorMessage: f.message);
        return null;
      },
      (savedTransaction) {
        _ref.invalidate(transactionsStreamProvider(customerId));
        _ref.invalidate(customersStreamProvider);
        state = state.copyWith(isLoading: false, isSuccess: true);
        return savedTransaction;
      },
    );
  }

  // ── Update ───────────────────────────────────────────────────────────────

  Future<TransactionEntity?> updateTransaction({
    required TransactionEntity existing,
    required double amount,
    required TransactionType type,
    required DateTime date,
    String? note,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final updated = existing.copyWith(
      amount: amount,
      type: type,
      date: date,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
    );

    final useCase = _ref.read(updateTransactionUseCaseProvider);
    final result = await useCase(
      oldTransaction: existing,
      newTransaction: updated,
    );

    return result.fold(
      (f) {
        state = state.copyWith(isLoading: false, errorMessage: f.message);
        return null;
      },
      (savedTransaction) {
        _ref.invalidate(transactionsStreamProvider(existing.customerId));
        _ref.invalidate(customersStreamProvider);
        state = state.copyWith(isLoading: false, isSuccess: true);
        return savedTransaction;
      },
    );
  }

  // ── Delete ───────────────────────────────────────────────────────────────

  Future<bool> deleteTransaction(TransactionEntity tx) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final useCase = _ref.read(deleteTransactionUseCaseProvider);
    final result = await useCase(tx);

    return result.fold(
      (f) {
        state = state.copyWith(isLoading: false, errorMessage: f.message);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false);
        return true;
      },
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final transactionFormProvider = StateNotifierProvider.autoDispose
    .family<TransactionFormNotifier, TransactionFormState, String>(
  (ref, customerId) => TransactionFormNotifier(ref),
);
