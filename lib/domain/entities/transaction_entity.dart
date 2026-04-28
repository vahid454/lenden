import 'package:equatable/equatable.dart';

/// Represents a single money movement between the user and a customer.
///
/// Balance convention (always from the USER's perspective):
///   [TransactionType.gave] → user gave money → balance goes UP (customer owes more)
///   [TransactionType.got]  → user got money  → balance goes DOWN (customer owes less)
enum TransactionType { gave, got }

extension TransactionTypeX on TransactionType {
  String get label => this == TransactionType.gave ? 'You Gave' : 'You Got';
  String get firestoreValue => this == TransactionType.gave ? 'gave' : 'got';

  static TransactionType fromString(String s) =>
      s == 'gave' ? TransactionType.gave : TransactionType.got;
}

class TransactionEntity extends Equatable {
  final String id;
  final String customerId;
  final String userId;
  final double amount;
  final TransactionType type;
  final String? note;
  final DateTime date;       // user-visible date (editable)
  final DateTime createdAt;  // immutable server timestamp

  const TransactionEntity({
    required this.id,
    required this.customerId,
    required this.userId,
    required this.amount,
    required this.type,
    this.note,
    required this.date,
    required this.createdAt,
  });

  // ── Derived helpers ───────────────────────────────────────────────────────

  bool get isGave => type == TransactionType.gave;
  bool get isGot  => type == TransactionType.got;

  /// The signed delta this transaction applies to the customer balance.
  /// Gave → +amount (they owe more), Got → -amount (they owe less).
  double get balanceDelta => isGave ? amount : -amount;

  TransactionEntity copyWith({
    String? id,
    String? customerId,
    String? userId,
    double? amount,
    TransactionType? type,
    String? note,
    DateTime? date,
    DateTime? createdAt,
  }) {
    return TransactionEntity(
      id:          id          ?? this.id,
      customerId:  customerId  ?? this.customerId,
      userId:      userId      ?? this.userId,
      amount:      amount      ?? this.amount,
      type:        type        ?? this.type,
      note:        note        ?? this.note,
      date:        date        ?? this.date,
      createdAt:   createdAt   ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, customerId, userId, amount, type, note, date, createdAt];
}
