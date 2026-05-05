import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/customer_providers.dart';
import '../../../core/providers/transaction_providers.dart'
    show transactionsStreamProvider;
import '../../../core/router/app_router.dart';
import '../../../core/services/pdf_export_service.dart';
import '../../../core/services/share_service.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../domain/entities/customer_entity.dart';
import '../../../domain/entities/transaction_entity.dart';
import '../../transactions/pages/add_edit_transaction_page.dart';
import '../../transactions/widgets/transaction_tile.dart';

class CustomerDetailPage extends ConsumerStatefulWidget {
  final String customerId;
  final CustomerEntity? initialCustomer;

  const CustomerDetailPage({
    super.key,
    required this.customerId,
    this.initialCustomer,
  });

  @override
  ConsumerState<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends ConsumerState<CustomerDetailPage> {
  final Map<String, TransactionEntity> _optimisticTransactions = {};

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersStreamProvider);
    final sharedCustomersAsync = ref.watch(sharedCustomersStreamProvider);
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final visibleCustomers = ref.watch(visibleCustomersProvider);
    final transactionsAsync =
        ref.watch(transactionsStreamProvider(widget.customerId));
    final matchedCustomers =
        visibleCustomers.where((c) => c.id == widget.customerId).toList();
    final customer =
        (matchedCustomers.isNotEmpty ? matchedCustomers.first : null) ??
            widget.initialCustomer;
    final displayTransactions = _mergeTransactions(
      transactionsAsync.valueOrNull ?? const [],
    );
    final liveBalance = transactionsAsync.valueOrNull == null
        ? null
        : displayTransactions.fold<double>(
            0,
            (sum, tx) => sum + tx.balanceDelta,
          );
    final ledgerCustomer = customer == null || liveBalance == null
        ? customer
        : customer.copyWith(balance: liveBalance);
    final isSharedLedger =
        ledgerCustomer != null &&
        currentUserId != null &&
        ledgerCustomer.userId != currentUserId;

    if (ledgerCustomer == null) {
      if (customersAsync.hasError || sharedCustomersAsync.hasError) {
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
          _buildSliverAppBar(ctx, ledgerCustomer, isSharedLedger),
        ],
        body: _TransactionListBody(
          customer: ledgerCustomer,
          isSharedLedger: isSharedLedger,
          transactionsAsync: transactionsAsync,
          transactions: displayTransactions,
          onRetry: () => ref.invalidate(transactionsStreamProvider(ledgerCustomer.id)),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: isSharedLedger
          ? null
          : _buildAddEntryButton(context, ledgerCustomer),
    );
  }

  List<TransactionEntity> _mergeTransactions(
    List<TransactionEntity> streamTransactions,
  ) {
    if (_optimisticTransactions.isEmpty) {
      return streamTransactions;
    }

    final existingIds = streamTransactions
        .where((tx) => tx.id.isNotEmpty)
        .map((tx) => tx.id)
        .toSet();
    final merged = [...streamTransactions];

    for (final tx in _optimisticTransactions.values) {
      if (tx.id.isEmpty || !existingIds.contains(tx.id)) {
        merged.add(tx);
      }
    }

    merged.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      return b.createdAt.compareTo(a.createdAt);
    });
    return merged;
  }

  Future<void> _exportPdf(
    BuildContext context,
    CustomerEntity customer,
  ) async {
    final txs = _mergeTransactions(
      ref.read(transactionsStreamProvider(customer.id)).valueOrNull ?? const [],
    );
    final user = ref.read(currentUserProvider);
    final service = ref.read(pdfExportServiceProvider);
    final snack = ScaffoldMessenger.of(context);

    snack.showSnackBar(const SnackBar(
      content: Text('Generating PDF...'),
      behavior: SnackBarBehavior.floating,
    ));

    try {
      final file = await service.generateCustomerLedger(
        customer: customer,
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
        content: Text('Export failed: $e'),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Widget _buildSliverAppBar(
    BuildContext context,
    CustomerEntity customer,
    bool isSharedLedger,
  ) {
    final cs = Theme.of(context).colorScheme;

    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      backgroundColor: cs.surface,
      leading: IconButton(
        onPressed: () => context.pop(),
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
      ),
      actions: [
        if (!isSharedLedger) ...[
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Customer',
            onPressed: () => context.push(AppRoutes.editCustomer, extra: customer),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export PDF',
            onPressed: () => _exportPdf(context, customer),
          ),
        ],
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: _HeaderContent(
          customer: customer,
          isSharedLedger: isSharedLedger,
          onSharePdf: isSharedLedger ? null : () => _exportPdf(context, customer),
        ),
      ),
    );
  }

  Widget _buildAddEntryButton(
    BuildContext context,
    CustomerEntity customer,
  ) {
    return FloatingActionButton.extended(
      heroTag: 'add_txn_fab',
      onPressed: () => _openAddTransaction(context, customer),
      icon: const Icon(Icons.add_rounded),
      label: Text(
        'Add Entry',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _openAddTransaction(
    BuildContext context,
    CustomerEntity customer, {
    TransactionType? initialType,
  }) async {
    final savedTransaction = await Navigator.of(context).push<TransactionEntity>(
      PageRouteBuilder(
        pageBuilder: (ctx, anim, _) => AddEditTransactionPage(
          customerId: customer.id,
          customerName: customer.name,
          currentBalance: customer.balance,
          initialType: initialType,
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

    if (savedTransaction != null && mounted) {
      // Add to optimistic map for instant UI feedback
      setState(() {
        _optimisticTransactions[savedTransaction.id] = savedTransaction;
      });
      // Firestore snapshots() fires automatically — no invalidate needed.
      // Clear optimistic entry after stream has time to update (1.5s)
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _optimisticTransactions.remove(savedTransaction.id);
          });
        }
      });
    }
  }
}

class _HeaderContent extends StatelessWidget {
  final CustomerEntity customer;
  final bool isSharedLedger;
  final Future<void> Function()? onSharePdf;

  const _HeaderContent({
    required this.customer,
    required this.isSharedLedger,
    required this.onSharePdf,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accentColor = customer.isCreditor
        ? AppColors.success
        : customer.isDebtor
            ? AppColors.danger
            : cs.primary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 56, 20, 0),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: accentColor.withOpacity(0.4), width: 2),
              ),
              child: Center(
                child: Text(
                  customer.initials,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              customer.name,
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              customer.phone,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: cs.onSurface.withOpacity(0.45),
              ),
            ),
            if (isSharedLedger) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.primary.withOpacity(0.15)),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    'Added by ${customer.ownerName ?? 'Unknown'}',
                    style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w700, color: cs.primary),
                  ),
                  if (customer.ownerPhone != null && customer.ownerPhone!.isNotEmpty)
                    Text(
                      customer.ownerPhone!,
                      style: GoogleFonts.poppins(
                        fontSize: 11, color: cs.primary.withOpacity(0.7)),
                    ),
                  const SizedBox(height: 4),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.lock_outline_rounded, size: 10, color: cs.primary.withOpacity(0.6)),
                    const SizedBox(width: 4),
                    Text('Shared ledger · Read only',
                      style: GoogleFonts.poppins(
                        fontSize: 10, color: cs.primary.withOpacity(0.6),
                        fontWeight: FontWeight.w600)),
                  ]),
                ]),
              ),
            ],
            const SizedBox(height: 14),
            _BalancePill(
              customer: customer,
              invertPerspective: isSharedLedger,
            ),
            const SizedBox(height: 16),
            _QuickActions(
              customer: customer,
              isSharedLedger: isSharedLedger,
              onSharePdf: onSharePdf,
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _BalancePill extends StatelessWidget {
  final CustomerEntity customer;
  final bool invertPerspective;

  const _BalancePill({
    required this.customer,
    this.invertPerspective = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBalance =
        invertPerspective ? -customer.balance : customer.balance;
    Color color;
    Color bg;
    String text;
    IconData icon;

    if (effectiveBalance == 0) {
      color = Colors.grey;
      bg = Colors.grey.withOpacity(0.12);
      text = 'Settled ✓';
      icon = Icons.check_circle_outline_rounded;
    } else if (effectiveBalance > 0) {
      color = AppColors.success;
      bg = AppColors.successLight;
      text = '₹${AppFormatters.currency(effectiveBalance.abs())} to receive';
      icon = Icons.arrow_downward_rounded;
    } else {
      color = AppColors.danger;
      bg = AppColors.dangerLight;
      text = '₹${AppFormatters.currency(effectiveBalance.abs())} to pay';
      icon = Icons.arrow_upward_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final CustomerEntity customer;
  final bool isSharedLedger;
  final Future<void> Function()? onSharePdf;

  const _QuickActions({
    required this.customer,
    required this.isSharedLedger,
    required this.onSharePdf,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Btn(Icons.call_outlined, 'Call', AppColors.primary, () async {
          final uri = Uri.parse('tel:${customer.phone}');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        }),
        const SizedBox(width: 8),
        _Btn(Icons.sms_outlined, 'SMS', const Color(0xFF0097A7), () async {
          final uri = Uri.parse('sms:${customer.phone}');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        }),
        const SizedBox(width: 8),
        _Btn(Icons.notifications_outlined, 'Remind', const Color(0xFFD97706), () async {
          final bal = customer.balance;
          final amt = bal.abs().toStringAsFixed(0);
          final msg = bal > 0
              ? 'Hi ${customer.name}, friendly reminder: you owe me ₹$amt. Please clear when convenient. - Sent via LenDen'
              : 'Hi ${customer.name}, reminder: I owe you ₹$amt. Will settle soon. - Sent via LenDen';
          final encoded = Uri.encodeComponent(msg);
          final waUri  = Uri.parse('whatsapp://send?phone=91${customer.phone}&text=$encoded');
          final smsUri = Uri.parse('sms:${customer.phone}?body=$encoded');
          if (await canLaunchUrl(waUri)) {
            await launchUrl(waUri, mode: LaunchMode.externalApplication);
          } else if (await canLaunchUrl(smsUri)) {
            await launchUrl(smsUri);
          }
        }),
        const SizedBox(width: 8),
        _Btn(Icons.copy_outlined, 'Copy', Colors.grey.shade600, () {
          Clipboard.setData(ClipboardData(text: customer.phone));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Number copied!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }),
        if (!isSharedLedger && onSharePdf != null) ...[
          const SizedBox(width: 8),
          _Btn(
            Icons.picture_as_pdf_outlined,
            'PDF',
            const Color(0xFFE11D48),
            () => onSharePdf!.call(),
          ),
        ],
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _Btn(this.icon, this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionListBody extends StatelessWidget {
  final CustomerEntity customer;
  final bool isSharedLedger;
  final AsyncValue<List<TransactionEntity>> transactionsAsync;
  final List<TransactionEntity> transactions;
  final VoidCallback onRetry;

  const _TransactionListBody({
    required this.customer,
    required this.isSharedLedger,
    required this.transactionsAsync,
    required this.transactions,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isSharedLedger ? 'Shared Transaction History' : 'Transaction History',
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              Text(
                '${transactions.length} entries',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: transactionsAsync.when(
            loading: () => transactions.isNotEmpty ? _buildGroupedList(context) : _buildShimmer(),
            error: (e, _) => transactions.isNotEmpty
                ? _buildGroupedList(context)
                : _buildError(context, e.toString()),
            data: (_) {
              if (transactions.isEmpty) {
                return _buildEmpty(context);
              }
              return _buildGroupedList(context);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGroupedList(BuildContext context) {
    final grouped = <String, List<TransactionEntity>>{};
    for (final tx in transactions) {
      final key = DateFormat('MMMM yyyy').format(tx.date);
      grouped.putIfAbsent(key, () => []).add(tx);
    }

    return Column(
      children: [
        // Column headers
        _LedgerColumnHeader(),
        Expanded(child: ListView.builder(
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: grouped.length,
      itemBuilder: (ctx, groupIdx) {
        final month = grouped.keys.elementAt(groupIdx);
        final items = grouped[month]!;
        final gave =
            items.where((t) => t.isGave).fold(0.0, (sum, t) => sum + t.amount);
        final got =
            items.where((t) => t.isGot).fold(0.0, (sum, t) => sum + t.amount);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MonthHeader(month: month, gave: gave, got: got),
            ...items.asMap().entries.map((entry) {
              return TransactionTile(
                transaction: entry.value,
                animationIndex: entry.key,
                invertPerspective: isSharedLedger,
              );
            }),
          ],
        );
      },
    )),],);
  }

  Widget _buildEmpty(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 36,
                color: cs.primary.withOpacity(0.4),
              ),
            ).animate().scale(curve: Curves.elasticOut),
            const SizedBox(height: 20),
            Text(
              'No transactions yet',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 8),
            Text(
              isSharedLedger
                  ? 'No shared entries are visible for this ledger yet.'
                  : 'Tap "Add Entry" below\nto record the first transaction instantly.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: cs.onSurface.withOpacity(0.45),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 300.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(
              'Could not load transactions',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              msg,
              style: GoogleFonts.poppins(fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Retry',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      itemCount: 5,
      padding: const EdgeInsets.only(top: 8),
      itemBuilder: (_, i) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        height: 68,
        decoration: BoxDecoration(
          color: AppColors.shimmerBase,
          borderRadius: BorderRadius.circular(14),
        ),
      )
          .animate(onPlay: (c) => c.repeat())
          .shimmer(duration: 1200.ms, color: AppColors.shimmerHighlight),
    );
  }
}

class _LedgerColumnHeader extends StatelessWidget {
  const _LedgerColumnHeader();

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Row(children: [
        Expanded(flex: 4,
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text('DATE / NOTE',
                style: GoogleFonts.poppins(fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface.withOpacity(0.45),
                    letterSpacing: 0.8)),
          ),
        ),
        Container(width: 1, height: 16,
            color: isDark ? AppColors.darkBorder : AppColors.border),
        Expanded(flex: 3,
          child: Text('GAVE ↑',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success.withOpacity(0.8),
                  letterSpacing: 0.8)),
        ),
        Container(width: 1, height: 16,
            color: isDark ? AppColors.darkBorder : AppColors.border),
        Expanded(flex: 3,
          child: Text('GOT ↓',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger.withOpacity(0.8),
                  letterSpacing: 0.8)),
        ),
      ]),
    );
  }
}

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
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(
            month,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: cs.onSurface.withOpacity(0.6),
            ),
          ),
          const Spacer(),
          if (gave > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '+₹${AppFormatters.currency(gave)}',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (got > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '-₹${AppFormatters.currency(got)}',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
