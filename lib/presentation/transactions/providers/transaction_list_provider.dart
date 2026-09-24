import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    bool clearError = false,
  }) =>
      TransactionListState(
        deletingId: clearDeleting ? null : deletingId ?? this.deletingId,
        errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class TransactionListNotifier extends StateNotifier<TransactionListState> {
  TransactionListNotifier() : super(const TransactionListState());

  Future<bool> deleteTransaction(TransactionEntity _) async {
    state = state.copyWith(
      clearDeleting: true,
      errorMessage:
          'Entry deletion is disabled to protect your ledger history.',
    );
    return false;
  }

  void clearError() => state = state.copyWith(clearError: true);
}

// ── Provider ──────────────────────────────────────────────────────────────────

final transactionListProvider = StateNotifierProvider.autoDispose
    .family<TransactionListNotifier, TransactionListState, String>(
  (ref, customerId) => TransactionListNotifier(),
);
