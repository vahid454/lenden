import 'dart:math' as math;

import 'package:equatable/equatable.dart';

enum PaymentPromiseStatus { pending, partialPaid, paid, missed, rescheduled }

extension PaymentPromiseStatusX on PaymentPromiseStatus {
  String get firestoreValue => switch (this) {
        PaymentPromiseStatus.pending => 'pending',
        PaymentPromiseStatus.partialPaid => 'partialPaid',
        PaymentPromiseStatus.paid => 'paid',
        PaymentPromiseStatus.missed => 'missed',
        PaymentPromiseStatus.rescheduled => 'rescheduled',
      };

  String get label => switch (this) {
        PaymentPromiseStatus.pending => 'Pending',
        PaymentPromiseStatus.partialPaid => 'Partial paid',
        PaymentPromiseStatus.paid => 'Paid',
        PaymentPromiseStatus.missed => 'Missed',
        PaymentPromiseStatus.rescheduled => 'Rescheduled',
      };

  bool get isOpen =>
      this == PaymentPromiseStatus.pending ||
      this == PaymentPromiseStatus.partialPaid;

  static PaymentPromiseStatus fromString(String value) => switch (value) {
        'partialPaid' => PaymentPromiseStatus.partialPaid,
        'paid' => PaymentPromiseStatus.paid,
        'missed' => PaymentPromiseStatus.missed,
        'rescheduled' => PaymentPromiseStatus.rescheduled,
        _ => PaymentPromiseStatus.pending,
      };
}

class PaymentPromiseEntity extends Equatable {
  final String id;
  final String userId;
  final String customerId;
  final double amount;
  final double fulfilledAmount;
  final DateTime promisedDate;
  final PaymentPromiseStatus status;
  final String? note;
  final DateTime? lastContactedAt;
  final String? followUpNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PaymentPromiseEntity({
    required this.id,
    required this.userId,
    required this.customerId,
    required this.amount,
    this.fulfilledAmount = 0,
    required this.promisedDate,
    this.status = PaymentPromiseStatus.pending,
    this.note,
    this.lastContactedAt,
    this.followUpNote,
    required this.createdAt,
    required this.updatedAt,
  });

  double get remainingAmount => math.max(0, amount - fulfilledAmount);
  bool get isOpen => status.isOpen;
  bool get isPaid => status == PaymentPromiseStatus.paid;

  bool isDueOn(DateTime day) {
    final due = _dateOnly(promisedDate);
    return due == _dateOnly(day);
  }

  bool isOverdue(DateTime now) =>
      isOpen && promisedDate.isBefore(_dateOnly(now));

  bool isDueThisWeek(DateTime now) {
    final start = _dateOnly(now);
    final end = start.add(const Duration(days: 6));
    final due = _dateOnly(promisedDate);
    return isOpen && !due.isBefore(start) && !due.isAfter(end);
  }

  PaymentPromiseEntity copyWith({
    String? id,
    String? userId,
    String? customerId,
    double? amount,
    double? fulfilledAmount,
    DateTime? promisedDate,
    PaymentPromiseStatus? status,
    String? note,
    DateTime? lastContactedAt,
    String? followUpNote,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearNote = false,
    bool clearLastContactedAt = false,
    bool clearFollowUpNote = false,
  }) =>
      PaymentPromiseEntity(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        customerId: customerId ?? this.customerId,
        amount: amount ?? this.amount,
        fulfilledAmount: fulfilledAmount ?? this.fulfilledAmount,
        promisedDate: promisedDate ?? this.promisedDate,
        status: status ?? this.status,
        note: clearNote ? null : note ?? this.note,
        lastContactedAt: clearLastContactedAt
            ? null
            : lastContactedAt ?? this.lastContactedAt,
        followUpNote:
            clearFollowUpNote ? null : followUpNote ?? this.followUpNote,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  List<Object?> get props => [
        id,
        userId,
        customerId,
        amount,
        fulfilledAmount,
        promisedDate,
        status,
        note,
        lastContactedAt,
        followUpNote,
        createdAt,
        updatedAt,
      ];
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
