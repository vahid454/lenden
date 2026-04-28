import 'package:equatable/equatable.dart';

/// Core customer domain entity — pure Dart, zero Firebase dependencies.
/// A "customer" in LenDen is any person/party the user lends to or borrows from.
class CustomerEntity extends Equatable {
  final String id;
  final String userId;       // owner of this record
  final String name;
  final String phone;
  final String? address;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// Running balance for this customer.
  /// Positive → they owe YOU (you gave money).
  /// Negative → YOU owe them (they gave money).
  final double balance;

  const CustomerEntity({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    this.address,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.balance = 0.0,
  });

  // ── Derived helpers ───────────────────────────────────────────────────────

  /// True when the customer owes the user money.
  bool get isCreditor => balance > 0;

  /// True when the user owes the customer money.
  bool get isDebtor => balance < 0;

  /// True when balance is exactly zero.
  bool get isSettled => balance == 0;

  /// Returns initials for avatar (e.g. "Rahul Sharma" → "RS").
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  /// Absolute value of balance — safe for display.
  double get absBalance => balance.abs();

  // ── CopyWith ──────────────────────────────────────────────────────────────

  CustomerEntity copyWith({
    String? id,
    String? userId,
    String? name,
    String? phone,
    String? address,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? balance,
  }) {
    return CustomerEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      balance: balance ?? this.balance,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        phone,
        address,
        notes,
        createdAt,
        updatedAt,
        balance,
      ];
}
