import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/transaction_providers.dart';
import '../../../domain/entities/transaction_entity.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class TransactionListState {
  final String? deletingId;
  final String? errorMessage;

  const TransactionListState({this.deletingId, this.errorMessage});

  TransactionListState copyWith({
    String? deletingId,
    String? errorMessage,
    bool clearDeleting = false,
    bool clearError    = false,
  }) =>
      TransactionListState(
        deletingId:   clearDeleting ? null : deletingId   ?? this.deletingId,
        errorMessage: clearError    ? null : errorMessage ?? this.errorMessage,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class TransactionListNotifier extends StateNotifier<TransactionListState> {
  final Ref _ref;

  TransactionListNotifier(this._ref) : super(const TransactionListState());

  Future<bool> deleteTransaction(TransactionEntity tx) async {
    state = state.copyWith(deletingId: tx.id, clearError: true);

    final useCase = _ref.read(deleteTransactionUseCaseProvider);
    final result  = await useCase(tx);

    return result.fold(
      (f) {
        state = state.copyWith(
            clearDeleting: true, errorMessage: f.message);
        return false;
      },
      (_) {
        state = state.copyWith(clearDeleting: true);
        return true;
      },
    );
  }

  void clearError() => state = state.copyWith(clearError: true);
}

// ── Provider ──────────────────────────────────────────────────────────────────

final transactionListProvider = StateNotifierProvider.autoDispose
    .family<TransactionListNotifier, TransactionListState, String>(
  (ref, customerId) => TransactionListNotifier(ref),
);
