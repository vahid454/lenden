import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/customer_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/utils/app_formatters.dart';
import '../../common/widgets/common_widgets.dart';
import '../../customers/widgets/customer_card.dart';
import '../../cashbook/pages/cashbook_page.dart';
import '../../reports/pages/reports_page.dart';
import '../widgets/profile_tab.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      appBar: _buildAppBar(context, ref, user?.name ?? 'User'),
      body: Column(
        children: [
          // ── Offline banner ───────────────────────────────────────────────
          if (!isOnline) _OfflineBanner(),

          Expanded(
            child: IndexedStack(
              index: _navIndex,
              children: [
                const _HomeTab(),
                const ReportsPage(),
                const CashbookPage(),
                ProfileTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context),
      floatingActionButton: _navIndex == 0 ? _buildFab(context) : null,
    );
  }

  AppBar _buildAppBar(BuildContext context, WidgetRef ref, String name) {
    final titles = ['Home', 'Reports', 'CashBook', 'Profile'];
    return AppBar(
      toolbarHeight: 74,
      title: _navIndex == 0
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Hello, ${name.split(' ').first}',
                    style: GoogleFonts.poppins(
                        fontSize: 22, fontWeight: FontWeight.w700)),
                Text('Track lending with confidence',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.5))),
              ],
            )
          : Text(titles[_navIndex],
              style: GoogleFonts.poppins(
                  fontSize: 22, fontWeight: FontWeight.w700)),
      actions: [
        if (_navIndex == 0)
          Tooltip(
            message: 'Search Customers',
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.tonalIcon(
                onPressed: () => context.push(AppRoutes.customers),
                icon: const Icon(Icons.search_rounded, size: 18),
                label: Text(
                  'Search',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return NavigationBar(
      selectedIndex: _navIndex,
      onDestinationSelected: (i) => setState(() => _navIndex = i),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.bar_chart_outlined),
          selectedIcon: Icon(Icons.bar_chart_rounded),
          label: 'Reports',
        ),
        NavigationDestination(
          icon: Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: Icon(Icons.account_balance_wallet_rounded),
          label: 'CashBook',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Profile',
        ),
      ],
    );
  }

  Widget _buildFab(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'dashboard_fab',
      onPressed: () => context.push(AppRoutes.addCustomer),
      child: const Icon(Icons.person_add_alt_1_rounded),
    );
  }
}

// ── Offline Banner ────────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.warningAmber,
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 16, color: Colors.black87),
          const SizedBox(width: 8),
          Text(
            'You\'re offline. Showing cached data.',
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black87),
          ),
        ],
      ),
    ).animate().slideY(begin: -1, end: 0);
  }
}

// ── Home Tab ──────────────────────────────────────────────────────────────────

class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersStreamProvider);
    final visibleCustomers = ref.watch(visibleCustomersProvider);
    final toReceive = ref.watch(totalToReceiveProvider);
    final toPay = ref.watch(totalToPayProvider);
    final net = ref.watch(netBalanceProvider);
    final customerCount = visibleCustomers.length;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(customersStreamProvider);
        ref.invalidate(sharedCustomersStreamProvider);
        await Future.delayed(const Duration(milliseconds: 600));
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── Net Balance Hero ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  _NetBalanceHero(
                    net: net,
                    toReceive: toReceive,
                    toPay: toPay,
                    customerCount: customerCount,
                  ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.08),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: _SummaryChip(
                        label: 'To Receive',
                        amount: toReceive,
                        color: AppColors.success,
                        bg: AppColors.successLight,
                        icon: Icons.arrow_downward_rounded,
                      ).animate().fadeIn(delay: 100.ms)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _SummaryChip(
                        label: 'To Pay',
                        amount: toPay,
                        color: AppColors.danger,
                        bg: AppColors.dangerLight,
                        icon: Icons.arrow_upward_rounded,
                      ).animate().fadeIn(delay: 150.ms)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _QuickInsightStrip(
                    customerCount: customerCount,
                    customerWithDuesCount:
                        visibleCustomers
                            .where((c) => !c.isSettled)
                            .length,
                    isNetPositive: net >= 0,
                  ).animate().fadeIn(delay: 180.ms),
                ],
              ),
            ),
          ),

          // ── Section heading ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Customers',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  TextButton(
                    onPressed: () => context.push(AppRoutes.customers),
                    child: Text('See All',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ],
              ).animate().fadeIn(delay: 200.ms),
            ),
          ),

          // ── Customer List ────────────────────────────────────────────────
          customersAsync.when(
            loading: () => SliverToBoxAdapter(child: _buildShimmer()),
            error: (e, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ErrorDisplay(message: e.toString()),
              ),
            ),
            data: (customers) {
              if (visibleCustomers.isEmpty) {
                return SliverToBoxAdapter(
                  child: _EmptyHomeState().animate().fadeIn(delay: 200.ms),
                );
              }

              final sorted = [...visibleCustomers]
                ..sort((a, b) => b.absBalance.compareTo(a.absBalance));
              final preview = sorted.take(6).toList();
              final currentUserId = ref.watch(currentUserProvider)?.id;

              return SliverList(
                delegate: SliverChildBuilderDelegate((ctx, i) {
                  if (i == preview.length) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: OutlinedButton(
                        onPressed: () => context.push(AppRoutes.customers),
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 44)),
                        child: Text('View all ${visibleCustomers.length} customers',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600)),
                      ),
                    );
                  }
                  final c = preview[i];
                  final isSharedLedger =
                      currentUserId != null && c.userId != currentUserId;
                  return CustomerCard(
                    customer: c,
                    animationIndex: i,
                    invertPerspective: isSharedLedger,
                    showSharedBadge: isSharedLedger,
                    onTap: () =>
                        context.push(AppRoutes.customerDetail(c.id), extra: c),
                  );
                }, childCount: preview.length + (visibleCustomers.length > 6 ? 1 : 0)),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Column(
      children: List.generate(
          4,
          (_) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                height: 72,
                decoration: BoxDecoration(
                    color: AppColors.shimmerBase,
                    borderRadius: BorderRadius.circular(16)),
              ).animate(onPlay: (c) => c.repeat()).shimmer(
                  duration: 1200.ms, color: AppColors.shimmerHighlight)),
    );
  }
}

// ── Net Balance Hero ──────────────────────────────────────────────────────────

class _NetBalanceHero extends StatelessWidget {
  final double net;
  final double toReceive;
  final double toPay;
  final int customerCount;

  const _NetBalanceHero({
    required this.net,
    required this.toReceive,
    required this.toPay,
    required this.customerCount,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPositive = net >= 0;
    final start = isPositive ? cs.primary : AppColors.danger;
    final end = isPositive
        ? cs.primary.withOpacity(0.72)
        : AppColors.danger.withOpacity(0.72);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [start, end],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: start.withOpacity(0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$customerCount active parties',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.account_balance_wallet_outlined,
                  color: Colors.white, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Text('Net Balance',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 4),
          Text(
            AppFormatters.rupee(net.abs()),
            style: GoogleFonts.poppins(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1),
          ),
          const SizedBox(height: 4),
          Text(
            net == 0
                ? '✓ All accounts settled'
                : isPositive
                    ? 'Overall you will receive'
                    : 'Overall you will pay',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 14),
          Row(children: [
            _NetChip('↓ ${AppFormatters.rupee(toReceive)} to receive'),
            const SizedBox(width: 8),
            _NetChip('↑ ${AppFormatters.rupee(toPay)} to pay'),
          ]),
        ],
      ),
    );
  }
}

class _NetChip extends StatelessWidget {
  final String label;
  const _NetChip(this.label);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.w500)),
      );
}

// ── Summary Chip ──────────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final Color bg;
  final IconData icon;
  const _SummaryChip(
      {required this.label,
      required this.amount,
      required this.color,
      required this.bg,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(height: 8),
        Text(AppFormatters.rupee(amount),
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w700, color: color)),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 11,
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
      ]),
    );
  }
}

class _QuickInsightStrip extends StatelessWidget {
  final int customerCount;
  final int customerWithDuesCount;
  final bool isNetPositive;

  const _QuickInsightStrip({
    required this.customerCount,
    required this.customerWithDuesCount,
    required this.isNetPositive,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _InsightPill(
              icon: Icons.groups_2_outlined,
              label: '$customerCount total customers',
              color: cs.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _InsightPill(
              icon: Icons.receipt_long_outlined,
              label: '$customerWithDuesCount need follow-up',
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _InsightPill(
              icon: isNetPositive
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              label: isNetPositive ? 'Net positive' : 'Net payable',
              color: isNetPositive ? AppColors.success : AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InsightPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.72),
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Empty Home State ──────────────────────────────────────────────────────────

class _EmptyHomeState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: Column(children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.08), shape: BoxShape.circle),
            child: Icon(Icons.group_outlined,
                size: 36, color: cs.primary.withOpacity(0.5)),
          ).animate().scale(curve: Curves.elasticOut),
          const SizedBox(height: 20),
          Text('No customers yet',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w700))
              .animate()
              .fadeIn(delay: 200.ms),
          const SizedBox(height: 8),
          Text('Add your first customer to start tracking udhar.',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: cs.onSurface.withOpacity(0.5),
                      height: 1.5),
                  textAlign: TextAlign.center)
              .animate()
              .fadeIn(delay: 300.ms),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => context.push(AppRoutes.addCustomer),
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
            label: Text('Add First Customer',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(minimumSize: const Size(200, 48)),
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
        ]),
      ),
    );
  }
}
