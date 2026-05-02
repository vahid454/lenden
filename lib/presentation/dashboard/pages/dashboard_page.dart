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
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_formatters.dart';
import '../../common/widgets/common_widgets.dart';
import '../../customers/widgets/customer_card.dart';
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
    final user     = ref.watch(currentUserProvider);
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      body: Column(children: [
        if (!isOnline) _OfflineBanner(),
        Expanded(child: IndexedStack(
          index: _navIndex,
          children: [
            _HomeTab(userName: user?.name ?? 'User'),
            const ReportsPage(),
            ProfileTab(),
          ],
        )),
      ]),
      bottomNavigationBar: _BottomNav(
        index:    _navIndex,
        onChange: (i) => setState(() => _navIndex = i),
      ),
      floatingActionButton: _navIndex == 0
          ? FloatingActionButton.extended(
              heroTag:   'home_fab',
              onPressed: () => context.push(AppRoutes.addCustomer),
              icon:      const Icon(Icons.person_add_alt_1_rounded, size: 20),
              label:     Text('Add Customer',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            )
          : null,
    );
  }
}

// ── Bottom Navigation ─────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChange;
  const _BottomNav({required this.index, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        boxShadow: [
          BoxShadow(
            color:     Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 20,
            offset:    const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home_outlined,     activeIcon: Icons.home_rounded,         label: 'Home',    active: index == 0, onTap: () => onChange(0)),
              _NavItem(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart_rounded,   label: 'Reports', active: index == 1, onTap: () => onChange(1)),
              _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded,  label: 'Profile', active: index == 2, onTap: () => onChange(2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.activeIcon,
    required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final color = active ? cs.primary : cs.onSurface.withOpacity(0.45);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color:        active ? cs.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(active ? activeIcon : icon, color: color, size: 24),
          const SizedBox(height: 3),
          Text(label, style: GoogleFonts.poppins(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }
}

// ── Offline banner ────────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: AppColors.warningAmber,
    child: Row(children: [
      const Icon(Icons.wifi_off_rounded, size: 14, color: Colors.black87),
      const SizedBox(width: 8),
      Text('You\'re offline. Showing cached data.',
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500,
              color: Colors.black87)),
    ]),
  ).animate().slideY(begin: -1, end: 0);
}

// ── Home Tab ──────────────────────────────────────────────────────────────────

class _HomeTab extends ConsumerWidget {
  final String userName;
  const _HomeTab({required this.userName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs              = Theme.of(context).colorScheme;
    final isDark          = Theme.of(context).brightness == Brightness.dark;
    final toReceive       = ref.watch(totalToReceiveProvider);
    final toPay           = ref.watch(totalToPayProvider);
    final net             = ref.watch(netBalanceProvider);
    final customersAsync  = ref.watch(customersStreamProvider);
    final visibleCustomers = ref.watch(visibleCustomersProvider);
    final currentUserId   = ref.watch(currentUserProvider)?.id;
    final firstName       = userName.split(' ').first;
    final hour            = DateTime.now().hour;
    final greeting        = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [

        // ── Premium App Bar ────────────────────────────────────────────────
        SliverAppBar(
          floating:   true,
          snap:       true,
          elevation:  0,
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
          surfaceTintColor: Colors.transparent,
          title: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(greeting,
                  style: GoogleFonts.poppins(fontSize: 12,
                      color: cs.onSurface.withOpacity(0.5),
                      fontWeight: FontWeight.w400)),
              Text(firstName,
                  style: GoogleFonts.poppins(fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface, height: 1.1)),
            ])),
          ]),
          actions: [
            Consumer(builder: (ctx, ref, _) {
              final isDarkMode = ref.watch(themeModeProvider.notifier).isDark;
              return IconButton(
                icon: Icon(isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 22),
                onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
              );
            }),
            IconButton(
              icon: const Icon(Icons.search_rounded, size: 22),
              onPressed: () => context.push(AppRoutes.customers),
            ),
            const SizedBox(width: 4),
          ],
        ),

        // ── Net Balance Hero ───────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _NetBalanceHero(
                net: net, toReceive: toReceive, toPay: toPay)
                .animate().fadeIn(delay: 50.ms).slideY(begin: 0.06),
          ),
        ),

        // ── Summary chips ──────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              Expanded(child: _SummaryChip(
                label: 'To Receive', amount: toReceive,
                color: AppColors.success, bg: AppColors.successLight,
                icon: Icons.arrow_downward_rounded,
              ).animate().fadeIn(delay: 100.ms)),
              const SizedBox(width: 12),
              Expanded(child: _SummaryChip(
                label: 'To Pay', amount: toPay,
                color: AppColors.danger, bg: AppColors.dangerLight,
                icon: Icons.arrow_upward_rounded,
              ).animate().fadeIn(delay: 140.ms)),
            ]),
          ),
        ),

        // ── Section heading ────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Customers',
                    style: GoogleFonts.poppins(fontSize: 16,
                        fontWeight: FontWeight.w700)),
                TextButton(
                  onPressed: () => context.push(AppRoutes.customers),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text('See All →',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ],
            ).animate().fadeIn(delay: 180.ms),
          ),
        ),

        // ── Customer list ──────────────────────────────────────────────────
        if (customersAsync.isLoading && visibleCustomers.isEmpty)
          SliverToBoxAdapter(child: _buildShimmer())
        else if (visibleCustomers.isEmpty)
          SliverToBoxAdapter(
            child: _EmptyState().animate().fadeIn(delay: 200.ms))
        else
          SliverList(
            delegate: SliverChildBuilderDelegate((ctx, i) {
              if (i >= visibleCustomers.take(6).length) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: OutlinedButton(
                    onPressed: () => context.push(AppRoutes.customers),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44)),
                    child: Text('View all ${visibleCustomers.length} customers',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  ),
                );
              }
              final c            = visibleCustomers[i];
              final isSharedLedger = currentUserId != null && c.userId != currentUserId;
              return CustomerCard(
                customer:          c,
                animationIndex:    i,
                invertPerspective: isSharedLedger,
                showSharedBadge:   isSharedLedger,
                onTap: () => context.push(
                    AppRoutes.customerDetail(c.id), extra: c),
              );
            }, childCount: visibleCustomers.take(6).length +
                (visibleCustomers.length > 6 ? 1 : 0)),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildShimmer() {
    return Column(children: List.generate(3, (_) => Container(
      margin:  const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      height:  76,
      decoration: BoxDecoration(color: AppColors.shimmerBase,
          borderRadius: BorderRadius.circular(18)),
    ).animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1200.ms, color: AppColors.shimmerHighlight)));
  }
}

// ── Net Balance Hero ──────────────────────────────────────────────────────────

class _NetBalanceHero extends StatelessWidget {
  final double net, toReceive, toPay;
  const _NetBalanceHero({required this.net, required this.toReceive, required this.toPay});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPositive = net >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withOpacity(0.78)],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(
          color:     cs.primary.withOpacity(0.32),
          blurRadius: 24,
          offset:    const Offset(0, 10),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Net Balance',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70,
                  fontWeight: FontWeight.w500)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(net == 0 ? 'All Settled' : isPositive ? 'To Receive' : 'To Pay',
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(AppFormatters.rupee(net.abs()),
            style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.w800,
                color: Colors.white, height: 1)),
        const SizedBox(height: 16),
        Row(children: [
          _PillStat(label: '↓ ${AppFormatters.rupee(toReceive)}', sub: 'Receive'),
          const SizedBox(width: 10),
          _PillStat(label: '↑ ${AppFormatters.rupee(toPay)}', sub: 'Pay'),
        ]),
      ]),
    );
  }
}

class _PillStat extends StatelessWidget {
  final String label, sub;
  const _PillStat({required this.label, required this.sub});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.16),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
      Text(sub,   style: GoogleFonts.poppins(fontSize: 10, color: Colors.white70)),
    ]),
  );
}

// ── Summary chips ─────────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final String label; final double amount;
  final Color color, bg; final IconData icon;
  const _SummaryChip({required this.label, required this.amount,
    required this.color, required this.bg, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs     = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        boxShadow: isDark ? [] : [
          BoxShadow(color: Colors.black.withOpacity(0.03),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 16)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(AppFormatters.rupee(amount), style: GoogleFonts.poppins(
              fontSize: 16, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: GoogleFonts.poppins(fontSize: 11,
              color: cs.onSurface.withOpacity(0.5))),
        ])),
      ]),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color:        cs.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: Column(children: [
          Container(width: 80, height: 80,
              decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.08), shape: BoxShape.circle),
              child: Icon(Icons.group_outlined, size: 36,
                  color: cs.primary.withOpacity(0.5))),
          const SizedBox(height: 20),
          Text('No customers yet', style: GoogleFonts.poppins(
              fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Add your first customer to start tracking.',
              style: GoogleFonts.poppins(fontSize: 13,
                  color: cs.onSurface.withOpacity(0.45), height: 1.5),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
