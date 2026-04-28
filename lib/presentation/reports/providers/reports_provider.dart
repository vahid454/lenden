import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/transaction_providers.dart';
import '../../../domain/entities/transaction_entity.dart';

// ── Date range ────────────────────────────────────────────────────────────────

enum ReportPeriod { today, thisWeek, thisMonth, lastMonth, last3Months, custom }

extension ReportPeriodX on ReportPeriod {
  String get label {
    switch (this) {
      case ReportPeriod.today:       return 'Today';
      case ReportPeriod.thisWeek:    return 'This Week';
      case ReportPeriod.thisMonth:   return 'This Month';
      case ReportPeriod.lastMonth:   return 'Last Month';
      case ReportPeriod.last3Months: return 'Last 3 Months';
      case ReportPeriod.custom:      return 'Custom';
    }
  }

  DateRange get dateRange {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (this) {
      case ReportPeriod.today:
        return DateRange(today, now);
      case ReportPeriod.thisWeek:
        return DateRange(today.subtract(Duration(days: today.weekday - 1)), now);
      case ReportPeriod.thisMonth:
        return DateRange(DateTime(now.year, now.month, 1), now);
      case ReportPeriod.lastMonth:
        final s = DateTime(now.year, now.month - 1, 1);
        final e = DateTime(now.year, now.month, 1).subtract(const Duration(seconds: 1));
        return DateRange(s, e);
      case ReportPeriod.last3Months:
        return DateRange(DateTime(now.year, now.month - 2, 1), now);
      case ReportPeriod.custom:
        return DateRange(DateTime(now.year, now.month, 1), now);
    }
  }
}

class DateRange {
  final DateTime from;
  final DateTime to;
  const DateRange(this.from, this.to);
}

// ── State ─────────────────────────────────────────────────────────────────────

class ReportsState {
  final ReportPeriod period;
  final DateRange dateRange;
  final bool isLoading;
  final String? errorMessage;
  final List<TransactionEntity> transactions;

  const ReportsState({
    this.period      = ReportPeriod.thisMonth,
    required this.dateRange,
    this.isLoading   = false,
    this.errorMessage,
    this.transactions = const [],
  });

  ReportsState copyWith({
    ReportPeriod? period,
    DateRange? dateRange,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    List<TransactionEntity>? transactions,
  }) => ReportsState(
    period:       period       ?? this.period,
    dateRange:    dateRange    ?? this.dateRange,
    isLoading:    isLoading    ?? this.isLoading,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    transactions: transactions ?? this.transactions,
  );

  double get totalGave =>
      transactions.where((t) => t.isGave).fold(0.0, (s, t) => s + t.amount);
  double get totalGot =>
      transactions.where((t) => t.isGot).fold(0.0, (s, t) => s + t.amount);
  double get netBalance => totalGave - totalGot;
  int    get txCount    => transactions.length;

  List<MonthlyData> get monthlyBreakdown {
    final map = <String, MonthlyData>{};
    for (final tx in transactions) {
      final key = DateFormat('MMM yy').format(tx.date);
      final e   = map[key] ?? MonthlyData(month: key);
      map[key]  = tx.isGave
          ? e.copyWith(gave: e.gave + tx.amount)
          : e.copyWith(got:  e.got  + tx.amount);
    }
    return map.values.toList();
  }

  List<DailyData> get dailyBreakdown {
    final map = <String, DailyData>{};
    for (final tx in transactions) {
      final key = DateFormat('d MMM').format(tx.date);
      final e   = map[key] ?? DailyData(label: key, date: tx.date);
      map[key]  = tx.isGave
          ? e.copyWith(gave: e.gave + tx.amount)
          : e.copyWith(got:  e.got  + tx.amount);
    }
    final list = map.values.toList()..sort((a, b) => a.date.compareTo(b.date));
    return list;
  }
}

class MonthlyData {
  final String month;
  final double gave;
  final double got;
  const MonthlyData({required this.month, this.gave = 0, this.got = 0});
  MonthlyData copyWith({double? gave, double? got}) =>
      MonthlyData(month: month, gave: gave ?? this.gave, got: got ?? this.got);
}

class DailyData {
  final String label;
  final DateTime date;
  final double gave;
  final double got;
  const DailyData({required this.label, required this.date, this.gave = 0, this.got = 0});
  DailyData copyWith({double? gave, double? got}) =>
      DailyData(label: label, date: date, gave: gave ?? this.gave, got: got ?? this.got);
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class ReportsNotifier extends StateNotifier<ReportsState> {
  final Ref _ref;

  ReportsNotifier(this._ref)
      : super(ReportsState(dateRange: ReportPeriod.thisMonth.dateRange)) {
    _load();
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, clearError: true);

    final userId = _ref.read(currentUserProvider)?.id;
    if (userId == null || userId.isEmpty) {
      state = state.copyWith(isLoading: false, transactions: []);
      return;
    }

    try {
      final useCase = _ref.read(getTransactionsByDateRangeUseCaseProvider);
      final result  = await useCase(
        userId: userId,
        from:   state.dateRange.from,
        to:     state.dateRange.to,
      );

      result.fold(
        (f) => state = state.copyWith(isLoading: false, errorMessage: f.message),
        (txs) => state = state.copyWith(isLoading: false, transactions: txs),
      );
    } catch (e) {
      state = state.copyWith(
          isLoading: false, errorMessage: 'Failed to load report. Please retry.');
    }
  }

  void setPeriod(ReportPeriod period) {
    state = state.copyWith(period: period, dateRange: period.dateRange);
    _load();
  }

  void setCustomRange(DateRange range) {
    state = state.copyWith(period: ReportPeriod.custom, dateRange: range);
    _load();
  }

  Future<void> refresh() => _load();
}

// ── Provider ──────────────────────────────────────────────────────────────────

final reportsProvider =
    StateNotifierProvider<ReportsNotifier, ReportsState>(
  (ref) => ReportsNotifier(ref),
);
