import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/customer_providers.dart';
import '../../../core/providers/payment_promise_providers.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/utils/payment_reminder_message.dart';
import '../../../domain/entities/customer_entity.dart';
import '../../../domain/entities/payment_promise_entity.dart';
import '../../../domain/entities/transaction_entity.dart';
import '../../transactions/pages/add_edit_transaction_page.dart';
import '../widgets/payment_promise_sheet.dart';

class FollowUpsPage extends ConsumerStatefulWidget {
  const FollowUpsPage({super.key});

  @override
  ConsumerState<FollowUpsPage> createState() => _FollowUpsPageState();
}

class _FollowUpsPageState extends ConsumerState<FollowUpsPage> {
  PaymentPromiseFilter _filter = PaymentPromiseFilter.overdue;

  @override
  Widget build(BuildContext context) {
    final promises =
        ref.watch(paymentPromisesStreamProvider).valueOrNull ?? const [];
    final customers = {
      for (final customer in ref.watch(visibleCustomersProvider))
        customer.id: customer,
    };
    final now = DateTime.now();
    final openPromises = promises
        .where((promise) =>
            promise.isOpen && (customers[promise.customerId]?.balance ?? 0) > 0)
        .toList();
    final filtered = openPromises.where((promise) {
      if (_filter == PaymentPromiseFilter.dueThisWeek) {
        return promise.isDueThisWeek(now) && !promise.isDueOn(now);
      }
      return _filter.matches(promise, now);
    }).toList()
      ..sort((a, b) => a.promisedDate.compareTo(b.promisedDate));

    return Scaffold(
      appBar: AppBar(
        title: Text('Today\'s follow-ups',
            style:
                GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _FollowUpSummary(promises: openPromises, now: now),
          ),
          SizedBox(
            height: 42,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                for (final filter in const [
                  PaymentPromiseFilter.overdue,
                  PaymentPromiseFilter.dueToday,
                  PaymentPromiseFilter.dueTomorrow,
                  PaymentPromiseFilter.dueThisWeek,
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: _filter == filter,
                      label: Text(filter.label),
                      onSelected: (_) => setState(() => _filter = filter),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? _EmptyFollowUps(filter: _filter)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final promise = filtered[index];
                      final customer = customers[promise.customerId];
                      if (customer == null) return const SizedBox.shrink();
                      return _FollowUpTile(
                        promise: promise,
                        customer: customer,
                        onCall: () => _call(customer.phone),
                        onWhatsApp: () => _remind(customer, promise),
                        onContact: () => _contact(promise),
                        onPayment: () => _payment(customer, promise),
                        onMissed: () => _missed(promise),
                        onReschedule: () => showPaymentPromiseSheet(
                          context,
                          customer: customer,
                          replacing: promise,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _remind(
    CustomerEntity customer,
    PaymentPromiseEntity promise,
  ) async {
    final user = ref.read(currentUserProvider);
    final business = user?.businessName?.trim() ?? '';
    final owner = user?.name.trim() ?? '';
    final sender = business.isNotEmpty
        ? business
        : owner.isNotEmpty
            ? owner
            : 'LenDen';
    final message = PaymentReminderMessage.build(
      customerName: customer.name,
      senderName: sender,
      amount: promise.remainingAmount,
      ownerOwes: false,
      dueDate: promise.promisedDate,
    );
    final uri = Uri.parse(
      'whatsapp://send?phone=91${customer.phone}&text=${Uri.encodeComponent(message)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _contact(PaymentPromiseEntity promise) async {
    final note = await showFollowUpContactDialog(
      context,
      initialNote: promise.followUpNote,
    );
    if (note == null || !mounted) return;
    final error = await ref
        .read(paymentPromiseActionsProvider)
        .contact(promise, note: note);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? 'Marked as contacted today.'),
      backgroundColor: error == null ? null : AppColors.danger,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _payment(
    CustomerEntity customer,
    PaymentPromiseEntity promise,
  ) async {
    final saved = await Navigator.of(context).push<TransactionEntity>(
      MaterialPageRoute(
        builder: (_) => AddEditTransactionPage(
          customerId: customer.id,
          customerName: customer.name,
          currentBalance: customer.balance,
          initialType: TransactionType.got,
          initialAmount: promise.remainingAmount,
          initialNote:
              'Payment against promise for ${DateFormat('d MMM').format(promise.promisedDate)}',
        ),
      ),
    );
    if (saved == null || saved.type != TransactionType.got) return;
    final error = await ref.read(paymentPromiseActionsProvider).payment(
          promise,
          saved.amount,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? 'Payment promise updated.'),
      backgroundColor: error == null ? null : AppColors.danger,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _missed(PaymentPromiseEntity promise) async {
    final error =
        await ref.read(paymentPromiseActionsProvider).markMissed(promise);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? 'Promise marked missed and kept in history.'),
      backgroundColor: error == null ? null : AppColors.danger,
      behavior: SnackBarBehavior.floating,
    ));
  }
}

class _FollowUpSummary extends StatelessWidget {
  final List<PaymentPromiseEntity> promises;
  final DateTime now;
  const _FollowUpSummary({required this.promises, required this.now});

  @override
  Widget build(BuildContext context) {
    final overdue = promises.where((item) => item.isOverdue(now)).toList();
    final today = promises.where((item) => item.isDueOn(now)).toList();
    final week = promises
        .where((item) => item.isDueThisWeek(now) && !item.isDueOn(now))
        .toList();
    return Row(
      children: [
        _SummaryMetric('Overdue', overdue, AppColors.danger),
        const SizedBox(width: 8),
        _SummaryMetric('Today', today, AppColors.warning),
        const SizedBox(width: 8),
        _SummaryMetric('This week', week, AppColors.primary),
      ],
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final List<PaymentPromiseEntity> promises;
  final Color color;
  const _SummaryMetric(this.label, this.promises, this.color);

  @override
  Widget build(BuildContext context) {
    final amount =
        promises.fold<double>(0, (sum, item) => sum + item.remainingAmount);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${promises.length}',
                style: GoogleFonts.poppins(
                    fontSize: 17, fontWeight: FontWeight.w700, color: color)),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 10, fontWeight: FontWeight.w600, color: color)),
            Text(AppFormatters.rupee(amount, compact: true),
                style: GoogleFonts.poppins(
                    fontSize: 10, color: color.withValues(alpha: 0.82))),
          ],
        ),
      ),
    );
  }
}

class _FollowUpTile extends StatelessWidget {
  final PaymentPromiseEntity promise;
  final CustomerEntity customer;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  final VoidCallback onContact;
  final VoidCallback onPayment;
  final VoidCallback onMissed;
  final VoidCallback onReschedule;

  const _FollowUpTile({
    required this.promise,
    required this.customer,
    required this.onCall,
    required this.onWhatsApp,
    required this.onContact,
    required this.onPayment,
    required this.onMissed,
    required this.onReschedule,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final overdue = promise.isOverdue(now);
    final color = overdue
        ? AppColors.danger
        : promise.isDueOn(now)
            ? AppColors.warning
            : AppColors.primary;
    final due = overdue
        ? '${DateFormat('d MMM').format(promise.promisedDate)} overdue'
        : promise.isDueOn(now)
            ? 'Due today'
            : 'Due ${DateFormat('EEE, d MMM').format(promise.promisedDate)}';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Text(customer.initials,
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customer.name,
                          style: GoogleFonts.poppins(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      Text(
                          '${AppFormatters.rupee(promise.remainingAmount)} promised - $due',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: color,
                              fontWeight: FontWeight.w600)),
                    ]),
              ),
              Text(
                  'Due: ${AppFormatters.rupee(customer.balance > 0 ? customer.balance : 0)}',
                  style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.54))),
            ],
          ),
          if (promise.note != null && promise.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(promise.note!,
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.62))),
          ],
          if (promise.lastContactedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Last contacted ${AppFormatters.relativeDate(promise.lastContactedAt!)}${promise.followUpNote == null || promise.followUpNote!.isEmpty ? '' : ' - ${promise.followUpNote}'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.52),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              _ActionIcon(Icons.call_outlined, 'Call', onCall),
              _ActionIcon(Icons.chat_outlined, 'WhatsApp', onWhatsApp),
              _ActionIcon(Icons.payments_outlined, 'Payment', onPayment),
              _ActionIcon(Icons.phone_in_talk_outlined, 'Contacted', onContact),
              PopupMenuButton<String>(
                tooltip: 'More promise actions',
                onSelected: (value) {
                  if (value == 'missed') onMissed();
                  if (value == 'reschedule') onReschedule();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'reschedule', child: Text('Reschedule')),
                  PopupMenuItem(value: 'missed', child: Text('Mark missed')),
                ],
                icon: const Icon(Icons.more_horiz_rounded, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  const _ActionIcon(this.icon, this.tooltip, this.onPressed);

  @override
  Widget build(BuildContext context) => Expanded(
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, size: 19),
          visualDensity: VisualDensity.compact,
        ),
      );
}

class _EmptyFollowUps extends StatelessWidget {
  final PaymentPromiseFilter filter;
  const _EmptyFollowUps({required this.filter});

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          'No ${filter.label.toLowerCase()} follow-ups.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.56),
          ),
        ),
      );
}
