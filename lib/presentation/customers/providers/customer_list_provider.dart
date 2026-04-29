import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/customer_providers.dart';
import '../../../domain/entities/customer_entity.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class CustomerListState {
  final bool isSearching;
  final String searchQuery;
  final bool isSearchLoading;
  final List<CustomerEntity>? searchResults;
  final String? errorMessage;
  final String? deletingId;

  const CustomerListState({
    this.isSearching     = false,
    this.searchQuery     = '',
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
    bool clearError    = false,
    bool clearDeleting = false,
    bool clearSearch   = false,
  }) => CustomerListState(
    isSearching:     isSearching     ?? this.isSearching,
    searchQuery:     searchQuery     ?? this.searchQuery,
    isSearchLoading: isSearchLoading ?? this.isSearchLoading,
    searchResults:   clearSearch  ? null : searchResults ?? this.searchResults,
    errorMessage:    clearError   ? null : errorMessage  ?? this.errorMessage,
    deletingId:      clearDeleting ? null : deletingId   ?? this.deletingId,
  );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class CustomerListNotifier extends StateNotifier<CustomerListState> {
  final Ref _ref;

  CustomerListNotifier(this._ref) : super(const CustomerListState());

  // ── Search ────────────────────────────────────────────────────────────────

  void onSearchChanged(String query) {
    final trimmedQuery = query.trim();
    state = state.copyWith(
      searchQuery: query,
      isSearching: trimmedQuery.isNotEmpty,
    );

    if (trimmedQuery.isEmpty) {
      state = state.copyWith(clearSearch: true, isSearching: false);
      return;
    }

    _performSearch(trimmedQuery);
  }

  void _performSearch(String query) {
    final visibleCustomers = _ref.read(visibleCustomersProvider);
    final lowerQuery = query.toLowerCase();
    final list = visibleCustomers.where((customer) {
      return customer.name.toLowerCase().contains(lowerQuery) ||
          customer.phone.contains(query);
    }).toList();

    state = state.copyWith(
      isSearchLoading: false,
      searchResults: list,
      clearError: true,
    );
  }

  void clearSearch() {
    state = const CustomerListState();
  }

  // ── Delete DISABLED — data safety ────────────────────────────────────────
  // Deletion is blocked by Firestore rules and disabled in UI.
  // This method exists for API compat but always returns false.
  Future<bool> deleteCustomer(String customerId) async {
    // Intentionally no-op — Firestore rules block delete anyway
    state = state.copyWith(
      errorMessage: 'Customer deletion is disabled. Contact support if needed.',
    );
    return false;
  }

  void clearError() => state = state.copyWith(clearError: true);
}

// ── Provider ──────────────────────────────────────────────────────────────────

final customerListProvider =
    StateNotifierProvider.autoDispose<CustomerListNotifier, CustomerListState>(
  (ref) => CustomerListNotifier(ref),
);
