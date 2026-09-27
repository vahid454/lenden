import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/customer_providers.dart';
import '../../../core/providers/payment_promise_providers.dart';
import '../../../core/services/pdf_export_service.dart';
import '../../../core/services/share_service.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../domain/entities/collection_report_entry.dart';
import '../../../domain/entities/customer_entity.dart';
import '../../../domain/entities/payment_promise_entity.dart';
import '../../../domain/entities/transaction_entity.dart';

enum _CollectionPeriod {
  allDue,
  overdue,
  today,
  thisWeek,
  thisMonth,
  custom,
  all,
}

extension on _CollectionPeriod {
  String get label => switch (this) {
        _CollectionPeriod.allDue => 'All customer due',
        _CollectionPeriod.overdue => 'Overdue',
        _CollectionPeriod.today => 'Today',
        _CollectionPeriod.thisWeek => 'This week',
        _CollectionPeriod.thisMonth => 'This month',
        _CollectionPeriod.custom => 'Custom',
        _CollectionPeriod.all => 'All dates',
      };
}

enum _PromiseState { open, pending, partial, paid, missed, all }

extension on _PromiseState {
  String get label => switch (this) {
        _PromiseState.open => 'Open',
        _PromiseState.pending => 'Pending',
        _PromiseState.partial => 'Partial paid',
        _PromiseState.paid => 'Paid',
        _PromiseState.missed => 'Missed',
        _PromiseState.all => 'All statuses',
      };
}

enum _CollectionSort { dueDate, highestAmount, customerName }

extension on _CollectionSort {
  String get label => switch (this) {
        _CollectionSort.dueDate => 'Due date',
        _CollectionSort.highestAmount => 'Highest amount',
        _CollectionSort.customerName => 'Customer name',
      };
}

class CollectionReportPage extends ConsumerStatefulWidget {
  const CollectionReportPage({super.key});

  @override
  ConsumerState<CollectionReportPage> createState() =>
      _CollectionReportPageState();
}

class _CollectionReportPageState extends ConsumerState<CollectionReportPage> {
  _CollectionPeriod _period = _CollectionPeriod.allDue;
  _PromiseState _status = _PromiseState.open;
  _CollectionSort _sort = _CollectionSort.dueDate;
  bool _outstandingOnly = true;
  DateTimeRange? _customRange;
  bool _exporting = false;
  bool _reconcilingPromises = false;
  String? _reconciledPromiseKey;

  @override
  Widget build(BuildContext context) {
    final promiseState = ref.watch(paymentPromisesStreamProvider);
    final customerState = ref.watch(customersStreamProvider);
    final paymentHistoryState = ref.watch(promisePaymentHistoryProvider);
    final customers = {
      for (final customer
          in customerState.valueOrNull ?? const <CustomerEntity>[])
        customer.id: customer,
    };
    final promises = promiseState.valueOrNull ?? const <PaymentPromiseEntity>[];
    final paymentHistory =
        paymentHistoryState.valueOrNull ?? const <TransactionEntity>[];
    final fulfilledPromiseIds =
        promiseIdsFulfilledByPayments(promises, paymentHistory);
    if (!paymentHistoryState.isLoading && !paymentHistoryState.hasError) {
      _schedulePromiseReconciliation(
        promises,
        paymentHistory,
        fulfilledPromiseIds,
      );
    }
    final filtered = _filter(
      promises,
      customers,
      fulfilledPromiseIds,
    );
    final total = filtered.fold<double>(
      0,
      (sum, item) => sum + item.collectionAmount,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Collection Report',
            style:
                GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Export filtered PDF',
            onPressed: _exporting || paymentHistoryState.hasError
                ? null
                : () => _export(filtered),
            icon: _exporting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined, size: 21),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: paymentHistoryState.hasError
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sync_problem_outlined, size: 30),
                    const SizedBox(height: 12),
                    const Text(
                      'Payment history could not be checked. Refresh to avoid showing a fulfilled promise.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () =>
                          ref.invalidate(promisePaymentHistoryProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
              ),
            )
          : ((promiseState.isLoading && promiseState.valueOrNull == null) ||
                  (customerState.isLoading &&
                      customerState.valueOrNull == null) ||
                  (paymentHistoryState.isLoading &&
                      paymentHistoryState.valueOrNull == null))
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    _filters(),
                    _summary(filtered.length, total),
                    Expanded(
                      child: filtered.isEmpty
                          ? const _EmptyCollectionReport()
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 10, 16, 32),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, index) {
                                return _CollectionReportRow(
                                    entry: filtered[index]);
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  void _schedulePromiseReconciliation(
    List<PaymentPromiseEntity> promises,
    List<TransactionEntity> transactions,
    Set<String> fulfilledPromiseIds,
  ) {
    final pending = promises
        .where((promise) =>
            promise.isOpen && fulfilledPromiseIds.contains(promise.id))
        .toList();
    final key =
        (pending.map((promise) => promise.id).toList()..sort()).join('|');
    if (_reconcilingPromises || key.isEmpty || key == _reconciledPromiseKey) {
      return;
    }
    _reconciledPromiseKey = key;
    _reconcilingPromises = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted) return;
        final actions = ref.read(paymentPromiseActionsProvider);
        for (final promise in pending) {
          final error =
              await actions.reconcilePaymentHistory(promise, transactions);
          if (error != null && mounted) {
            _reconciledPromiseKey = key;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Could not update a fulfilled promise: $error'),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () {
                  _reconciledPromiseKey = null;
                  ref.invalidate(promisePaymentHistoryProvider);
                },
              ),
            ));
            return;
          }
        }
      } finally {
        _reconcilingPromises = false;
      }
    });
  }

  Widget _filters() {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _CollectionPeriod.values.length,
                separatorBuilder: (_, __) => const SizedBox(width: 7),
                itemBuilder: (_, index) {
                  final period = _CollectionPeriod.values[index];
                  return ChoiceChip(
                    label: Text(period.label),
                    selected: _period == period,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => _selectPeriod(period),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _promiseStatusControl()),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<_CollectionSort>(
                    value: _sort,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Sort by',
                      isDense: true,
                    ),
                    items: _CollectionSort.values
                        .map((value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.label),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _sort = value ?? _sort),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Only customers with outstanding balance'),
              value: _period == _CollectionPeriod.allDue || _outstandingOnly,
              onChanged: _period == _CollectionPeriod.allDue
                  ? null
                  : (value) => setState(() => _outstandingOnly = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _promiseStatusControl() {
    if (_period == _CollectionPeriod.allDue) {
      return const InputDecorator(
        decoration: InputDecoration(
          labelText: 'Promise status',
          isDense: true,
        ),
        child: Text('Any / no promise'),
      );
    }
    return DropdownButtonFormField<_PromiseState>(
      value: _status,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Promise status',
        isDense: true,
      ),
      items: _PromiseState.values
          .map((value) => DropdownMenuItem(
                value: value,
                child: Text(value.label),
              ))
          .toList(),
      onChanged: (value) => setState(() => _status = value ?? _status),
    );
  }

  Widget _summary(int count, double amount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          const Icon(Icons.groups_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text('$count ${count == 1 ? 'customer' : 'customers'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                AppFormatters.rupee(amount),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectPeriod(_CollectionPeriod period) async {
    if (period != _CollectionPeriod.custom) {
      setState(() => _period = period);
      return;
    }
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _customRange,
    );
    if (range != null) {
      setState(() {
        _customRange = range;
        _period = period;
      });
    }
  }

  List<CollectionReportEntry> _filter(
    List<PaymentPromiseEntity> promises,
    Map<String, CustomerEntity> customers,
    Set<String> fulfilledPromiseIds,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthEnd = DateTime(now.year, now.month + 1, 1)
        .subtract(const Duration(microseconds: 1));

    if (_period == _CollectionPeriod.allDue) {
      final result = buildOutstandingCollectionEntries(
        customers.values,
        promises,
        fulfilledPromiseIds: fulfilledPromiseIds,
      );
      _sortEntries(result);
      return result;
    }

    final result = promises
        .where((promise) {
          final customer = customers[promise.customerId];
          if (customer == null) return false;
          if (_outstandingOnly && customer.balance <= 0) return false;
          final statusMatches = switch (_status) {
            _PromiseState.open => promise.isOpen,
            _PromiseState.pending =>
              promise.status == PaymentPromiseStatus.pending,
            _PromiseState.partial =>
              promise.status == PaymentPromiseStatus.partialPaid,
            _PromiseState.paid => promise.status == PaymentPromiseStatus.paid,
            _PromiseState.missed =>
              promise.status == PaymentPromiseStatus.missed,
            _PromiseState.all =>
              promise.status != PaymentPromiseStatus.cancelled,
          };
          if (!statusMatches) return false;
          if (fulfilledPromiseIds.contains(promise.id)) {
            return false;
          }

          final due = DateTime(
            promise.promisedDate.year,
            promise.promisedDate.month,
            promise.promisedDate.day,
          );
          return switch (_period) {
            _CollectionPeriod.allDue => false,
            _CollectionPeriod.overdue => due.isBefore(today),
            _CollectionPeriod.today => due == today,
            _CollectionPeriod.thisWeek => !due.isBefore(today) &&
                !due.isAfter(today.add(const Duration(days: 6))),
            _CollectionPeriod.thisMonth =>
              !due.isBefore(DateTime(now.year, now.month, 1)) &&
                  !due.isAfter(monthEnd),
            _CollectionPeriod.custom => _customRange != null &&
                !due.isBefore(_customRange!.start) &&
                !due.isAfter(_customRange!.end),
            _CollectionPeriod.all => true,
          };
        })
        .map((promise) => CollectionReportEntry(
              customer: customers[promise.customerId]!,
              promise: promise,
            ))
        .toList();

    _sortEntries(result);
    return result;
  }

  void _sortEntries(List<CollectionReportEntry> entries) {
    entries.sort((a, b) => switch (_sort) {
          _CollectionSort.dueDate => switch ((a.promisedDate, b.promisedDate)) {
              (null, null) => a.customer.name.compareTo(b.customer.name),
              (null, _) => 1,
              (_, null) => -1,
              (final aDate?, final bDate?) => aDate.compareTo(bDate),
            },
          _CollectionSort.highestAmount =>
            b.collectionAmount.compareTo(a.collectionAmount),
          _CollectionSort.customerName =>
            a.customer.name.compareTo(b.customer.name),
        });
  }

  Future<void> _export(
    List<CollectionReportEntry> entries,
  ) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _exporting = true);
    try {
      final file =
          await ref.read(pdfExportServiceProvider).generatePromiseReport(
                entries: entries,
                userName: user.name,
                businessName: user.businessName ?? '',
                reportTitle: _period == _CollectionPeriod.allDue
                    ? _period.label
                    : '${_period.label} - ${_status.label}',
              );
      if (mounted) await ShareService.sharePdf(file, 'Collection Report');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Export failed: $error'),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

class _CollectionReportRow extends StatelessWidget {
  final CollectionReportEntry entry;

  const _CollectionReportRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final customer = entry.customer;
    final promisedDate = entry.promisedDate;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 54,
            child: Column(
              children: [
                Text(
                    promisedDate == null
                        ? '--'
                        : DateFormat('dd').format(promisedDate),
                    style: GoogleFonts.poppins(
                        fontSize: 20, fontWeight: FontWeight.w700)),
                Text(
                    promisedDate == null
                        ? 'No date'
                        : DateFormat('MMM').format(promisedDate),
                    style: GoogleFonts.poppins(fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                Text(customer.phone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
                if (customer.secondaryPhone?.isNotEmpty == true)
                  Text('Alt ${customer.secondaryPhone}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 112,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(AppFormatters.rupee(entry.collectionAmount),
                      maxLines: 1,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          color: AppColors.success)),
                ),
                Text(entry.statusLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCollectionReport extends StatelessWidget {
  const _EmptyCollectionReport();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_alt_off_outlined, size: 42),
            const SizedBox(height: 12),
            Text('No customers match these filters',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
