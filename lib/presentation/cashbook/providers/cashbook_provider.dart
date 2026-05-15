import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_providers.dart';

enum CashType { cashIn, cashOut }

class CashEntry {
  final String id;
  final String userId;
  final CashType type;
  final double amount;
  final String? note;
  final DateTime date;
  final DateTime createdAt;

  const CashEntry({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    this.note,
    required this.date,
    required this.createdAt,
  });

  bool get isCashIn => type == CashType.cashIn;
  double get signedAmt => isCashIn ? amount : -amount;

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'type': isCashIn ? 'in' : 'out',
        'amount': amount,
        if (note != null && note!.isNotEmpty) 'note': note,
        'date': Timestamp.fromDate(date),
        'createdAt': Timestamp.fromDate(createdAt),
        'yearMonthDay': DateFormat('yyyy-MM-dd').format(date),
      };

  factory CashEntry.fromMap(String id, Map<String, dynamic> d) => CashEntry(
        id: id,
        userId: d['userId'] as String,
        type: d['type'] == 'in' ? CashType.cashIn : CashType.cashOut,
        amount: (d['amount'] as num).toDouble(),
        note: d['note'] as String?,
        date: (d['date'] as Timestamp).toDate(),
        createdAt: (d['createdAt'] as Timestamp).toDate(),
      );
}

class CashbookState {
  final List<CashEntry> entries;
  final bool isLoading;
  final String? error;
  final DateTime selectedDate;

  const CashbookState({
    this.entries = const [],
    this.isLoading = false,
    this.error,
    required this.selectedDate,
  });

  double get totalIn =>
      entries.where((e) => e.isCashIn).fold(0.0, (s, e) => s + e.amount);
  double get totalOut =>
      entries.where((e) => !e.isCashIn).fold(0.0, (s, e) => s + e.amount);
  double get balance => totalIn - totalOut;

  bool get isToday {
    final n = DateTime.now();
    return selectedDate.year == n.year &&
        selectedDate.month == n.month &&
        selectedDate.day == n.day;
  }

  CashbookState copyWith({
    List<CashEntry>? entries,
    bool? isLoading,
    String? error,
    bool clearError = false,
    DateTime? selectedDate,
  }) =>
      CashbookState(
        entries: entries ?? this.entries,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
        selectedDate: selectedDate ?? this.selectedDate,
      );
}

class CashbookNotifier extends StateNotifier<CashbookState> {
  final Ref _ref;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  static const _col = 'cashbook';

  CashbookNotifier(this._ref)
      : super(CashbookState(selectedDate: DateTime.now())) {
    _ref.listen(currentUserProvider, (_, __) => _watch(),
        fireImmediately: true);
    _ref.onDispose(() => _subscription?.cancel());
  }

  String? get _uid {
    final profileUid = _ref.read(currentUserProvider)?.id;
    if (profileUid != null && profileUid.isNotEmpty) return profileUid;
    return FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _watch() async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) {
      await _subscription?.cancel();
      state = state.copyWith(isLoading: false, entries: []);
      return;
    }
    await _subscription?.cancel();
    state = state.copyWith(isLoading: true, clearError: true);
    final dateStr = DateFormat('yyyy-MM-dd').format(state.selectedDate);

    // Use only userId filter — avoids composite index requirement.
    // Filter by date client-side so it works without any Firestore index.
    _subscription = FirebaseFirestore.instance
        .collection(_col)
        .where('userId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      final entries = snap.docs
          .map((d) => CashEntry.fromMap(d.id, d.data()))
          .where((e) => DateFormat('yyyy-MM-dd').format(e.date) == dateStr)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) {
        state = state.copyWith(isLoading: false, entries: entries);
      }
    }, onError: (e) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load cashbook. Check your connection.',
        );
      }
    });
  }

  void selectDate(DateTime d) {
    state = state.copyWith(selectedDate: d);
    _watch();
  }

  Future<bool> addEntry({
    required CashType type,
    required double amount,
    String? note,
  }) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) {
      state = state.copyWith(error: 'User not authenticated. Please log in again.');
      return false;
    }

    final now = DateTime.now();
    final map = CashEntry(
      id: '',
      userId: uid,
      type: type,
      amount: amount,
      note: note,
      date: state.selectedDate,
      createdAt: now,
    ).toMap();

    int attempt = 0;
    while (attempt < 2) {
      try {
        if (attempt > 0) {
          // Refresh auth token before retrying permission-denied writes.
          await FirebaseAuth.instance.currentUser?.getIdToken(true);
        }
        await FirebaseFirestore.instance.collection(_col).add(map);
        state = state.copyWith(clearError: true);
        return true;
      } on FirebaseException catch (e) {
        attempt += 1;
        if (e.code == 'permission-denied' && attempt < 2) {
          continue;
        }
        String errorMsg = 'Failed to save entry. Please try again.';
        if (e.code == 'permission-denied') {
          errorMsg = 'Permission denied. Check your account settings or Firestore rules.';
        } else if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
          errorMsg = 'Network error. Check your internet connection.';
        } else if (e.code == 'resource-exhausted') {
          errorMsg = 'Storage quota exceeded. Please delete old entries.';
        }
        state = state.copyWith(error: errorMsg);
        return false;
      } catch (e) {
        state = state.copyWith(error: 'Failed to save entry. Please try again.');
        return false;
      }
    }
    state = state.copyWith(error: 'Failed to save entry. Please try again.');
    return false;
  }

  Future<List<CashEntry>> getEntriesByRange({
    required DateTime from,
    required DateTime to,
  }) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return [];

    final start = _dayKey(from);
    final end = _dayKey(to);
    try {
      final snap = await FirebaseFirestore.instance
          .collection(_col)
          .where('userId', isEqualTo: uid)
          .where('yearMonthDay', isGreaterThanOrEqualTo: start)
          .where('yearMonthDay', isLessThanOrEqualTo: end)
          .get();
      return _entriesFromDocs(snap.docs);
    } catch (_) {
      final all = await FirebaseFirestore.instance
          .collection(_col)
          .where('userId', isEqualTo: uid)
          .get();
      return _entriesFromDocs(all.docs).where((entry) {
        final key = _dayKey(entry.date);
        return key.compareTo(start) >= 0 && key.compareTo(end) <= 0;
      }).toList();
    }
  }

  Future<void> refresh() => _watch();

  List<CashEntry> _entriesFromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.map((d) => CashEntry.fromMap(d.id, d.data())).toList()
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) return byDate;
        return a.createdAt.compareTo(b.createdAt);
      });
  }

  String _dayKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
}

final cashbookProvider =
    StateNotifierProvider.autoDispose<CashbookNotifier, CashbookState>(
  (ref) => CashbookNotifier(ref),
);
