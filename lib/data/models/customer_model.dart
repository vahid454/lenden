import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/customer_entity.dart';

/// [CustomerModel] extends [CustomerEntity] and adds Firestore (de)serialization.
/// Lives only in the data layer — domain never imports this directly.
class CustomerModel extends CustomerEntity {
  const CustomerModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.phone,
    super.address,
    super.notes,
    required super.createdAt,
    super.updatedAt,
    super.balance,
  });

  // ── Firestore → Model ─────────────────────────────────────────────────────

  factory CustomerModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return CustomerModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      address: data['address'] as String?,
      notes: data['notes'] as String?,
      balance: (data['balance'] as num?)?.toDouble() ?? 0.0,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  // ── Model → Firestore ─────────────────────────────────────────────────────

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'phone': phone,
      if (address != null && address!.isNotEmpty) 'address': address,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      'balance': balance,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      // Lowercase name stored for efficient case-insensitive search
      'nameLower': name.toLowerCase(),
      // First letter for prefix-range queries
      'namePrefix': name.toLowerCase().substring(0, 1),
    };
  }

  // ── Entity → Model ────────────────────────────────────────────────────────

  factory CustomerModel.fromEntity(CustomerEntity entity) {
    return CustomerModel(
      id: entity.id,
      userId: entity.userId,
      name: entity.name,
      phone: entity.phone,
      address: entity.address,
      notes: entity.notes,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      balance: entity.balance,
    );
  }

  // ── CopyWith override ─────────────────────────────────────────────────────

  @override
  CustomerModel copyWith({
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
    return CustomerModel(
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
}
