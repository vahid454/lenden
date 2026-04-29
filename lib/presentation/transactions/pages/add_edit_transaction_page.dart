import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../domain/entities/transaction_entity.dart';
import '../../common/widgets/common_widgets.dart';
import '../providers/transaction_form_provider.dart';

/// Add or edit a transaction for a given customer.
/// Slide-up modal sheet style.
class AddEditTransactionPage extends ConsumerStatefulWidget {
  final String              customerId;
  final String              customerName;
  final double              currentBalance;
  final TransactionType?    initialType;
  final TransactionEntity?  existingTransaction; // non-null = edit mode

  const AddEditTransactionPage({
    super.key,
    required this.customerId,
    required this.customerName,
    this.currentBalance = 0,
    this.initialType,
    this.existingTransaction,
  });

  bool get isEditing => existingTransaction != null;

  @override
  ConsumerState<AddEditTransactionPage> createState() =>
      _AddEditTransactionPageState();
}

class _AddEditTransactionPageState
    extends ConsumerState<AddEditTransactionPage> {
  final _formKey    = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl   = TextEditingController();

  late TransactionType _type;
  late DateTime        _selectedDate;

  @override
  void initState() {
    super.initState();
    final e = widget.existingTransaction;
    _type         = e?.type ?? widget.initialType ?? TransactionType.gave;
    _selectedDate = e?.date ?? DateTime.now();
    _amountCtrl.text =
        e != null ? (e.amount % 1 == 0 ? e.amount.toInt().toString() : e.amount.toStringAsFixed(2)) : '';
    _noteCtrl.text = e?.note ?? '';
    _amountCtrl.addListener(_handleAmountChanged);
  }

  @override
  void dispose() {
    _amountCtrl.removeListener(_handleAmountChanged);
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _handleAmountChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  // ── Date picker ───────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context:         context,
      initialDate:     _selectedDate,
      firstDate:       DateTime(2000),
      lastDate:        DateTime.now(),
      builder:         (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
            primary: Theme.of(ctx).colorScheme.primary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final amount  = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final notifier = ref.read(
        transactionFormProvider(widget.customerId).notifier);

    TransactionEntity? savedTransaction;
    if (widget.isEditing) {
      savedTransaction = await notifier.updateTransaction(
        existing: widget.existingTransaction!,
        amount:   amount,
        type:     _type,
        date:     _selectedDate,
        note:     _noteCtrl.text,
      );
    } else {
      savedTransaction = await notifier.addTransaction(
        customerId: widget.customerId,
        amount:     amount,
        type:       _type,
        date:       _selectedDate,
        note:       _noteCtrl.text,
      );
    }

    if (savedTransaction != null && mounted) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(savedTransaction);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionFormProvider(widget.customerId));
    final cs    = Theme.of(context).colorScheme;
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final currentBalance = widget.currentBalance;
    final baseBalance = widget.isEditing
        ? currentBalance - (widget.existingTransaction?.balanceDelta ?? 0)
        : currentBalance;
    final projectedBalance =
        baseBalance + (_type == TransactionType.gave ? amount : -amount);

    return KeyboardDismissWrapper(
      child: Scaffold(
        // Drag handle at top for bottom-sheet feel
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close_rounded),
          ),
          title: Text(
            widget.isEditing ? 'Edit Entry' : 'Add Entry',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          actions: [
            TextButton(
              onPressed: state.isLoading ? null : _onSave,
              child: Text(
                'Save',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize:   15,
                  color: state.isLoading
                      ? cs.onSurface.withOpacity(0.3)
                      : cs.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),

        body: LoadingOverlay(
          isLoading: state.isLoading,
          message:   widget.isEditing ? 'Updating entry…' : 'Saving entry…',
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Customer banner ────────────────────────────────────
                  _CustomerBanner(
                    name: widget.customerName,
                    currentBalance: currentBalance,
                  )
                      .animate().fadeIn(),

                  const SizedBox(height: 16),

                  _BalancePreviewCard(
                    currentBalance: currentBalance,
                    projectedBalance: projectedBalance,
                    selectedType: _type,
                    isEditing: widget.isEditing,
                    amount: amount,
                  ).animate().fadeIn(delay: 40.ms),

                  const SizedBox(height: 24),

                  // ── Type toggle ────────────────────────────────────────
                  _TypeToggle(
                    selected:  _type,
                    onChanged: (t) => setState(() => _type = t),
                  ).animate().fadeIn(delay: 80.ms),

                  const SizedBox(height: 24),

                  // ── Amount ─────────────────────────────────────────────
                  _AmountField(
                    controller: _amountCtrl,
                    type:       _type,
                  ).animate().fadeIn(delay: 120.ms),

                  const SizedBox(height: 20),

                  // ── Date picker ────────────────────────────────────────
                  _DateRow(
                    date:     _selectedDate,
                    onTap:    _pickDate,
                  ).animate().fadeIn(delay: 160.ms),

                  const SizedBox(height: 20),

                  // ── Note ───────────────────────────────────────────────
                  TextFormField(
                    controller:      _noteCtrl,
                    maxLines:        2,
                    maxLength:       150,
                    textInputAction: TextInputAction.done,
                    onEditingComplete: _onSave,
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Note (optional)',
                      hintText:  'e.g. For groceries, Loan payment…',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 24),
                        child: Icon(Icons.notes_rounded, size: 20),
                      ),
                      alignLabelWithHint: true,
                    ),
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 8),

                  // ── Error ──────────────────────────────────────────────
                  if (state.errorMessage != null)
                    ErrorDisplay(message: state.errorMessage!)
                        .animate().fadeIn().shakeX(amount: 4),

                  const SizedBox(height: 28),

                  // ── Save button ────────────────────────────────────────
                  _SaveButton(
                    type:      _type,
                    isEditing: widget.isEditing,
                    isLoading: state.isLoading,
                    onPressed: _onSave,
                  ).animate().fadeIn(delay: 240.ms).slideY(begin: 0.15),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Customer Banner ───────────────────────────────────────────────────────────

class _CustomerBanner extends StatelessWidget {
  final String name;
  final double currentBalance;
  const _CustomerBanner({
    required this.name,
    required this.currentBalance,
  });

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding:    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.person_outline_rounded,
              size: 18, color: cs.primary),
          const SizedBox(width: 10),
          Text(
            'Transaction with ',
            style: GoogleFonts.poppins(fontSize: 13, color: cs.onSurface.withOpacity(0.6)),
          ),
          Text(
            name,
            style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _headlineBalance(currentBalance),
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _headlineBalance(double balance) {
    if (balance == 0) return 'Settled';
    final label = balance > 0 ? 'To receive' : 'To pay';
    return '$label ${AppFormatters.rupee(balance.abs())}';
  }
}

class _BalancePreviewCard extends StatelessWidget {
  final double currentBalance;
  final double projectedBalance;
  final TransactionType selectedType;
  final bool isEditing;
  final double amount;

  const _BalancePreviewCard({
    required this.currentBalance,
    required this.projectedBalance,
    required this.selectedType,
    required this.isEditing,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent =
        selectedType == TransactionType.gave ? AppColors.success : AppColors.danger;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withOpacity(0.12),
            cs.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  selectedType == TransactionType.gave
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  color: accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedType == TransactionType.gave ? 'You Gave' : 'You Got',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      amount > 0
                          ? _changeSummary()
                          : 'Enter amount to preview the updated payable balance.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: cs.onSurface.withOpacity(0.6),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _PreviewAmount(
                  label: 'Current balance',
                  value: _balanceLabel(currentBalance),
                  color: _balanceColor(currentBalance),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PreviewAmount(
                  label: isEditing ? 'Updated balance' : 'After this entry',
                  value: _balanceLabel(projectedBalance),
                  color: _balanceColor(projectedBalance),
                  highlight: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _changeSummary() {
    final amountLabel = AppFormatters.rupee(amount);
    if (selectedType == TransactionType.gave) {
      return 'This will increase receivable by $amountLabel.';
    }
    return 'This will reduce receivable by $amountLabel.';
  }

  String _balanceLabel(double balance) {
    if (balance == 0) return 'Settled';
    final prefix = balance > 0 ? 'To receive' : 'To pay';
    return '$prefix ${AppFormatters.rupee(balance.abs())}';
  }

  Color _balanceColor(double balance) {
    if (balance == 0) return Colors.grey.shade700;
    return balance > 0 ? AppColors.success : AppColors.danger;
  }
}

class _PreviewAmount extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool highlight;

  const _PreviewAmount({
    required this.label,
    required this.value,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? color.withOpacity(0.08) : cs.surface.withOpacity(0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight ? color.withOpacity(0.18) : cs.outline.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withOpacity(0.52),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
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

// ── Type Toggle ───────────────────────────────────────────────────────────────

class _TypeToggle extends StatelessWidget {
  final TransactionType selected;
  final ValueChanged<TransactionType> onChanged;

  const _TypeToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TRANSACTION TYPE',
          style: GoogleFonts.poppins(
            fontSize:      11,
            fontWeight:    FontWeight.w700,
            color:         Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _TypeBtn(
                label:    'You Gave',
                subtitle: 'They owe you',
                icon:     Icons.arrow_upward_rounded,
                color:    AppColors.success,
                bgColor:  AppColors.successLight,
                selected: selected == TransactionType.gave,
                onTap:    () => onChanged(TransactionType.gave),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TypeBtn(
                label:    'You Got',
                subtitle: 'You received',
                icon:     Icons.arrow_downward_rounded,
                color:    AppColors.danger,
                bgColor:  AppColors.dangerLight,
                selected: selected == TransactionType.got,
                onTap:    () => onChanged(TransactionType.got),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TypeBtn extends StatelessWidget {
  final String   label;
  final String   subtitle;
  final IconData icon;
  final Color    color;
  final Color    bgColor;
  final bool     selected;
  final VoidCallback onTap;

  const _TypeBtn({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:    const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color:        selected
              ? (isDark ? color.withOpacity(0.2) : bgColor)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : (isDark ? AppColors.darkBorder : AppColors.border),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding:    const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:        selected ? color.withOpacity(0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: selected ? color : Theme.of(context).colorScheme.onSurface.withOpacity(0.4), size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize:   13,
                fontWeight: FontWeight.w700,
                color:      selected ? color : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color:    selected ? color.withOpacity(0.7) : Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Amount Field ──────────────────────────────────────────────────────────────

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  final TransactionType       type;

  const _AmountField({required this.controller, required this.type});

  @override
  Widget build(BuildContext context) {
    final color = type == TransactionType.gave ? AppColors.success : AppColors.danger;

    return TextFormField(
      controller:   controller,
      autofocus:    true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      style: GoogleFonts.poppins(
        fontSize:   28,
        fontWeight: FontWeight.w700,
        color:      color,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
      validator: (v) {
        if (v == null || v.isEmpty) return 'Enter an amount';
        final val = double.tryParse(v);
        if (val == null || val <= 0) return 'Enter a valid amount';
        if (val > 10000000) return 'Amount too large (max ₹1 Crore)';
        return null;
      },
      decoration: InputDecoration(
        labelText: 'Amount',
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 8, top: 4),
          child: Text(
            '₹',
            style: GoogleFonts.poppins(
              fontSize:   28,
              fontWeight: FontWeight.w700,
              color:      color,
            ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        hintText: '0',
        hintStyle: GoogleFonts.poppins(
          fontSize:   28,
          fontWeight: FontWeight.w700,
          color:      color.withOpacity(0.25),
        ),
      ),
    );
  }
}

// ── Date Row ──────────────────────────────────────────────────────────────────

class _DateRow extends StatelessWidget {
  final DateTime  date;
  final VoidCallback onTap;

  const _DateRow({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color:        isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, size: 20, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _label(date),
                style: GoogleFonts.poppins(
                  fontSize:   14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: cs.onSurface.withOpacity(0.35)),
          ],
        ),
      ),
    );
  }

  String _label(DateTime d) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day   = DateTime(d.year, d.month, d.day);
    if (day == today) return 'Today — ${DateFormat('d MMM yyyy').format(d)}';
    if (day == today.subtract(const Duration(days: 1)))
      return 'Yesterday — ${DateFormat('d MMM yyyy').format(d)}';
    return DateFormat('EEEE, d MMMM yyyy').format(d);
  }
}

// ── Save Button ───────────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  final TransactionType type;
  final bool            isEditing;
  final bool            isLoading;
  final VoidCallback    onPressed;

  const _SaveButton({
    required this.type,
    required this.isEditing,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isGave = type == TransactionType.gave;
    final color  = isGave ? AppColors.success : AppColors.danger;
    final label  = isEditing
        ? 'Update Entry'
        : isGave ? 'Confirm — You Gave' : 'Confirm — You Got';
    final icon   = isGave
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;

    return SizedBox(
      width:  double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon:  isLoading
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Icon(icon, size: 20),
        label: Text(
          label,
          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
