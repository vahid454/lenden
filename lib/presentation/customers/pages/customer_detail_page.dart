import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/customer_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../domain/entities/customer_entity.dart';
import '../../../domain/entities/transaction_entity.dart';
import '../../common/widgets/common_widgets.dart';
import '../../transactions/pages/add_edit_transaction_page.dart';
import '../../transactions/widgets/transaction_tile.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/transaction_providers.dart' show transactionsStreamProvider;
import '../../../core/services/pdf_export_service.dart';
import '../../../core/services/share_service.dart';
import '../../../core/utils/app_formatters.dart';

/// Full customer ledger screen.
/// Shows balance, quick actions, and a real-time transaction history.
class CustomerDetailPage extends ConsumerWidget {
  final String           customerId;
  final CustomerEntity?  initialCustomer;

  const CustomerDetailPage({
    super.key,
    required this.customerId,
    this.initialCustomer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersStreamProvider);
    final customers = customersAsync.valueOrNull;

    // Live customer data (balance updates when transactions change).
    // Never force-unwrap `initialCustomer` because deep links/opening from
    // notifications may not pass `extra`.
    final matchedCustomers =
        customers?.where((c) => c.id == customerId).toList() ?? const [];
    final customer =
        (matchedCustomers.isNotEmpty ? matchedCustomers.first : null) ??
            initialCustomer;

    if (customer == null) {
      if (customersAsync.hasError) {
        return Scaffold(
          appBar: AppBar(),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not open this customer right now. Please go back and try again.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ),
          ),
        );
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          _buildSliverAppBar(ctx, ref, customer),
        ],
        body: _TransactionListBody(customer: customer),
      ),
      floatingActionButton: _buildFab(context, customer),
    );
  }

  // ── PDF Export ───────────────────────────────────────────────────────────
  Future<void> _exportPdf(
    BuildContext context,
    WidgetRef ref,
    CustomerEntity customer,
  ) async {
    final txs     = ref.read(transactionsStreamProvider(customer.id)).valueOrNull ?? [];
    final user    = ref.read(currentUserProvider);
    final service = ref.read(pdfExportServiceProvider);
    final snack   = ScaffoldMessenger.of(context);

    snack.showSnackBar(const SnackBar(
      content:  Text('Generating PDF…'),
      behavior: SnackBarBehavior.floating,
    ));

    try {
      final file = await service.generateCustomerLedger(
        customer:     customer,
        transactions: txs,
        businessName: user?.businessName ?? '',
        ownerName: user?.name ?? '',
      );
      snack.hideCurrentSnackBar();
      if (context.mounted) {
        await ShareService.sharePdf(file, customer.name);
      }
    } catch (e) {
      snack.hideCurrentSnackBar();
      snack.showSnackBar(SnackBar(
        content:         Text('Export failed: $e'),
        backgroundColor: AppColors.danger,
        behavior:        SnackBarBehavior.floating,
      ));
    }
  }

  // ── SliverAppBar with collapsing header ───────────────────────────────────

  Widget _buildSliverAppBar(
    BuildContext context,
    WidgetRef ref,
    CustomerEntity customer,
  ) {
    final cs = Theme.of(context).colorScheme;

    return SliverAppBar(
      expandedHeight: 320,
      pinned:         true,
      backgroundColor: cs.surface,
      leading: IconButton(
        onPressed: () => context.pop(),
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
      ),
      actions: [
        IconButton(
          icon:    const Icon(Icons.edit_outlined),
          tooltip: 'Edit Customer',
          onPressed: () => context.push(AppRoutes.editCustomer, extra: customer),
        ),
        IconButton(
          icon:    const Icon(Icons.picture_as_pdf_outlined),
          tooltip: 'Export PDF',
          onPressed: () => _exportPdf(context, ref, customer),
        ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: _HeaderContent(customer: customer),
      ),
    );
  }

  // ── FAB ───────────────────────────────────────────────────────────────────

  Widget _buildFab(BuildContext context, CustomerEntity customer) {
    return FloatingActionButton.extended(
      heroTag:  'add_txn_fab',
      onPressed: () => _openAddTransaction(context, customer),
      icon:  const Icon(Icons.add_rounded),
      label: Text('Add Entry',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
    );
  }

  void _openAddTransaction(BuildContext context, CustomerEntity customer) async {
    // Await so we can invalidate streams immediately after transaction is saved
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (ctx, anim, _) => AddEditTransactionPage(
          customerId:   customer.id,
          customerName: customer.name,
        ),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOutCubic))
              .animate(anim),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
    // Firestore streams auto-update, but invalidating forces immediate rebuild
    // on lower-end devices where stream events can be delayed
    if (context.mounted) {
      // No manual invalidation needed — Firestore snapshots() auto-fires
      // The streams are already listening; this is just insurance
    }
  }

}

// ── Header content ────────────────────────────────────────────────────────────

class _HeaderContent extends ConsumerWidget {
  final CustomerEntity customer;
  const _HeaderContent({required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color accentColor;
    if (customer.isCreditor)      accentColor = AppColors.success;
    else if (customer.isDebtor)   accentColor = AppColors.danger;
    else                          accentColor = cs.primary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 56, 20, 0),
        child: Column(
          children: [
            // Avatar
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color:  accentColor.withOpacity(0.12),
                shape:  BoxShape.circle,
                border: Border.all(color: accentColor.withOpacity(0.4), width: 2),
              ),
              child: Center(
                child: Text(
                  customer.initials,
                  style: GoogleFonts.poppins(
                    fontSize: 22, fontWeight: FontWeight.w700, color: accentColor),
                ),
              ),
            ),

            const SizedBox(height: 8),

            Text(
              customer.name,
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              customer.phone,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: cs.onSurface.withOpacity(0.45)),
            ),

            const SizedBox(height: 14),

            // Balance pill
            _BalancePill(customer: customer),

            const SizedBox(height: 16),

            // Quick actions
            _QuickActions(customer: customer, ref: ref),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

// ── Balance pill ──────────────────────────────────────────────────────────────

class _BalancePill extends StatelessWidget {
  final CustomerEntity customer;
  const _BalancePill({required this.customer});

  @override
  Widget build(BuildContext context) {
    Color color; Color bg; String text; IconData icon;
    if (customer.isSettled) {
      color = Colors.grey; bg = Colors.grey.withOpacity(0.12);
      text = 'Settled ✓'; icon = Icons.check_circle_outline_rounded;
    } else if (customer.isCreditor) {
      color = AppColors.success; bg = AppColors.successLight;
      text = '₹${_fmt(customer.absBalance)} to receive'; icon = Icons.arrow_downward_rounded;
    } else {
      color = AppColors.danger; bg = AppColors.dangerLight;
      text = '₹${_fmt(customer.absBalance)} to pay'; icon = Icons.arrow_upward_rounded;
    }

    return Container(
      padding:    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(30)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(text, style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  String _fmt(double v) {
    return AppFormatters.currency(v);
  }
}

// ── Quick actions ─────────────────────────────────────────────────────────────

class _QuickActions extends ConsumerWidget {
  final CustomerEntity customer;
  const _QuickActions({required this.customer, WidgetRef? ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Btn(Icons.call_outlined,    'Call',    AppColors.primary, () async {
          final uri = Uri.parse('tel:${customer.phone}');
          if (await canLaunchUrl(uri)) launchUrl(uri);
        }),
        const SizedBox(width: 8),
        _Btn(Icons.sms_outlined,     'SMS',     const Color(0xFF0097A7), () async {
          final uri = Uri.parse('sms:${customer.phone}');
          if (await canLaunchUrl(uri)) launchUrl(uri);
        }),
        const SizedBox(width: 8),
        _Btn(Icons.copy_outlined,    'Copy',    Colors.grey.shade600, () {
          Clipboard.setData(ClipboardData(text: customer.phone));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Number copied!'),
                behavior: SnackBarBehavior.floating),
          );
        }),
        const SizedBox(width: 8),
        _Btn(Icons.share_outlined,   'Share',   const Color(0xFF25D366), () async {
          final txs = ref.read(transactionsStreamProvider(customer.id)).valueOrNull ?? [];
          final user = ref.read(currentUserProvider);
          await ShareService.shareOnWhatsApp(
            customer: customer,
            transactions: txs,
            senderName: user?.name ?? 'LenDen User',
            businessName: user?.businessName ?? '',
          );
        }),
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon; final String label;
  final Color color; final VoidCallback onTap;
  const _Btn(this.icon, this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:        color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 3),
            Text(label, style: GoogleFonts.poppins(
                fontSize: 10, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Transaction list body ─────────────────────────────────────────────────────

class _TransactionListBody extends ConsumerWidget {
  final CustomerEntity customer;
  const _TransactionListBody({required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync  = ref.watch(transactionsStreamProvider(customer.id));

    return Column(
      children: [
        const SizedBox(height: 8),
        // ── Section header ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transaction History',
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
              txAsync.whenData((list) => Text(
                '${list.length} entries',
                style: GoogleFonts.poppins(
                  fontSize:  12,
                  color:     Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
                ),
              )).valueOrNull ?? const SizedBox.shrink(),
            ],
          ),
        ),



        // ── List ────────────────────────────────────────────────────────
        Expanded(
          child: txAsync.when(
            loading: () => _buildShimmer(),
            error:   (e, _) => _buildError(context, ref, e.toString()),
            data:    (txList) {
              if (txList.isEmpty) return _buildEmpty(context, customer);
              return _buildGroupedList(context, ref, txList, customer);
            },
          ),
        ),
      ],
    );
  }

  // ── Grouped by month ──────────────────────────────────────────────────────

  Widget _buildGroupedList(
    BuildContext context,
    WidgetRef ref,
    List<TransactionEntity> txList,
    CustomerEntity customer,
  ) {
    // Group by year-month
    final Map<String, List<TransactionEntity>> grouped = {};
    for (final tx in txList) {
      final key = DateFormat('MMMM yyyy').format(tx.date);
      grouped.putIfAbsent(key, () => []).add(tx);
    }

    return ListView.builder(
      padding:     const EdgeInsets.only(bottom: 100),
      itemCount:   grouped.length,
      itemBuilder: (ctx, groupIdx) {
        final month = grouped.keys.elementAt(groupIdx);
        final items = grouped[month]!;

        // Monthly sub-total
        final gave = items.where((t) => t.isGave).fold(0.0, (s, t) => s + t.amount);
        final got  = items.where((t) => t.isGot ).fold(0.0, (s, t) => s + t.amount);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month header
            _MonthHeader(month: month, gave: gave, got: got),

            // Transactions
            ...items.asMap().entries.map((entry) {
              final idx = entry.key;
              final tx  = entry.value;
              return TransactionTile(
                transaction:    tx,
                animationIndex: idx,
                onEdit: () => _openEdit(context, customer, tx),
              );
            }),
          ],
        );
      },
    );
  }

  void _openEdit(
    BuildContext context,
    CustomerEntity customer,
    TransactionEntity tx,
  ) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (ctx, anim, _) => AddEditTransactionPage(
          customerId:          customer.id,
          customerName:        customer.name,
          existingTransaction: tx,
        ),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOutCubic))
              .animate(anim),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmpty(BuildContext context, CustomerEntity customer) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color:  cs.primary.withOpacity(0.08),
                shape:  BoxShape.circle,
              ),
              child: Icon(Icons.receipt_long_outlined,
                  size: 36, color: cs.primary.withOpacity(0.4)),
            ).animate().scale(curve: Curves.elasticOut),
            const SizedBox(height: 20),
            Text('No transactions yet',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w700))
                .animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 8),
            Text(
              'Tap "Add Entry" to record\nthe first transaction.',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: cs.onSurface.withOpacity(0.45),
                  height: 1.5),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 300.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text('Could not load transactions',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(msg, style: GoogleFonts.poppins(fontSize: 12), textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () {
                ref.invalidate(transactionsStreamProvider(customer.id));
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Retry',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),
      );

  Widget _buildShimmer() {
    return ListView.builder(
      itemCount: 5,
      padding: const EdgeInsets.only(top: 8),
      itemBuilder: (_, i) => Container(
        margin:  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        height:  68,
        decoration: BoxDecoration(
          color:        AppColors.shimmerBase,
          borderRadius: BorderRadius.circular(14),
        ),
      )
          .animate(onPlay: (c) => c.repeat())
          .shimmer(duration: 1200.ms, color: AppColors.shimmerHighlight),
    );
  }
}

// ── Month header with subtotals ───────────────────────────────────────────────

class _MonthHeader extends StatelessWidget {
  final String month;
  final double gave;
  final double got;

  const _MonthHeader({
    required this.month,
    required this.gave,
    required this.got,
  });

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin:  const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(
            month,
            style: GoogleFonts.poppins(
              fontSize:   12,
              fontWeight: FontWeight.w700,
              color:      cs.onSurface.withOpacity(0.6),
            ),
          ),
          const Spacer(),
          if (gave > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color:        AppColors.successLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '+₹${_fmt(gave)}',
                style: GoogleFonts.poppins(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: AppColors.success),
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (got > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color:        AppColors.dangerLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '-₹${_fmt(got)}',
                style: GoogleFonts.poppins(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: AppColors.danger),
              ),
            ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    return AppFormatters.currency(v);
  }
}
