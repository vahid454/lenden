import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/customer_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../domain/entities/customer_entity.dart';
import '../../common/widgets/common_widgets.dart';
import '../providers/customer_list_provider.dart';
import '../widgets/customer_card.dart';
import '../widgets/customer_search_bar.dart';

/// Displays all customers for the logged-in user in real-time.
/// Supports inline search and quick navigation into each ledger.
class CustomerListPage extends ConsumerWidget {
  const CustomerListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersStreamProvider);
    final sharedCustomersAsync = ref.watch(sharedCustomersStreamProvider);
    final visibleCustomers = ref.watch(visibleCustomersProvider);
    final listState = ref.watch(customerListProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          // ── Search Bar ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: CustomerSearchBar(
              onChanged: (q) =>
                  ref.read(customerListProvider.notifier).onSearchChanged(q),
              onClear: () =>
                  ref.read(customerListProvider.notifier).clearSearch(),
            ),
          ).animate().fadeIn(duration: 300.ms),

          // ── Error Banner ───────────────────────────────────────────────
          if (listState.errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ErrorDisplay(message: listState.errorMessage!),
            ).animate().fadeIn().shakeX(amount: 4),

          // ── List Body ──────────────────────────────────────────────────
          Expanded(
            child: listState.isSearching
                ? _buildSearchResults(context, ref, listState)
                : _buildCustomerList(
                    context,
                    ref,
                    customersAsync: customersAsync,
                    sharedCustomersAsync: sharedCustomersAsync,
                    visibleCustomers: visibleCustomers,
                  ),
          ),
        ],
      ),
      floatingActionButton: _buildFab(context),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Customers',
            style:
                GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          Consumer(builder: (ctx, ref, _) {
            final count =
                ref.watch(visibleCustomersProvider).length;
            return Text(
              '$count ${count == 1 ? 'party' : 'parties'}',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.5),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Realtime Customer List ─────────────────────────────────────────────────

  Widget _buildCustomerList(
    BuildContext context,
    WidgetRef ref,
    {
    required AsyncValue<List<CustomerEntity>> customersAsync,
    required AsyncValue<List<CustomerEntity>> sharedCustomersAsync,
    required List<CustomerEntity> visibleCustomers,
  }) {
    if (visibleCustomers.isNotEmpty) {
      return _buildList(context, ref, visibleCustomers);
    }

    if (customersAsync.isLoading || sharedCustomersAsync.isLoading) {
      return _buildShimmerList();
    }

    final error = customersAsync.asError?.error ?? sharedCustomersAsync.asError?.error;
    if (error != null) {
      return _buildErrorState(context, error.toString());
    }

    return _buildEmptyState(context);
  }

  // ── Search Results ─────────────────────────────────────────────────────────

  Widget _buildSearchResults(
    BuildContext context,
    WidgetRef ref,
    CustomerListState state,
  ) {
    if (state.isSearchLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final results = state.searchResults ?? [];

    if (results.isEmpty && state.hasSearchQuery) {
      return _buildSearchEmptyState(context, state.searchQuery);
    }

    return _buildList(context, ref, results);
  }

  // ── List Builder ───────────────────────────────────────────────────────────

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<CustomerEntity> customers,
  ) {
    final listState = ref.watch(customerListProvider);

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: customers.length,
      itemBuilder: (context, index) {
        final customer = customers[index];
        final isDeleting = listState.deletingId == customer.id;
        final currentUserId = ref.watch(currentUserProvider)?.id;
        final isSharedLedger =
            currentUserId != null && customer.userId != currentUserId;

        return CustomerCard(
          customer: customer,
          animationIndex: index,
          isDeleting: isDeleting,
          invertPerspective: isSharedLedger,
          showSharedBadge: isSharedLedger,
          onTap: () => context.push(
            AppRoutes.customerDetail(customer.id),
            extra: customer,
          ),
        );
      },
    );
  }

  // ── FAB ────────────────────────────────────────────────────────────────────

  Widget _buildFab(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'add_customer_fab',
      onPressed: () => context.push(AppRoutes.addCustomer),
      icon: const Icon(Icons.person_add_alt_1_rounded),
      label: Text(
        'Add',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
    );
  }

  // ── Empty States ───────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.group_outlined,
                size: 44,
                color: colorScheme.primary.withOpacity(0.5),
              ),
            ).animate().scale(curve: Curves.elasticOut, duration: 600.ms),
            const SizedBox(height: 24),
            Text(
              'No customers yet',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 8),
            Text(
              'Add your first customer and start\ntracking your udhar.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: colorScheme.onSurface.withOpacity(0.5),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: () => context.push(AppRoutes.addCustomer),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: Text(
                'Add First Customer',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(200, 48),
              ),
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchEmptyState(BuildContext context, String query) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: colorScheme.onSurface.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No results for "$query"',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different name or check spelling.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: colorScheme.onSurface.withOpacity(0.4),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 56, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(
              'Could not load customers',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Shimmer Placeholder ────────────────────────────────────────────────────

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: 6,
      itemBuilder: (_, index) => const _ShimmerTile(),
    );
  }
}

// ── Shimmer Tile ──────────────────────────────────────────────────────────────

class _ShimmerTile extends StatelessWidget {
  const _ShimmerTile();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        isDark ? AppColors.darkSurfaceVariant : AppColors.shimmerBase;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _shimmerBox(46, 46, circular: true, base: baseColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(14, 120, base: baseColor),
                const SizedBox(height: 6),
                _shimmerBox(11, 80, base: baseColor),
              ],
            ),
          ),
          _shimmerBox(14, 60, base: baseColor),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1200.ms, color: AppColors.shimmerHighlight);
  }

  Widget _shimmerBox(double h, double w,
      {bool circular = false, required Color base}) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: base,
        borderRadius:
            circular ? BorderRadius.circular(50) : BorderRadius.circular(8),
      ),
    );
  }
}
