import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_providers.dart';

enum CashType { cashIn, cashOut }

class CashEntry {
  final String   id;
  final String   userId;
  final CashType type;
  final double   amount;
  final String?  note;
  final DateTime date;
  final DateTime createdAt;

  const CashEntry({
    required this.id, required this.userId, required this.type,
    required this.amount, this.note, required this.date,
    required this.createdAt,
  });

  bool   get isCashIn  => type == CashType.cashIn;
  double get signedAmt => isCashIn ? amount : -amount;

  Map<String, dynamic> toMap() => {
    'userId':       userId,
    'type':         isCashIn ? 'in' : 'out',
    'amount':       amount,
    if (note != null && note!.isNotEmpty) 'note': note,
    'date':         Timestamp.fromDate(date),
    'createdAt':    Timestamp.fromDate(createdAt),
    'yearMonthDay': DateFormat('yyyy-MM-dd').format(date),
  };

  factory CashEntry.fromMap(String id, Map<String, dynamic> d) => CashEntry(
    id:        id,
    userId:    d['userId']     as String,
    type:      d['type'] == 'in' ? CashType.cashIn : CashType.cashOut,
    amount:    (d['amount']    as num).toDouble(),
    note:      d['note']       as String?,
    date:      (d['date']      as Timestamp).toDate(),
    createdAt: (d['createdAt'] as Timestamp).toDate(),
  );
}

class CashbookState {
  final List<CashEntry> entries;
  final bool            isLoading;
  final String?         error;
  final DateTime        selectedDate;

  const CashbookState({
    this.entries   = const [],
    this.isLoading = false,
    this.error,
    required this.selectedDate,
  });

  double get totalIn  => entries.where((e) => e.isCashIn).fold(0.0, (s, e) => s + e.amount);
  double get totalOut => entries.where((e) => !e.isCashIn).fold(0.0, (s, e) => s + e.amount);
  double get balance  => totalIn - totalOut;

  bool get isToday {
    final n = DateTime.now();
    return selectedDate.year == n.year &&
           selectedDate.month == n.month &&
           selectedDate.day   == n.day;
  }

  CashbookState copyWith({
    List<CashEntry>? entries, bool? isLoading,
    String? error, bool clearError = false, DateTime? selectedDate,
  }) => CashbookState(
    entries:      entries      ?? this.entries,
    isLoading:    isLoading    ?? this.isLoading,
    error:        clearError ? null : error ?? this.error,
    selectedDate: selectedDate ?? this.selectedDate,
  );
}

class CashbookNotifier extends StateNotifier<CashbookState> {
  final Ref _ref;
  static const _col = 'cashbook';

  CashbookNotifier(this._ref)
      : super(CashbookState(selectedDate: DateTime.now())) {
    _load();
  }

  String? get _uid => _ref.read(currentUserProvider)?.id;

  Future<void> _load() async {
    final uid = _uid;
    if (uid == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(state.selectedDate);
      final snap = await FirebaseFirestore.instance
          .collection(_col)
          .where('userId', isEqualTo: uid)
          .where('yearMonthDay', isEqualTo: dateStr)
          .get();
      final entries = snap.docs
          .map((d) => CashEntry.fromMap(d.id, d.data()))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = state.copyWith(isLoading: false, entries: entries);
    } catch (_) {
      // Fallback: fetch all and filter client-side (no composite index needed)
      try {
        final all = await FirebaseFirestore.instance
            .collection(_col)
            .where('userId', isEqualTo: uid)
            .get();
        final dateStr = DateFormat('yyyy-MM-dd').format(state.selectedDate);
        final filtered = all.docs
            .map((d) => CashEntry.fromMap(d.id, d.data()))
            .where((e) => DateFormat('yyyy-MM-dd').format(e.date) == dateStr)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        state = state.copyWith(isLoading: false, entries: filtered);
      } catch (e2) {
        state = state.copyWith(isLoading: false, error: 'Failed to load cashbook.');
      }
    }
  }

  void selectDate(DateTime d) {
    state = state.copyWith(selectedDate: d);
    _load();
  }

  Future<bool> addEntry({
    required CashType type,
    required double   amount,
    String?           note,
  }) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      final now = DateTime.now();
      final map = CashEntry(
        id: '', userId: uid, type: type, amount: amount,
        note: note, date: state.selectedDate, createdAt: now,
      ).toMap();
      final ref = await FirebaseFirestore.instance.collection(_col).add(map);
      final saved = CashEntry(
        id: ref.id, userId: uid, type: type, amount: amount,
        note: note, date: state.selectedDate, createdAt: now,
      );
      state = state.copyWith(entries: [saved, ...state.entries]);
      return true;
    } catch (_) {
      state = state.copyWith(error: 'Failed to save entry.');
      return false;
    }
  }

  Future<void> deleteEntry(String id) async {
    try {
      await FirebaseFirestore.instance.collection(_col).doc(id).delete();
      state = state.copyWith(
          entries: state.entries.where((e) => e.id != id).toList());
    } catch (_) {}
  }

  Future<void> refresh() => _load();
}

final cashbookProvider =
    StateNotifierProvider.autoDispose<CashbookNotifier, CashbookState>(
  (ref) => CashbookNotifier(ref),
);
