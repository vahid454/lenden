import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/customer_providers.dart';
import '../../../domain/entities/customer_entity.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Customer List Page State
// ─────────────────────────────────────────────────────────────────────────────

class CustomerListState {
  final bool isSearching;
  final String searchQuery;
  final bool isSearchLoading;
  final List<CustomerEntity>? searchResults;
  final String? errorMessage;
  final String? deletingId; // ID of customer being deleted (for UI feedback)

  const CustomerListState({
    this.isSearching = false,
    this.searchQuery = '',
    this.isSearchLoading = false,
    this.searchResults,
    this.errorMessage,
    this.deletingId,
  });

  bool get hasSearchQuery => searchQuery.trim().isNotEmpty;

  CustomerListState copyWith({
    bool? isSearching,
    String? searchQuery,
    bool? isSearchLoading,
    List<CustomerEntity>? searchResults,
    String? errorMessage,
    String? deletingId,
    bool clearError = false,
    bool clearDeleting = false,
    bool clearSearch = false,
  }) {
    return CustomerListState(
      isSearching: isSearching ?? this.isSearching,
      searchQuery: searchQuery ?? this.searchQuery,
      isSearchLoading: isSearchLoading ?? this.isSearchLoading,
      searchResults: clearSearch ? null : searchResults ?? this.searchResults,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      deletingId: clearDeleting ? null : deletingId ?? this.deletingId,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class CustomerListNotifier extends StateNotifier<CustomerListState> {
  final Ref _ref;
  Timer? _searchDebounce;

  CustomerListNotifier(this._ref) : super(const CustomerListState());

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ── Search ──────────────────────────────────────────────────────────────

  void onSearchChanged(String query) {
    state = state.copyWith(
      searchQuery: query,
      isSearching: query.isNotEmpty,
    );

    _searchDebounce?.cancel();

    if (query.trim().isEmpty) {
      state = state.copyWith(clearSearch: true, isSearching: false);
      return;
    }

    // Debounce 350ms to avoid hammering Firestore on each keystroke
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    final userId = _ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    state = state.copyWith(isSearchLoading: true);

    final useCase = _ref.read(searchCustomersUseCaseProvider);
    final result = await useCase(userId: userId, query: query);

    result.fold(
      (failure) => state = state.copyWith(
        isSearchLoading: false,
        errorMessage: failure.message,
      ),
      (customers) => state = state.copyWith(
        isSearchLoading: false,
        searchResults: customers,
        clearError: true,
      ),
    );
  }

  void clearSearch() {
    _searchDebounce?.cancel();
    state = const CustomerListState();
  }

  // ── Delete ──────────────────────────────────────────────────────────────

  Future<bool> deleteCustomer(String customerId) async {
    state = state.copyWith(deletingId: customerId, clearError: true);

    final useCase = _ref.read(deleteCustomerUseCaseProvider);
    final result = await useCase(customerId);

    return result.fold(
      (failure) {
        state = state.copyWith(
          clearDeleting: true,
          errorMessage: failure.message,
        );
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

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final customerListProvider =
    StateNotifierProvider.autoDispose<CustomerListNotifier, CustomerListState>(
  (ref) => CustomerListNotifier(ref),
);
