import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/payment_promise_providers.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../domain/entities/customer_entity.dart';
import '../../../domain/entities/payment_promise_entity.dart';

Future<void> showPaymentPromiseSheet(
  BuildContext context, {
  required CustomerEntity customer,
  PaymentPromiseEntity? replacing,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PaymentPromiseSheet(
        customer: customer,
        replacing: replacing,
      ),
    );

/// Returns null when the caller cancels. An empty value records a contact
/// without a note, keeping the common call workflow quick.
Future<String?> showFollowUpContactDialog(
  BuildContext context, {
  String? initialNote,
}) async {
  final controller = TextEditingController(text: initialNote ?? '');
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Follow-up outcome',
          style:
              GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700)),
      content: TextField(
        controller: controller,
        maxLength: 200,
        maxLines: 3,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Called, asked to pay after salary...',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(''),
          child: const Text('No note'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

class _PaymentPromiseSheet extends ConsumerStatefulWidget {
  final CustomerEntity customer;
  final PaymentPromiseEntity? replacing;

  const _PaymentPromiseSheet({required this.customer, this.replacing});

  @override
  ConsumerState<_PaymentPromiseSheet> createState() =>
      _PaymentPromiseSheetState();
}

class _PaymentPromiseSheetState extends ConsumerState<_PaymentPromiseSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late DateTime _date;
  bool _saving = false;

  bool get _isReschedule => widget.replacing != null;

  @override
  void initState() {
    super.initState();
    final old = widget.replacing;
    _amountController = TextEditingController(
      text: old == null ? '' : _amountText(old.remainingAmount),
    );
    _noteController = TextEditingController(text: old?.note ?? '');
    _date = old == null
        ? DateTime.now().add(const Duration(days: 1))
        : old.promisedDate.isAfter(DateTime.now())
            ? old.promisedDate
            : DateTime.now().add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null || userId.isEmpty) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final replacement = PaymentPromiseEntity(
      id: '',
      userId: userId,
      customerId: widget.customer.id,
      amount: double.parse(_amountController.text.trim()),
      promisedDate: _date,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      createdAt: now,
      updatedAt: now,
    );
    final actions = ref.read(paymentPromiseActionsProvider);
    final error = _isReschedule
        ? await actions.reschedule(
            promise: widget.replacing!, replacement: replacement)
        : await actions.add(replacement);
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: AppColors.danger,
      ));
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_isReschedule
          ? 'Promise rescheduled. The previous commitment stays in history.'
          : 'Payment promise saved.'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final remaining =
        widget.customer.balance > 0 ? widget.customer.balance : 0.0;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isReschedule
                    ? 'Reschedule payment promise'
                    : 'Set payment promise',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.customer.name} owes ${AppFormatters.rupee(remaining)}',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.58),
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Promised amount',
                  prefixText: '₹ ',
                ),
                validator: (value) {
                  final amount = double.tryParse(value?.trim() ?? '');
                  if (amount == null || amount <= 0) {
                    return 'Enter a valid amount';
                  }
                  if (amount > 10000000) {
                    return 'Amount is too large';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text(DateFormat('EEE, d MMM yyyy').format(_date)),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'Salary date, festival, reminder detail...',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.event_available_outlined, size: 18),
                  label: Text(
                      _isReschedule ? 'Reschedule promise' : 'Save promise'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _amountText(double amount) =>
      amount % 1 == 0 ? amount.toInt().toString() : amount.toStringAsFixed(2);
}
