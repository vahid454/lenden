import 'package:equatable/equatable.dart';

class CustomerEntity extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String phone;
  final String? address;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final double balance;

  /// The name of the person who created this customer record.
  /// Populated for shared ledger records so Y can see X's name.
  final String? ownerName;

  /// The phone of the person who created this customer record.
  final String? ownerPhone;

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
    this.ownerName,
    this.ownerPhone,
  });

  bool get isCreditor => balance > 0;
  bool get isDebtor   => balance < 0;
  bool get isSettled  => balance == 0;
  double get absBalance => balance.abs();

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  CustomerEntity copyWith({
    String? id, String? userId, String? name, String? phone,
    String? address, String? notes, DateTime? createdAt, DateTime? updatedAt,
    double? balance, String? ownerName, String? ownerPhone,
  }) {
    return CustomerEntity(
      id: id ?? this.id, userId: userId ?? this.userId,
      name: name ?? this.name, phone: phone ?? this.phone,
      address: address ?? this.address, notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
      balance: balance ?? this.balance,
      ownerName:  ownerName  ?? this.ownerName,
      ownerPhone: ownerPhone ?? this.ownerPhone,
    );
  }

  @override
  List<Object?> get props => [
    id, userId, name, phone, address, notes, createdAt, updatedAt, balance,
    ownerName, ownerPhone,
  ];
}
