import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/services/pdf_export_service.dart';
import '../../../core/services/share_service.dart';
import '../../../core/utils/app_formatters.dart';
import '../providers/cashbook_provider.dart';

class CashbookPage extends ConsumerStatefulWidget {
  const CashbookPage({super.key});

  @override
  ConsumerState<CashbookPage> createState() => _CashbookPageState();
}

class _CashbookPageState extends ConsumerState<CashbookPage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cashbookProvider);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('CashBook',
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w700)),
          Text(
            state.isToday
                ? 'Today'
                : DateFormat('d MMM yyyy').format(state.selectedDate),
            style: GoogleFonts.poppins(
                fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5)),
          ),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined, size: 20),
            onPressed: () => _pickDate(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: () => ref.read(cashbookProvider.notifier).refresh(),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
            tooltip: 'Export Cashbook',
            onPressed: () => _showExportOptions(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(children: [
        // ── Daily summary ───────────────────────────────────────────────
        _DailySummary(state: state),

        // ── Entry list ──────────────────────────────────────────────────
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : state.entries.isEmpty
                  ? _EmptyState()
                  : _EntryList(state: state),
        ),
      ]),

      // ── Quick entry FABs ─────────────────────────────────────────────
      floatingActionButton: _QuickEntryFab(
        onAdd: () => _showAddSheet(context),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: ref.read(cashbookProvider).selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      ref.read(cashbookProvider.notifier).selectDate(picked);
    }
  }

  Future<void> _showAddSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddEntrySheet(),
    );
  }

  Future<void> _showExportOptions(BuildContext context) async {
    final selectedDate = ref.read(cashbookProvider).selectedDate;
    final choice = await showModalBottomSheet<_CashbookExportChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _CashbookExportSheet(selectedDate: selectedDate),
    );
    if (!context.mounted || choice == null) return;

    if (choice == _CashbookExportChoice.day) {
      await _exportCashbook(context, selectedDate, selectedDate);
      return;
    }

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: selectedDate, end: selectedDate),
    );
    if (range != null && context.mounted) {
      await _exportCashbook(context, range.start, range.end);
    }
  }

  Future<void> _exportCashbook(
    BuildContext context,
    DateTime from,
    DateTime to,
  ) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final snack = ScaffoldMessenger.of(context);
    snack.showSnackBar(const SnackBar(
      content: Text('Generating cashbook PDF...'),
      behavior: SnackBarBehavior.floating,
    ));

    try {
      final entries = await ref
          .read(cashbookProvider.notifier)
          .getEntriesByRange(from: from, to: to);
      final service = ref.read(pdfExportServiceProvider);
      final file = await service.generateCashbookReport(
        entries: entries,
        userName: user.name,
        businessName: user.businessName ?? '',
        from: from,
        to: to,
      );
      snack.hideCurrentSnackBar();
      if (context.mounted) {
        await ShareService.sharePdf(file, 'Cashbook');
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
}

enum _CashbookExportChoice { day, range }

class _CashbookExportSheet extends StatelessWidget {
  final DateTime selectedDate;
  const _CashbookExportSheet({required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBorder : AppColors.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Text('Export Cashbook',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(DateFormat('d MMM yyyy').format(selectedDate),
                style: GoogleFonts.poppins(
                    fontSize: 12, color: cs.onSurface.withValues(alpha: 0.48))),
          ]),
          const SizedBox(height: 14),
          _ExportOption(
            icon: Icons.today_rounded,
            title: 'Selected Day',
            subtitle: 'PDF for the cashbook day currently open.',
            onTap: () => Navigator.pop(context, _CashbookExportChoice.day),
          ),
          const SizedBox(height: 10),
          _ExportOption(
            icon: Icons.date_range_rounded,
            title: 'Date Range',
            subtitle: 'Choose start and end dates for a PDF report.',
            onTap: () => Navigator.pop(context, _CashbookExportChoice.range),
          ),
        ]),
      ),
    );
  }
}

class _ExportOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ExportOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: cs.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: cs.onSurface.withValues(alpha: 0.48))),
            ]),
          ),
          Icon(Icons.chevron_right_rounded,
              color: cs.onSurface.withValues(alpha: 0.34)),
        ]),
      ),
    );
  }
}

// ── Daily Summary ─────────────────────────────────────────────────────────────

class _DailySummary extends StatelessWidget {
  final CashbookState state;
  const _DailySummary({required this.state});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bal = state.balance;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance amount - prominent
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('बाकी रकम',
                  style: GoogleFonts.poppins(
                      fontSize: 13, 
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  AppFormatters.rupee(bal.abs()),
                  maxLines: 1,
                  style: GoogleFonts.poppins(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: bal >= 0 ? AppColors.success : AppColors.danger,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    bal >= 0 ? 'Cash in hand' : 'Cash shortage',
                    style: GoogleFonts.poppins(
                        fontSize: 12, 
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gave ↓',
                        style: GoogleFonts.poppins(
                            fontSize: 11, 
                            color: Colors.white.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        AppFormatters.rupee(state.totalOut),
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Received ↑',
                        style: GoogleFonts.poppins(
                            fontSize: 11, 
                            color: Colors.white.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        AppFormatters.rupee(state.totalIn),
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Entry List ────────────────────────────────────────────────────────────────

class _EntryList extends ConsumerWidget {
  final CashbookState state;
  const _EntryList({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(children: [
      // Column headers with better styling
      Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border, width: 0.8),
        ),
        child: Row(children: [
          Expanded(
              flex: 4,
              child: Text('DETAILS',
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface.withValues(alpha: 0.5),
                      letterSpacing: 0.5))),
          const SizedBox(width: 1),
          Expanded(
              flex: 3,
              child: Text('RECEIVED',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success.withValues(alpha: 0.75),
                      letterSpacing: 0.5))),
          const SizedBox(width: 1),
          Expanded(
              flex: 3,
              child: Text('GAVE',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger.withValues(alpha: 0.75),
                      letterSpacing: 0.5))),
        ]),
      ),

      // Entries with improved design
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: state.entries.length,
          itemBuilder: (ctx, i) {
            final e = state.entries[i];
            return _EntryRow(entry: e, index: i);
          },
        ),
      ),
    ]);
  }
}

class _EntryRow extends StatelessWidget {
  final CashEntry entry;
  final int index;
  const _EntryRow({required this.entry, required this.index});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fmt = NumberFormat('#,##,###').format(entry.amount.toInt());
    final time = DateFormat('h:mm a').format(entry.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border, 
            width: 0.8),
        boxShadow: [
          BoxShadow(
            color: isDark 
              ? Colors.black.withValues(alpha: 0.1) 
              : Colors.grey.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(children: [
          // Time + note with better spacing
          Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(time,
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface.withValues(alpha: 0.7))),
                    if (entry.note?.isNotEmpty == true) ...[
                      const SizedBox(height: 3),
                      Text(entry.note!,
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: 0.5),
                              fontWeight: FontWeight.w400),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              )),
          // Divider
          VerticalDivider(
              width: 1,
              thickness: 0.8,
              color: isDark ? AppColors.darkBorder : AppColors.border),
          // Cash In
          Expanded(
              flex: 3,
              child: Center(
                child: entry.isCashIn
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('₹$fmt',
                              maxLines: 1,
                              style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.success),
                              textAlign: TextAlign.center),
                        ),
                      )
                    : Text('—',
                        style: GoogleFonts.poppins(
                            fontSize: 13, 
                            color: cs.onSurface.withValues(alpha: 0.15),
                            fontWeight: FontWeight.w400),
                        textAlign: TextAlign.center),
              )),
          // Divider
          VerticalDivider(
              width: 1,
              thickness: 0.8,
              color: isDark ? AppColors.darkBorder : AppColors.border),
          // Cash Out
          Expanded(
              flex: 3,
              child: Center(
                child: !entry.isCashIn
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('₹$fmt',
                              maxLines: 1,
                              style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.danger),
                              textAlign: TextAlign.center),
                        ),
                      )
                    : Text('—',
                        style: GoogleFonts.poppins(
                            fontSize: 13, 
                            color: cs.onSurface.withValues(alpha: 0.15),
                            fontWeight: FontWeight.w400),
                        textAlign: TextAlign.center),
              )),
        ]),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 25))
        .fadeIn(duration: 250.ms);
  }
}

// ── Quick Entry FAB ───────────────────────────────────────────────────────────

class _QuickEntryFab extends StatefulWidget {
  final VoidCallback onAdd;
  const _QuickEntryFab({required this.onAdd});

  @override
  State<_QuickEntryFab> createState() => _QuickEntryFabState();
}

class _QuickEntryFabState extends State<_QuickEntryFab> {
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'cashbook_fab',
      onPressed: widget.onAdd,
      icon: const Icon(Icons.add_rounded, size: 20),
      label: Text('Add Entry',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, 
              fontSize: 14)),
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Colors.white,
      elevation: 6,
    );
  }
}

// ── Add Entry Bottom Sheet ────────────────────────────────────────────────────

class _AddEntrySheet extends ConsumerStatefulWidget {
  const _AddEntrySheet();

  @override
  ConsumerState<_AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends ConsumerState<_AddEntrySheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  late CashType _type;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _type = CashType.cashIn;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '').trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter a valid amount.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (amount > 10000000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Maximum amount is ₹1 Crore.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _loading = true);
    final ok = await ref.read(cashbookProvider.notifier).addEntry(
          type: _type,
          amount: amount,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        );
    setState(() => _loading = false);
    if (ok && mounted) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop();
      // Show success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_type == CashType.cashIn ? "Cash In" : "Cash Out"} recorded successfully'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (mounted) {
      final error = ref.read(cashbookProvider).error ?? 'Could not save entry. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCashIn = _type == CashType.cashIn;
    final accent = isCashIn ? AppColors.success : AppColors.danger;
    final label = isCashIn ? 'Cash In' : 'Cash Out';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Handle
            Center(
                child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBorder : AppColors.border,
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 18),
            
            // Title
            Text('Add Entry',
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),

            // Type toggle with better design
            Container(
              height: 70,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                  width: 0.8,
                ),
              ),
              child: Row(children: [
                Expanded(
                    child: GestureDetector(
                  onTap: () => setState(() => _type = CashType.cashIn),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: _type == CashType.cashIn
                          ? AppColors.success
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.call_received_rounded,
                              size: 20,
                              color: _type == CashType.cashIn
                                  ? Colors.white
                                  : AppColors.success.withValues(alpha: 0.6)),
                          const SizedBox(height: 3),
                          Text('Received',
                              style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _type == CashType.cashIn
                                      ? Colors.white
                                      : AppColors.success.withValues(alpha: 0.6))),
                        ]),
                  ),
                )),
                Expanded(
                    child: GestureDetector(
                  onTap: () => setState(() => _type = CashType.cashOut),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: _type == CashType.cashOut
                          ? AppColors.danger
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.call_made_rounded,
                              size: 20,
                              color: _type == CashType.cashOut
                                  ? Colors.white
                                  : AppColors.danger.withValues(alpha: 0.6)),
                          const SizedBox(height: 3),
                          Text('Gave',
                              style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _type == CashType.cashOut
                                      ? Colors.white
                                      : AppColors.danger.withValues(alpha: 0.6))),
                        ]),
                  ),
                )),
              ]),
            ),

            const SizedBox(height: 20),

            // Amount with better styling
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: accent.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Row(children: [
                Text('₹',
                    style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: accent)),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                  controller: _amountCtrl,
                  autofocus: true,
                  maxLines: 1,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.poppins(
                      fontSize: 28, fontWeight: FontWeight.w700, color: accent),
                  inputFormatters: [
                    _AmountInputFormatter(),
                  ],
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: accent.withValues(alpha: 0.15)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onSubmitted: (_) => _save(),
                )),
              ]),
            ),

            const SizedBox(height: 14),

            // Note with better styling
            TextField(
              controller: _noteCtrl,
              maxLength: 80,
              style: GoogleFonts.poppins(fontSize: 15),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Note (optional)',
                hintStyle: GoogleFonts.poppins(
                    fontSize: 14, 
                    color: cs.onSurface.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w400),
                filled: true,
                fillColor: isDark
                    ? AppColors.darkSurfaceVariant
                    : AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                    width: 0.8,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: accent,
                    width: 1.5,
                  ),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),

            const SizedBox(height: 24),

            // Save button with better styling
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _save,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.2, color: Colors.white))
                    : Icon(
                        isCashIn
                            ? Icons.call_received_rounded
                            : Icons.call_made_rounded,
                        size: 20),
                label: Text(_loading ? 'Saving...' : 'Record $label',
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                disabledBackgroundColor: accent.withValues(alpha: 0.4),
              ),
            ),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}

class _AmountInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty || RegExp(r'^\d{0,8}(\.\d{0,2})?$').hasMatch(text)) {
      return newValue;
    }
    return oldValue;
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.account_balance_wallet_outlined,
            size: 64, color: cs.onSurface.withValues(alpha: 0.15)),
        const SizedBox(height: 20),
        Text('No entries today',
            style: GoogleFonts.poppins(
                fontSize: 18, 
                fontWeight: FontWeight.w700,
                color: cs.onSurface.withValues(alpha: 0.8))),
        const SizedBox(height: 10),
        Text('Tap the Add Entry button to get started',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 14, 
                color: cs.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w400)),
      ]),
    );
  }
}
