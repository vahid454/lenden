import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/transaction_entity.dart';

/// Extends [TransactionEntity] with Firestore (de)serialization.
/// Only the data layer uses this — domain sees [TransactionEntity].
class TransactionModel extends TransactionEntity {
  const TransactionModel({
    required super.id,
    required super.customerId,
    required super.userId,
    required super.amount,
    required super.type,
    super.note,
    required super.date,
    required super.createdAt,
  });

  // ── Firestore → Model ─────────────────────────────────────────────────────

  factory TransactionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data()!;
    return TransactionModel(
      id:         doc.id,
      customerId: d['customerId'] as String? ?? '',
      userId:     d['userId']     as String? ?? '',
      amount:     (d['amount']    as num?)?.toDouble() ?? 0.0,
      type:       TransactionTypeX.fromString(d['type'] as String? ?? 'gave'),
      note:       d['note']       as String?,
      date:       (d['date']      as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt:  (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // ── Model → Firestore ─────────────────────────────────────────────────────

  Map<String, dynamic> toFirestore() => {
    'customerId': customerId,
    'userId':     userId,
    'amount':     amount,
    'type':       type.firestoreValue,
    if (note != null && note!.isNotEmpty) 'note': note,
    'date':       Timestamp.fromDate(date),
    'createdAt':  Timestamp.fromDate(createdAt),
    // Store year-month for efficient monthly report queries
    'yearMonth':  '${date.year}-${date.month.toString().padLeft(2, '0')}',
  };

  // ── Entity → Model ────────────────────────────────────────────────────────

  factory TransactionModel.fromEntity(TransactionEntity e) => TransactionModel(
    id:         e.id,
    customerId: e.customerId,
    userId:     e.userId,
    amount:     e.amount,
    type:       e.type,
    note:       e.note,
    date:       e.date,
    createdAt:  e.createdAt,
  );

  @override
  TransactionModel copyWith({
    String?          id,
    String?          customerId,
    String?          userId,
    double?          amount,
    TransactionType? type,
    String?          note,
    DateTime?        date,
    DateTime?        createdAt,
  }) =>
      TransactionModel(
        id:         id         ?? this.id,
        customerId: customerId ?? this.customerId,
        userId:     userId     ?? this.userId,
        amount:     amount     ?? this.amount,
        type:       type       ?? this.type,
        note:       note       ?? this.note,
        date:       date       ?? this.date,
        createdAt:  createdAt  ?? this.createdAt,
      );
}
