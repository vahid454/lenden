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

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportsProvider);
    final cs    = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Reports',
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
        actions: [
          if (!state.isLoading)
            IconButton(
              icon:    const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: () =>
                  ref.read(reportsProvider.notifier).refresh(),
            ),
          IconButton(
            icon:    const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export PDF',
            onPressed: state.isLoading
                ? null
                : () => _exportPdf(context, ref, state),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(reportsProvider.notifier).refresh(),
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // ── Period filter chips ──────────────────────────
                          _PeriodFilterBar().animate().fadeIn(),
                          const SizedBox(height: 16),

                          // ── Error ────────────────────────────────────────
                          if (state.errorMessage != null)
                            ErrorDisplay(message: state.errorMessage!)
                                .animate().fadeIn().shakeX(amount: 4),

                          // ── Summary cards ────────────────────────────────
                          _SummaryCards(state: state)
                              .animate().fadeIn(delay: 80.ms),
                          const SizedBox(height: 20),

                          // ── Bar chart ────────────────────────────────────
                          if (state.transactions.isNotEmpty) ...[
                            _SectionLabel(label: 'Monthly Overview'),
                            const SizedBox(height: 10),
                            _BarChart(state: state)
                                .animate().fadeIn(delay: 120.ms),
                            const SizedBox(height: 20),
                          ],

                          // ── Daily line chart ─────────────────────────────
                          if (state.dailyBreakdown.length > 1) ...[
                            _SectionLabel(label: 'Daily Activity'),
                            const SizedBox(height: 10),
                            _LineChart(state: state)
                                .animate().fadeIn(delay: 160.ms),
                            const SizedBox(height: 20),
                          ],

                          // ── Recent transactions list ──────────────────────
                          _SectionLabel(label: 'Transactions (${state.txCount})'),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),

                  // ── Transaction list ─────────────────────────────────────
                  if (state.transactions.isEmpty)
                    SliverToBoxAdapter(
                        child: _EmptyState())
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final tx = state.transactions[i];
                          return _ReportTxTile(tx: tx, index: i);
                        },
                        childCount: state.transactions.length,
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
      ),
    );
  }

  Future<void> _exportPdf(
      BuildContext context, WidgetRef ref, ReportsState state) async {
    final user      = ref.read(currentUserProvider);
    final customers = ref.read(customersStreamProvider).valueOrNull ?? [];
    final service   = ref.read(pdfExportServiceProvider);

    if (user == null) return;

    final snack = ScaffoldMessenger.of(context);
    snack.showSnackBar(const SnackBar(
        content: Text('Generating PDF…'),
        behavior: SnackBarBehavior.floating));

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
      if (context.mounted) {
        await ShareService.sharePdf(file, 'Full Report');
      }
    } catch (e) {
      snack.hideCurrentSnackBar();
      snack.showSnackBar(SnackBar(
          content: Text('PDF export failed: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating));
    }
  }
}

// ── Period filter chips ───────────────────────────────────────────────────────

class _PeriodFilterBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(reportsProvider).period;
    final notifier = ref.read(reportsProvider.notifier);
    final cs       = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ReportPeriod.values.map((p) {
          final isSelected = p == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                if (p == ReportPeriod.custom) {
                  _showCustomDatePicker(context, ref);
                } else {
                  notifier.setPeriod(p);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color:        isSelected ? cs.primary : cs.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? cs.primary : AppColors.border,
                    width: isSelected ? 0 : 1,
                  ),
                ),
                child: Text(
                  p.label,
                  style: GoogleFonts.poppins(
                    fontSize:   12,
                    fontWeight: FontWeight.w600,
                    color:      isSelected ? Colors.white : cs.onSurface.withOpacity(0.65),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _showCustomDatePicker(BuildContext context, WidgetRef ref) async {
    final range = await showDateRangePicker(
      context:   context,
      firstDate: DateTime(2020),
      lastDate:  DateTime.now(),
      builder:   (ctx, child) => Theme(
        data: Theme.of(ctx),
        child: child!,
      ),
    );
    if (range != null) {
      ref.read(reportsProvider.notifier).setCustomRange(
        DateRange(range.start, range.end),
      );
    }
  }
}

// ── Summary cards ─────────────────────────────────────────────────────────────

class _SummaryCards extends StatelessWidget {
  final ReportsState state;
  const _SummaryCards({required this.state});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs     = Theme.of(context).colorScheme;
    final net    = state.netBalance;

    return Column(
      children: [
        // Net balance hero
        Container(
          width:   double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cs.primary, cs.primary.withOpacity(0.7)],
              begin:  Alignment.topLeft,
              end:    Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Net Position',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
              const SizedBox(height: 4),
              Text(
                AppFormatters.rupee(net.abs()),
                style: GoogleFonts.poppins(
                    fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              Text(
                net == 0
                    ? 'All settled for this period'
                    : net > 0
                        ? 'Overall you will receive'
                        : 'Overall you owe',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Text('${state.txCount} transactions',
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.white60)),
            ],
          ),
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _MiniCard(
                label:  'Total Gave',
                amount: state.totalGave,
                color:  AppColors.success,
                bg:     AppColors.successLight,
                icon:   Icons.arrow_upward_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniCard(
                label:  'Total Got',
                amount: state.totalGot,
                color:  AppColors.danger,
                bg:     AppColors.dangerLight,
                icon:   Icons.arrow_downward_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  final String label; final double amount;
  final Color color; final Color bg; final IconData icon;
  const _MiniCard({required this.label, required this.amount,
    required this.color, required this.bg, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:    const EdgeInsets.all(6),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          Text(AppFormatters.rupee(amount),
              style: GoogleFonts.poppins(
                  fontSize: 17, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: GoogleFonts.poppins(
              fontSize: 11, color: cs.onSurface.withOpacity(0.5))),
        ],
      ),
    );
  }
}

// ── Bar chart ─────────────────────────────────────────────────────────────────

class _BarChart extends StatelessWidget {
  final ReportsState state;
  const _BarChart({required this.state});

  @override
  Widget build(BuildContext context) {
    final data = state.monthlyBreakdown;
    if (data.isEmpty) return const SizedBox.shrink();

    final maxY = data.fold(0.0, (m, d) => [m, d.gave, d.got].reduce((a, b) => a > b ? a : b));

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: BarChart(
        BarChartData(
          alignment:     BarChartAlignment.spaceAround,
          maxY:          maxY * 1.2,
          barTouchData:  BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final d     = data[group.x];
                final label = rodIndex == 0 ? 'Gave' : 'Got';
                final amt   = rodIndex == 0 ? d.gave : d.got;
                return BarTooltipItem(
                  '$label\n${AppFormatters.rupee(amt)}',
                  GoogleFonts.poppins(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: Colors.white),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, meta) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    data[v.toInt()].month,
                    style: GoogleFonts.poppins(
                        fontSize: 9,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                  ),
                ),
                reservedSize: 24,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (v, meta) => Text(
                  AppFormatters.compactCurrency(v),
                  style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                ),
              ),
            ),
            topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkBorder : AppColors.border,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: data.asMap().entries.map((e) {
            final i = e.key;
            final d = e.value;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: d.gave,
                  color: AppColors.success,
                  width: 8,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
                BarChartRodData(
                  toY: d.got,
                  color: AppColors.danger,
                  width: 8,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Line chart ────────────────────────────────────────────────────────────────

class _LineChart extends StatelessWidget {
  final ReportsState state;
  const _LineChart({required this.state});

  @override
  Widget build(BuildContext context) {
    final data = state.dailyBreakdown;
    if (data.length < 2) return const SizedBox.shrink();

    final maxY = data.fold(0.0, (m, d) =>
        [m, d.gave, d.got].reduce((a, b) => a > b ? a : b));

    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: LineChart(
        LineChartData(
          minX: 0, maxX: (data.length - 1).toDouble(),
          minY: 0, maxY: maxY * 1.2,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (data.length / 4).ceil().toDouble(),
                getTitlesWidget: (v, m) {
                  final i = v.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(data[i].label,
                        style: GoogleFonts.poppins(fontSize: 8,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4))),
                  );
                },
                reservedSize: 22,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (v, m) => Text(
                  AppFormatters.compactCurrency(v),
                  style: GoogleFonts.poppins(fontSize: 8,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                ),
              ),
            ),
            topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkBorder : AppColors.border,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: data.asMap().entries
                  .map((e) => FlSpot(e.key.toDouble(), e.value.gave))
                  .toList(),
              isCurved: true,
              color:    AppColors.success,
              barWidth: 2.5,
              dotData:  const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.success.withOpacity(0.08),
              ),
            ),
            LineChartBarData(
              spots: data.asMap().entries
                  .map((e) => FlSpot(e.key.toDouble(), e.value.got))
                  .toList(),
              isCurved: true,
              color:    AppColors.danger,
              barWidth: 2.5,
              dotData:  const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.danger.withOpacity(0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Report transaction tile ───────────────────────────────────────────────────

class _ReportTxTile extends StatelessWidget {
  final TransactionEntity tx;
  final int               index;
  const _ReportTxTile({required this.tx, required this.index});

  @override
  Widget build(BuildContext context) {
    final isGave = tx.isGave;
    final color  = isGave ? AppColors.success : AppColors.danger;
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin:     const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      padding:    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding:    const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isGave ? AppColors.successLight : AppColors.dangerLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isGave ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              color: color, size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.note?.isNotEmpty == true ? tx.note! : isGave ? 'You gave money' : 'You got money',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(AppFormatters.relativeDate(tx.date),
                    style: GoogleFonts.poppins(fontSize: 11, color: cs.onSurface.withOpacity(0.45))),
              ],
            ),
          ),
          Text(
            '${isGave ? '+' : '-'}${AppFormatters.rupee(tx.amount)}',
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: index * 30))
        .fadeIn(duration: 250.ms)
        .slideX(begin: 0.04, end: 0);
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.bar_chart_outlined, size: 56, color: cs.onSurface.withOpacity(0.2)),
            const SizedBox(height: 14),
            Text('No transactions in this period',
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('Try selecting a different date range.',
                style: GoogleFonts.poppins(fontSize: 13, color: cs.onSurface.withOpacity(0.45))),
          ],
        ),
      ),
    );
  }
}
