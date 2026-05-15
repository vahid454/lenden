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
import '../providers/reports_provider.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state  = ref.watch(reportsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF4F7FC),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text('Reports',
            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800)),
        actions: [ 
          if (!state.isLoading)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 22),
              onPressed: () => ref.read(reportsProvider.notifier).refresh(),
            ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 22),
            tooltip: 'Export PDF',
            onPressed: state.isLoading ? null : () => _exportPdf(context, ref, state),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: _PeriodChips(),
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.transactions.isEmpty
              ? _EmptyState()
              : _ReportBody(state: state),
    );
  }

  Future<void> _exportPdf(BuildContext ctx, WidgetRef ref, ReportsState state) async {
    final user      = ref.read(currentUserProvider);
    final customers = ref.read(customersStreamProvider).valueOrNull ?? [];
    final service   = ref.read(pdfExportServiceProvider);
    if (user == null) return;

    final snack = ScaffoldMessenger.of(ctx);
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
      if (ctx.mounted) await ShareService.sharePdf(file, 'Report');
    } catch (e) {
      snack.hideCurrentSnackBar();
      snack.showSnackBar(SnackBar(
        content:         Text('Export failed: $e'),
        backgroundColor: AppColors.danger,
        behavior:        SnackBarBehavior.floating,
      ));
    }
  }
}

// ── Period Chips ──────────────────────────────────────────────────────────────

class _PeriodChips extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(reportsProvider).period;
    final notifier = ref.read(reportsProvider.notifier);
    final cs       = Theme.of(context).colorScheme;

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        children: ReportPeriod.values.map((p) {
          final active = p == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => p == ReportPeriod.custom
                  ? _pickCustom(context, ref)
                  : notifier.setPeriod(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color:        active ? cs.primary : cs.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: active ? cs.primary : AppColors.border),
                ),
                child: Text(p.label,
                    style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: active ? Colors.white
                            : cs.onSurface.withValues(alpha: 0.6))),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _pickCustom(BuildContext ctx, WidgetRef ref) async {
    final range = await showDateRangePicker(
        context: ctx, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (range != null) {
      ref.read(reportsProvider.notifier)
          .setCustomRange(DateRange(range.start, range.end));
    }
  }
}

// ── Report Body ───────────────────────────────────────────────────────────────

class _ReportBody extends StatelessWidget {
  final ReportsState state;
  const _ReportBody({required this.state});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Summary hero
        _SummaryHero(state: state).animate().fadeIn(delay: 40.ms),
        const SizedBox(height: 12),

        // 2. Gave / Got cards
        _GaveGotRow(state: state).animate().fadeIn(delay: 80.ms),
        const SizedBox(height: 20),

        // 3. Bar chart (only if >1 month of data)
        if (state.monthlyBreakdown.length > 1) ...[
          const _Label('Monthly Breakdown'),
          const SizedBox(height: 10),
          _BarChartCard(state: state).animate().fadeIn(delay: 120.ms),
          const SizedBox(height: 20),
        ],

        // 4. Transaction list grouped by date
        const _Label('All Transactions'),
        const SizedBox(height: 10),
        _GroupedTxList(state: state).animate().fadeIn(delay: 160.ms),

        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Summary Hero ──────────────────────────────────────────────────────────────

class _SummaryHero extends StatelessWidget {
  final ReportsState state;
  const _SummaryHero({required this.state});

  @override
  Widget build(BuildContext context) {
    final cs  = Theme.of(context).colorScheme;
    final net = state.netBalance;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(0, 12),
          )
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text('Summary',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ),
          const Spacer(),
          Icon(Icons.insights_rounded, color: Colors.white.withValues(alpha: 0.85)),
        ]),
        const SizedBox(height: 18),
        Text(AppFormatters.rupee(net.abs()),
            style: GoogleFonts.poppins(
                fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 6),
        Text(
          net == 0 ? 'All settled' : net > 0 ? 'Overall to receive' : 'Overall to pay',
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.white.withValues(alpha: 0.8)),
        ),
        const SizedBox(height: 18),
        Row(children: [
          _MiniStat(label: 'Entries', value: '${state.txCount}', color: Colors.white70),
          const SizedBox(width: 10),
          _MiniStat(
              label: 'Period',
              value: state.dateRange.from.year == state.dateRange.to.year &&
                      state.dateRange.from.month == state.dateRange.to.month
                  ? DateFormat('MMM yyyy').format(state.dateRange.from)
                  : '${DateFormat('d MMM').format(state.dateRange.from)} - ${DateFormat('d MMM').format(state.dateRange.to)}',
              color: Colors.white70),
        ])
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color)),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
      ]),
    );
  }
}

// ── Gave / Got row ────────────────────────────────────────────────────────────

class _GaveGotRow extends StatelessWidget {
  final ReportsState state;
  const _GaveGotRow({required this.state});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(children: [
      Expanded(child: _StatCard(
        label:   'Total Gave',
        amount:  state.totalGave,
        color:   AppColors.success,
        bg:      AppColors.successLight,
        icon:    Icons.arrow_upward_rounded,
        isDark:  isDark,
      )),
      const SizedBox(width: 12),
      Expanded(child: _StatCard(
        label:   'Total Got',
        amount:  state.totalGot,
        color:   AppColors.danger,
        bg:      AppColors.dangerLight,
        icon:    Icons.arrow_downward_rounded,
        isDark:  isDark,
      )),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final String label; final double amount;
  final Color color, bg; final IconData icon; final bool isDark;
  const _StatCard({required this.label, required this.amount,
    required this.color, required this.bg, required this.icon, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(
          color: bg.withValues(alpha: 0.14),
          blurRadius: 22,
          offset: const Offset(0, 10),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 16),
          ),
          const Spacer(),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54)),
        ]),
        const SizedBox(height: 16),
        Text(AppFormatters.rupee(amount),
            style: GoogleFonts.poppins(
                fontSize: 24, fontWeight: FontWeight.w800, color: color)),
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
    if (data.isEmpty) return const SizedBox.shrink();
    final cs     = Theme.of(context).colorScheme;
    final maxY   = data.fold(0.0, (m, d) => math.max(m, math.max(d.gave, d.got))) * 1.3;

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(
          color: cs.onSurface.withValues(alpha: 0.06),
          blurRadius: 30,
          offset: const Offset(0, 12),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _Dot(AppColors.success, 'Gave'),
          const SizedBox(width: 12),
          _Dot(AppColors.danger, 'Got'),
          const Spacer(),
          Text('Monthly trend', style: GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface.withValues(alpha: 0.8))),
        ]),
        const SizedBox(height: 14),
        Expanded(child: BarChart(BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY == 0 ? 100 : maxY,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, ri) {
                final item = data[group.x];
                final value = ri == 0 ? item.gave : item.got;
                return BarTooltipItem(
                  '${ri == 0 ? 'Gave' : 'Got'}\n${AppFormatters.rupee(value)}',
                  GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, _) {
                final index = value.toInt();
                final label = index < data.length ? data[index].month : '';
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(label,
                      style: GoogleFonts.poppins(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.65))),
                );
              },
            )),
            leftTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, _) => Text(
                  AppFormatters.compactCurrency(value),
                  style: GoogleFonts.poppins(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.5))),
            )),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: cs.onSurface.withValues(alpha: 0.08),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: data.asMap().entries.map((entry) {
            final value = entry.value;
            return BarChartGroupData(
              x: entry.key,
              barsSpace: 6,
              barRods: [
                BarChartRodData(
                    toY: value.gave,
                    color: AppColors.success,
                    width: 10,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6))),
                BarChartRodData(
                    toY: value.got,
                    color: AppColors.danger,
                    width: 10,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6))),
              ],
            );
          }).toList(),
        ))),
      ]),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color; final String label;
  const _Dot(this.color, this.label);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10,
        decoration: BoxDecoration(color: color,
            borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 5),
    Text(label, style: GoogleFonts.poppins(fontSize: 11,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        fontWeight: FontWeight.w500)),
  ]);
}

// ── Grouped Transaction List ──────────────────────────────────────────────────

class _GroupedTxList extends StatelessWidget {
  final ReportsState state;
  const _GroupedTxList({required this.state});

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Group by date
    final Map<String, List<TransactionEntity>> grouped = {};
    for (final tx in state.transactions) {
      final key = DateFormat('d MMM yyyy').format(tx.date);
      grouped.putIfAbsent(key, () => []).add(tx);
    }

    return Column(children: [
      // Column header with enhanced styling
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant.withValues(alpha: 0.6)
            : AppColors.surfaceVariant.withValues(alpha: 0.8),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Row(children: [
          Expanded(flex: 4, child: Text('DATE / NOTE',
              style: GoogleFonts.poppins(fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface.withValues(alpha: 0.5),
                  letterSpacing: 0.8))),
          Expanded(flex: 3, child: Text('GAVE',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success.withValues(alpha: 0.85),
                  letterSpacing: 0.8))),
          Expanded(flex: 3, child: Text('GOT',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger.withValues(alpha: 0.85),
                  letterSpacing: 0.8))),
        ]),
      ),

      // Container wrapper with shadow
      Container(
        margin: const EdgeInsets.only(top: 0),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: cs.onSurface.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Column(children: [
          // Rows grouped by date
          ...grouped.entries.expand((entry) {
            final date  = entry.key;
            final items = entry.value;
            final dayGave = items.where((t) => t.isGave).fold(0.0, (s, t) => s + t.amount);
            final dayGot  = items.where((t) => t.isGot ).fold(0.0, (s, t) => s + t.amount);

            return [
              // Date subheader with improved visual hierarchy
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface.withValues(alpha: 0.4)
                      : AppColors.surfaceVariant.withValues(alpha: 0.4),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceVariant.withValues(alpha: 0.6)
                          : AppColors.surfaceVariant.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(date, style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: cs.onSurface.withValues(alpha: 0.7))),
                  ),
                  const Spacer(),
                  if (dayGave > 0)
                    Row(children: [
                      Icon(Icons.arrow_upward_rounded, size: 12,
                          color: AppColors.success.withValues(alpha: 0.8)),
                      const SizedBox(width: 4),
                      Text('+${AppFormatters.rupee(dayGave)}',
                          style: GoogleFonts.poppins(fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success)),
                    ]),
                  if (dayGave > 0 && dayGot > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('·',
                          style: GoogleFonts.poppins(fontSize: 14,
                              color: cs.onSurface.withValues(alpha: 0.2))),
                    ),
                  if (dayGot > 0)
                    Row(children: [
                      Icon(Icons.arrow_downward_rounded, size: 12,
                          color: AppColors.danger.withValues(alpha: 0.8)),
                      const SizedBox(width: 4),
                      Text('-${AppFormatters.rupee(dayGot)}',
                          style: GoogleFonts.poppins(fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.danger)),
                    ]),
                ]),
              ),
              // Transaction rows for this date with staggered animation
              ...items.asMap().entries.map((entry) {
                final idx = entry.key;
                final tx = entry.value;
                return _TxRow(
                  tx: tx,
                  isDark: isDark,
                  cs: cs,
                  index: idx,
                );
              }),
            ];
          }).toList(),
        ]),
      ),
    ]);
  }
}

class _TxRow extends StatefulWidget {
  final TransactionEntity tx;
  final bool isDark;
  final ColorScheme cs;
  final int index;
  const _TxRow({required this.tx, required this.isDark, required this.cs, required this.index});

  @override
  State<_TxRow> createState() => _TxRowState();
}

class _TxRowState extends State<_TxRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isGave = widget.tx.isGave;
    final fmt    = AppFormatters.compactCurrency(widget.tx.amount);
    final color  = isGave ? AppColors.success : AppColors.danger;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) => setState(() => _isHovered = false),
      onTapCancel: () => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: _isHovered
              ? color.withValues(alpha: 0.08)
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: widget.isDark
                  ? AppColors.darkBorder.withValues(alpha: 0.5)
                  : AppColors.border.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(children: [
            // Date + note with icon indicator
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isGave
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 12,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(DateFormat('h:mm a').format(widget.tx.date),
                          style: GoogleFonts.poppins(fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: widget.cs.onSurface.withValues(alpha: 0.6))),
                    ]),
                    if (widget.tx.note?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(widget.tx.note!, style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w500),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
            ),
            VerticalDivider(width: 1,
                color: widget.isDark
                    ? AppColors.darkBorder.withValues(alpha: 0.4)
                    : AppColors.border.withValues(alpha: 0.4)),
            // Gave
            Expanded(flex: 3, child: Center(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: isGave
                  ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('₹$fmt', textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success)),
                      ),
                    ],
                  )
                  : Text('—', textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 13,
                          color: widget.cs.onSurface.withValues(alpha: 0.15))),
            ))),
            VerticalDivider(width: 1,
                color: widget.isDark
                    ? AppColors.darkBorder.withValues(alpha: 0.4)
                    : AppColors.border.withValues(alpha: 0.4)),
            // Got
            Expanded(flex: 3, child: Center(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: !isGave
                  ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('₹$fmt', textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.danger)),
                      ),
                    ],
                  )
                  : Text('—', textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 13,
                          color: widget.cs.onSurface.withValues(alpha: 0.15))),
            ))),
          ]),
        ),
      )
      .animate()
      .fadeIn(delay: (160 + (widget.index * 30)).ms, duration: 300.ms)
      .slideX(begin: -0.1, end: 0, delay: (160 + (widget.index * 30)).ms, duration: 300.ms),
    );
  }
}

class _Label extends StatelessWidget {
  final String label;
  const _Label(this.label);
  @override
  Widget build(BuildContext context) => Text(label,
      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700));
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.bar_chart_outlined, size: 56,
            color: cs.onSurface.withValues(alpha: 0.18)),
        const SizedBox(height: 16),
        Text('No transactions in this period',
            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('Try a different date range.',
            style: GoogleFonts.poppins(fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.45))),
      ],
    ));
  }
}
