import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/transaction_entity.dart';
import '../../common/widgets/common_widgets.dart';
import '../providers/transaction_form_provider.dart';

/// Add or edit a transaction for a given customer.
/// Slide-up modal sheet style.
class AddEditTransactionPage extends ConsumerStatefulWidget {
  final String              customerId;
  final String              customerName;
  final TransactionEntity?  existingTransaction; // non-null = edit mode

  const AddEditTransactionPage({
    super.key,
    required this.customerId,
    required this.customerName,
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
    _type         = e?.type ?? TransactionType.gave;
    _selectedDate = e?.date ?? DateTime.now();
    _amountCtrl.text =
        e != null ? (e.amount % 1 == 0 ? e.amount.toInt().toString() : e.amount.toStringAsFixed(2)) : '';
    _noteCtrl.text = e?.note ?? '';
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
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

    bool success;
    if (widget.isEditing) {
      success = await notifier.updateTransaction(
        existing: widget.existingTransaction!,
        amount:   amount,
        type:     _type,
        date:     _selectedDate,
        note:     _noteCtrl.text,
      );
    } else {
      success = await notifier.addTransaction(
        customerId: widget.customerId,
        amount:     amount,
        type:       _type,
        date:       _selectedDate,
        note:       _noteCtrl.text,
      );
    }

    if (success && mounted) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(true); // signal success to caller
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionFormProvider(widget.customerId));
    final cs    = Theme.of(context).colorScheme;

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
                  _CustomerBanner(name: widget.customerName)
                      .animate().fadeIn(),

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
  const _CustomerBanner({required this.name});

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
