import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/customer_providers.dart';
import '../../../core/services/pdf_export_service.dart';
import '../../../core/services/share_service.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../domain/entities/transaction_entity.dart';
import '../../common/widgets/common_widgets.dart';
import '../providers/reports_provider.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _exportPdf() async {
    final state     = ref.read(reportsProvider);
    final user      = ref.read(currentUserProvider);
    final customers = ref.read(customersStreamProvider).valueOrNull ?? [];
    final service   = ref.read(pdfExportServiceProvider);
    if (user == null) return;

    final snack = ScaffoldMessenger.of(context);
    snack.showSnackBar(const SnackBar(
        content: Text('Generating PDF…'), behavior: SnackBarBehavior.floating));
    try {
      final file = await service.generateFullReport(
        customers:    customers,
        transactions: state.transactions,
        userName:     user.name,
        businessName: user.businessName ?? '',
        from:         state.dateRange.from,
        to:           state.dateRange.to,
      );
      snack.hideCurrentSnackBar();
      if (mounted) await ShareService.sharePdf(file, 'Report');
    } catch (e) {
      snack.hideCurrentSnackBar();
      snack.showSnackBar(SnackBar(
        content:         Text('Export failed: $e'),
        backgroundColor: AppColors.danger,
        behavior:        SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state  = ref.watch(reportsProvider);
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8F9FA),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            pinned: true,
            floating: true,
            backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Text('Reports',
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
            actions: [
              if (!state.isLoading)
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 22),
                  onPressed: () => ref.read(reportsProvider.notifier).refresh(),
                ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 22),
                tooltip: 'Export PDF',
                onPressed: state.isLoading ? null : _exportPdf,
              ),
              const SizedBox(width: 4),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(96),
              child: Column(children: [
                // Period chips
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: _PeriodChips(),
                ),
                // Tab bar
                TabBar(
                  controller: _tabCtrl,
                  indicatorColor: cs.primary,
                  indicatorWeight: 2.5,
                  labelColor: cs.primary,
                  unselectedLabelColor: cs.onSurface.withOpacity(0.45),
                  labelStyle: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Transactions'),
                  ],
                ),
              ]),
            ),
          ),
        ],
        body: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabCtrl,
                children: [
                  _OverviewTab(state: state),
                  _TransactionsTab(state: state),
                ],
              ),
      ),
    );
  }
}

// ── Period chips ──────────────────────────────────────────────────────────────

class _PeriodChips extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(reportsProvider).period;
    final notifier = ref.read(reportsProvider.notifier);
    final cs       = Theme.of(context).colorScheme;

    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: ReportPeriod.values.map((p) {
          final active = p == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                if (p == ReportPeriod.custom) {
                  _pickCustom(context, ref);
                } else {
                  notifier.setPeriod(p);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? cs.primary : cs.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active ? cs.primary : AppColors.border,
                  ),
                ),
                child: Text(p.label,
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: active ? Colors.white : cs.onSurface.withOpacity(0.6))),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _pickCustom(BuildContext context, WidgetRef ref) async {
    final range = await showDateRangePicker(
      context:   context,
      firstDate: DateTime(2020),
      lastDate:  DateTime.now(),
    );
    if (range != null) {
      ref.read(reportsProvider.notifier).setCustomRange(
        DateRange(range.start, range.end),
      );
    }
  }
}

// ── Overview Tab ──────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final ReportsState state;
  const _OverviewTab({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.transactions.isEmpty) return _EmptyReport();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary cards
        _SummaryCards(state: state).animate().fadeIn(delay: 50.ms),
        const SizedBox(height: 20),

        // Insights
        _InsightsRow(state: state).animate().fadeIn(delay: 100.ms),
        const SizedBox(height: 20),

        // Chart
        if (state.monthlyBreakdown.isNotEmpty) ...[
          _SectionLabel(label: 'Monthly Overview'),
          const SizedBox(height: 12),
          _BarChartCard(state: state).animate().fadeIn(delay: 140.ms),
          const SizedBox(height: 20),
        ],

        // Top customers
        _SectionLabel(label: 'Top Balances'),
        const SizedBox(height: 12),
        _TopCustomers().animate().fadeIn(delay: 180.ms),

        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Summary Cards ─────────────────────────────────────────────────────────────

class _SummaryCards extends StatelessWidget {
  final ReportsState state;
  const _SummaryCards({required this.state});

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final net    = state.netBalance;

    return Column(children: [
      // Net hero
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primary, cs.primary.withOpacity(0.72)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(
              color: cs.primary.withOpacity(0.28),
              blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Net Position', style: GoogleFonts.poppins(
                fontSize: 13, color: Colors.white70)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${state.txCount} transactions',
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.white,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(AppFormatters.rupee(net.abs()),
              style: GoogleFonts.poppins(fontSize: 34, fontWeight: FontWeight.w800,
                  color: Colors.white, height: 1)),
          const SizedBox(height: 4),
          Text(net == 0 ? 'All settled this period' :
               net > 0  ? 'Overall you will receive' : 'Overall you will pay',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
        ]),
      ),

      const SizedBox(height: 12),

      Row(children: [
        Expanded(child: _MiniCard(
          label: 'Total Gave',  amount: state.totalGave,
          color: AppColors.success, bg: AppColors.successLight,
          icon: Icons.arrow_upward_rounded,
        )),
        const SizedBox(width: 12),
        Expanded(child: _MiniCard(
          label: 'Total Got',   amount: state.totalGot,
          color: AppColors.danger,  bg: AppColors.dangerLight,
          icon: Icons.arrow_downward_rounded,
        )),
      ]),
    ]);
  }
}

class _MiniCard extends StatelessWidget {
  final String label; final double amount;
  final Color color, bg; final IconData icon;
  const _MiniCard({required this.label, required this.amount,
    required this.color, required this.bg, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs     = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 16)),
        const SizedBox(height: 10),
        Text(AppFormatters.rupee(amount), style: GoogleFonts.poppins(
            fontSize: 18, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: GoogleFonts.poppins(fontSize: 12,
            color: cs.onSurface.withOpacity(0.5))),
      ]),
    );
  }
}

// ── Insights Row ──────────────────────────────────────────────────────────────

class _InsightsRow extends StatelessWidget {
  final ReportsState state;
  const _InsightsRow({required this.state});

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final txs    = state.transactions;
    if (txs.isEmpty) return const SizedBox.shrink();

    final avgTx  = (state.totalGave + state.totalGot) / txs.length;
    final maxTx  = txs.fold(0.0, (m, t) => math.max(m, t.amount));
    final gaveCount = txs.where((t) => t.isGave).length;

    return Row(children: [
      Expanded(child: _InsightChip(
        label: 'Avg Entry',
        value: AppFormatters.rupee(avgTx),
        icon: Icons.analytics_outlined,
        color: const Color(0xFF7C3AED),
      )),
      const SizedBox(width: 10),
      Expanded(child: _InsightChip(
        label: 'Largest',
        value: AppFormatters.rupee(maxTx),
        icon: Icons.trending_up_rounded,
        color: const Color(0xFFEA580C),
      )),
      const SizedBox(width: 10),
      Expanded(child: _InsightChip(
        label: 'Gave Times',
        value: '$gaveCount',
        icon: Icons.repeat_rounded,
        color: AppColors.success,
      )),
    ]);
  }
}

class _InsightChip extends StatelessWidget {
  final String label, value; final IconData icon; final Color color;
  const _InsightChip({required this.label, required this.value,
    required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.poppins(
            fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: GoogleFonts.poppins(fontSize: 10,
            color: cs.onSurface.withOpacity(0.5)),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

// ── Bar Chart ─────────────────────────────────────────────────────────────────

class _BarChartCard extends StatelessWidget {
  final ReportsState state;
  const _BarChartCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final data   = state.monthlyBreakdown;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs     = Theme.of(context).colorScheme;
    if (data.isEmpty) return const SizedBox.shrink();

    final maxY = data.fold(0.0, (m, d) =>
        math.max(m, math.max(d.gave, d.got))) * 1.25;

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(children: [
            _LegendDot(color: AppColors.success, label: 'Gave'),
            const SizedBox(width: 14),
            _LegendDot(color: AppColors.danger,  label: 'Got'),
          ]),
        ),
        Expanded(
          child: BarChart(BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY == 0 ? 100 : maxY,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, gi, rod, ri) {
                  final d   = data[group.x];
                  final lbl = ri == 0 ? 'Gave' : 'Got';
                  final amt = ri == 0 ? d.gave : d.got;
                  return BarTooltipItem(
                    '$lbl\n${AppFormatters.rupee(amt)}',
                    GoogleFonts.poppins(fontSize: 11,
                        fontWeight: FontWeight.w600, color: Colors.white),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 22,
                getTitlesWidget: (v, _) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(data[v.toInt()].month,
                      style: GoogleFonts.poppins(fontSize: 9,
                          color: cs.onSurface.withOpacity(0.45))),
                ),
              )),
              leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 40,
                getTitlesWidget: (v, _) => Text(
                    AppFormatters.compactCurrency(v),
                    style: GoogleFonts.poppins(fontSize: 9,
                        color: cs.onSurface.withOpacity(0.4))),
              )),
              topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: isDark ? AppColors.darkBorder : AppColors.border,
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: data.asMap().entries.map((e) => BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(toY: e.value.gave, color: AppColors.success,
                    width: 9, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                BarChartRodData(toY: e.value.got,  color: AppColors.danger,
                    width: 9, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
              ],
            )).toList(),
          )),
        ),
      ]),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color; final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 5),
    Text(label, style: GoogleFonts.poppins(fontSize: 11,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        fontWeight: FontWeight.w500)),
  ]);
}

// ── Top customers ─────────────────────────────────────────────────────────────

class _TopCustomers extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs        = Theme.of(context).colorScheme;
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final customers = ref.watch(customersStreamProvider).valueOrNull ?? [];
    if (customers.isEmpty) return const SizedBox.shrink();

    final sorted = [...customers]
      ..sort((a, b) => b.absBalance.compareTo(a.absBalance));
    final top = sorted.take(5).toList();

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        children: top.asMap().entries.map((e) {
          final c   = e.value;
          final isLast = e.key == top.length - 1;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                Container(width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: (c.isCreditor ? AppColors.success : AppColors.danger)
                          .withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: Text(c.initials,
                        style: GoogleFonts.poppins(fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: c.isCreditor ? AppColors.success : AppColors.danger)))),
                const SizedBox(width: 12),
                Expanded(child: Text(c.name, style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text(
                  '${c.isCreditor ? '+' : '-'}${AppFormatters.rupee(c.absBalance)}',
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700,
                      color: c.isCreditor ? AppColors.success : AppColors.danger),
                ),
              ]),
            ),
            if (!isLast) Divider(height: 1,
                color: isDark ? AppColors.darkBorder : AppColors.border,
                indent: 64),
          ]);
        }).toList(),
      ),
    );
  }
}

// ── Transactions Tab ──────────────────────────────────────────────────────────

class _TransactionsTab extends StatelessWidget {
  final ReportsState state;
  const _TransactionsTab({required this.state});

  @override
  Widget build(BuildContext context) {
    final txs  = state.transactions;
    if (txs.isEmpty) return _EmptyReport();

    // Group by date
    final Map<String, List<TransactionEntity>> grouped = {};
    for (final tx in txs) {
      final key = DateFormat('d MMMM yyyy').format(tx.date);
      grouped.putIfAbsent(key, () => []).add(tx);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: grouped.length,
      itemBuilder: (ctx, i) {
        final date  = grouped.keys.elementAt(i);
        final items = grouped[date]!;
        final dayGave = items.where((t) => t.isGave).fold(0.0, (s, t) => s + t.amount);
        final dayGot  = items.where((t) => t.isGot ).fold(0.0, (s, t) => s + t.amount);

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Date header
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Row(children: [
              Text(date, style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (dayGave > 0) Text('+${AppFormatters.rupee(dayGave)}',
                  style: GoogleFonts.poppins(fontSize: 12,
                      fontWeight: FontWeight.w600, color: AppColors.success)),
              if (dayGot > 0) ...[
                const SizedBox(width: 8),
                Text('-${AppFormatters.rupee(dayGot)}',
                    style: GoogleFonts.poppins(fontSize: 12,
                        fontWeight: FontWeight.w600, color: AppColors.danger)),
              ],
            ]),
          ),
          ...items.map((tx) => _TxRow(tx: tx)),
        ]);
      },
    );
  }
}

class _TxRow extends StatelessWidget {
  final TransactionEntity tx;
  const _TxRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isGave = tx.isGave;
    final color  = isGave ? AppColors.success : AppColors.danger;
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: isGave ? AppColors.successLight : AppColors.dangerLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isGave ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 14, color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            tx.note?.isNotEmpty == true ? tx.note! : isGave ? 'You gave money' : 'You got money',
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
          Text(DateFormat('h:mm a').format(tx.date),
              style: GoogleFonts.poppins(fontSize: 11,
                  color: cs.onSurface.withOpacity(0.4))),
        ])),
        Text(
          '${isGave ? '+' : '-'}${AppFormatters.rupee(tx.amount)}',
          style: GoogleFonts.poppins(fontSize: 14,
              fontWeight: FontWeight.w700, color: color),
        ),
      ]),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(label,
      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700));
}

class _EmptyReport extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.bar_chart_outlined, size: 56, color: cs.onSurface.withOpacity(0.2)),
      const SizedBox(height: 16),
      Text('No transactions in this period',
          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text('Try a different date range.',
          style: GoogleFonts.poppins(fontSize: 13,
              color: cs.onSurface.withOpacity(0.45))),
    ]));
  }
}
