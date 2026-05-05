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

class AddEditTransactionPage extends ConsumerStatefulWidget {
  final String customerId;
  final String customerName;
  final double currentBalance;
  final TransactionType? initialType;
  final TransactionEntity? existingTransaction;

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
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  late TransactionType _type;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final e = widget.existingTransaction;
    _type = e?.type ?? widget.initialType ?? TransactionType.gave;
    _selectedDate = e?.date ?? DateTime.now();
    if (e != null) {
      _amountCtrl.text = e.amount % 1 == 0
          ? e.amount.toInt().toString()
          : e.amount.toStringAsFixed(2);
      _noteCtrl.text = e.note ?? '';
    }
    _amountCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final notifier =
        ref.read(transactionFormProvider(widget.customerId).notifier);

    TransactionEntity? result;
    if (widget.isEditing) {
      result = await notifier.updateTransaction(
        existing: widget.existingTransaction!,
        amount: amount,
        type: _type,
        date: _selectedDate,
        note: _noteCtrl.text,
      );
    } else {
      result = await notifier.addTransaction(
        customerId: widget.customerId,
        amount: amount,
        type: _type,
        date: _selectedDate,
        note: _noteCtrl.text,
      );
    }

    if (result != null && mounted) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionFormProvider(widget.customerId));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final isGave = _type == TransactionType.gave;
    final accent = isGave ? AppColors.success : AppColors.danger;

    // Projected balance
    final baseBalance = widget.isEditing
        ? widget.currentBalance -
            (widget.existingTransaction?.balanceDelta ?? 0)
        : widget.currentBalance;
    final projected = baseBalance + (isGave ? amount : -amount);

    return KeyboardDismissWrapper(
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : const Color(0xFFF8F9FA),
        body: LoadingOverlay(
          isLoading: state.isLoading,
          message: widget.isEditing ? 'Updating…' : 'Saving…',
          child: Form(
            key: _formKey,
            child: CustomScrollView(
              slivers: [
                // ── Compact header ──────────────────────────────────────
                SliverAppBar(
                  pinned: true,
                  backgroundColor:
                      isDark ? AppColors.darkSurface : AppColors.surface,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  title: Text(
                    widget.isEditing ? 'Edit Entry' : 'New Entry',
                    style: GoogleFonts.poppins(
                        fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: FilledButton(
                        onPressed: state.isLoading ? null : _onSave,
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: state.isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text('Save',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: Colors.white)),
                      ),
                    ),
                  ],
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Who + current balance ──────────────────────
                        _PartyRow(
                          name: widget.customerName,
                          balance: widget.currentBalance,
                          isDark: isDark,
                        ).animate().fadeIn(),

                        const SizedBox(height: 20),

                        // ── Type selector (segmented) ──────────────────
                        _SegmentedTypeSelector(
                          selected: _type,
                          onChanged: (t) => setState(() => _type = t),
                        ).animate().fadeIn(delay: 60.ms),

                        const SizedBox(height: 20),

                        // ── Amount input ───────────────────────────────
                        _BigAmountField(
                          controller: _amountCtrl,
                          accent: accent,
                        ).animate().fadeIn(delay: 100.ms),

                        // ── Balance preview ────────────────────────────
                        if (amount > 0) ...[
                          const SizedBox(height: 14),
                          _BalanceArrow(
                            current: widget.currentBalance,
                            projected: projected,
                            accent: accent,
                          ).animate().fadeIn(duration: 200.ms),
                        ],

                        const SizedBox(height: 20),

                        // ── Date chip ──────────────────────────────────
                        _DateChip(date: _selectedDate, onTap: _pickDate)
                            .animate()
                            .fadeIn(delay: 130.ms),

                        const SizedBox(height: 14),

                        // ── Note field ─────────────────────────────────
                        _NoteField(controller: _noteCtrl)
                            .animate()
                            .fadeIn(delay: 160.ms),

                        // ── Error ──────────────────────────────────────
                        if (state.errorMessage != null) ...[
                          const SizedBox(height: 14),
                          ErrorDisplay(message: state.errorMessage!)
                              .animate()
                              .fadeIn()
                              .shakeX(amount: 4),
                        ],

                        const SizedBox(height: 28),

                        // ── Save button ────────────────────────────────
                        _ConfirmButton(
                          type: _type,
                          isEditing: widget.isEditing,
                          isLoading: state.isLoading,
                          onPressed: _onSave,
                        ).animate().fadeIn(delay: 180.ms),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Party Row ─────────────────────────────────────────────────────────────────

class _PartyRow extends StatelessWidget {
  final String name;
  final double balance;
  final bool isDark;
  const _PartyRow(
      {required this.name, required this.balance, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: cs.primary.withOpacity(0.1),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w700, color: cs.primary),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          Text(
            balance == 0
                ? 'Settled'
                : balance > 0
                    ? 'Owes you ${AppFormatters.rupee(balance)}'
                    : 'You owe ${AppFormatters.rupee(balance.abs())}',
            style: GoogleFonts.poppins(
                fontSize: 12,
                color: balance > 0
                    ? AppColors.success
                    : balance < 0
                        ? AppColors.danger
                        : cs.onSurface.withOpacity(0.45)),
          ),
        ])),
      ]),
    );
  }
}

// ── Segmented type selector ───────────────────────────────────────────────────

class _SegmentedTypeSelector extends StatelessWidget {
  final TransactionType selected;
  final ValueChanged<TransactionType> onChanged;
  const _SegmentedTypeSelector(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Row(children: [
        Expanded(
            child: _Seg(
          label: 'You Gave',
          icon: Icons.arrow_upward_rounded,
          color: AppColors.success,
          selected: selected == TransactionType.gave,
          onTap: () => onChanged(TransactionType.gave),
        )),
        Container(
            width: 1,
            height: 44,
            color: isDark ? AppColors.darkBorder : AppColors.border),
        Expanded(
            child: _Seg(
          label: 'You Got',
          icon: Icons.arrow_downward_rounded,
          color: AppColors.danger,
          selected: selected == TransactionType.got,
          onTap: () => onChanged(TransactionType.got),
        )),
      ]),
    );
  }
}

class _Seg extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _Seg(
      {required this.label,
      required this.icon,
      required this.color,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon,
              size: 20,
              color: selected ? Colors.white : color.withOpacity(0.6)),
          const SizedBox(height: 4),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : color.withOpacity(0.7))),
        ]),
      ),
    );
  }
}

// ── Big amount field ──────────────────────────────────────────────────────────

class _BigAmountField extends StatelessWidget {
  final TextEditingController controller;
  final Color accent;
  const _BigAmountField({required this.controller, required this.accent});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.35), width: 1.5),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Text('₹',
            style: GoogleFonts.poppins(
                fontSize: 32, fontWeight: FontWeight.w700, color: accent)),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            style: GoogleFonts.poppins(
                fontSize: 32, fontWeight: FontWeight.w700, color: accent),
            inputFormatters: [
              _AmountInputFormatter(),
            ],
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter amount';
              final val = double.tryParse(v);
              if (val == null || val <= 0) return 'Invalid amount';
              if (val > 10000000) return 'Max ₹1 Crore';
              return null;
            },
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: accent.withOpacity(0.2)),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ]),
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

// ── Balance arrow ─────────────────────────────────────────────────────────────

class _BalanceArrow extends StatelessWidget {
  final double current, projected;
  final Color accent;
  const _BalanceArrow(
      {required this.current, required this.projected, required this.accent});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    String balanceLabel(double v) {
      if (v == 0) return 'Settled';
      return v > 0
          ? '${AppFormatters.rupee(v)} to receive'
          : '${AppFormatters.rupee(v.abs())} to pay';
    }

    Color balanceColor(double v) => v > 0
        ? AppColors.success
        : v < 0
            ? AppColors.danger
            : Colors.grey;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Before',
              style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: cs.onSurface.withOpacity(0.45),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(balanceLabel(current),
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: balanceColor(current))),
        ])),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Icon(Icons.arrow_forward_rounded,
              size: 18, color: accent.withOpacity(0.7)),
        ),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('After',
              style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: cs.onSurface.withOpacity(0.45),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(balanceLabel(projected),
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: balanceColor(projected))),
        ])),
      ]),
    );
  }
}

// ── Date chip ─────────────────────────────────────────────────────────────────

class _DateChip extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;
  const _DateChip({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final label = d == today
        ? 'Today'
        : d == today.subtract(const Duration(days: 1))
            ? 'Yesterday'
            : DateFormat('d MMM yyyy').format(date);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: Row(children: [
          Icon(Icons.event_rounded, size: 18, color: cs.primary),
          const SizedBox(width: 10),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w500)),
          const Spacer(),
          Icon(Icons.chevron_right_rounded,
              size: 18, color: cs.onSurface.withOpacity(0.35)),
        ]),
      ),
    );
  }
}

// ── Note field ────────────────────────────────────────────────────────────────

class _NoteField extends StatelessWidget {
  final TextEditingController controller;
  const _NoteField({required this.controller});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: TextField(
        controller: controller,
        maxLines: 2,
        maxLength: 120,
        textInputAction: TextInputAction.done,
        style: GoogleFonts.poppins(fontSize: 14),
        decoration: InputDecoration(
          counterText: '',
          hintText: 'Add a note… (optional)',
          hintStyle: GoogleFonts.poppins(
              fontSize: 13, color: cs.onSurface.withOpacity(0.35)),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Icon(Icons.sticky_note_2_outlined,
                size: 18, color: cs.onSurface.withOpacity(0.4)),
          ),
          alignLabelWithHint: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

// ── Confirm button ────────────────────────────────────────────────────────────

class _ConfirmButton extends StatelessWidget {
  final TransactionType type;
  final bool isEditing, isLoading;
  final VoidCallback onPressed;
  const _ConfirmButton(
      {required this.type,
      required this.isEditing,
      required this.isLoading,
      required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isGave = type == TransactionType.gave;
    final color = isGave ? AppColors.success : AppColors.danger;
    final label = isEditing
        ? 'Update Entry'
        : isGave
            ? 'Confirm — You Gave'
            : 'Confirm — You Got';

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white))
            : Icon(
                isGave
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 18),
        label: Text(label,
            style:
                GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
