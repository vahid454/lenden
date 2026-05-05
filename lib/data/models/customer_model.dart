import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/customer_entity.dart';

class CustomerModel extends CustomerEntity {
  const CustomerModel({
    required super.id, required super.userId,
    required super.name, required super.phone,
    super.address, super.notes, required super.createdAt,
    super.updatedAt, super.balance,
    super.ownerName, super.ownerPhone,
  });

  factory CustomerModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return CustomerModel(
      id:         doc.id,
      userId:     d['userId']     as String? ?? '',
      name:       d['name']       as String? ?? '',
      phone:      d['phone']      as String? ?? '',
      address:    d['address']    as String?,
      notes:      d['notes']      as String?,
      balance:    (d['balance']   as num?)?.toDouble() ?? 0.0,
      createdAt:  (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:  (d['updatedAt'] as Timestamp?)?.toDate(),
      // Owner info for shared ledger display
      ownerName:  d['ownerName']  as String?,
      ownerPhone: d['ownerPhone'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId':     userId,
      'name':       name,
      'phone':      phone,
      if (address   != null && address!.isNotEmpty)   'address': address,
      if (notes     != null && notes!.isNotEmpty)     'notes': notes,
      if (ownerName != null && ownerName!.isNotEmpty) 'ownerName': ownerName,
      if (ownerPhone!= null && ownerPhone!.isNotEmpty)'ownerPhone': ownerPhone,
      'balance':    balance,
      'createdAt':  Timestamp.fromDate(createdAt),
      'updatedAt':  FieldValue.serverTimestamp(),
      'nameLower':  name.toLowerCase(),
      'namePrefix': name.toLowerCase().isNotEmpty
                    ? name.toLowerCase().substring(0, 1)
                    : '',
    };
  }

  factory CustomerModel.fromEntity(CustomerEntity e) {
    return CustomerModel(
      id: e.id, userId: e.userId, name: e.name, phone: e.phone,
      address: e.address, notes: e.notes, createdAt: e.createdAt,
      updatedAt: e.updatedAt, balance: e.balance,
      ownerName: e.ownerName, ownerPhone: e.ownerPhone,
    );
  }

  @override
  CustomerModel copyWith({
    String? id, String? userId, String? name, String? phone,
    String? address, String? notes, DateTime? createdAt, DateTime? updatedAt,
    double? balance, String? ownerName, String? ownerPhone,
  }) {
    return CustomerModel(
      id: id ?? this.id, userId: userId ?? this.userId,
      name: name ?? this.name, phone: phone ?? this.phone,
      address: address ?? this.address, notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
      balance: balance ?? this.balance,
      ownerName:  ownerName  ?? this.ownerName,
      ownerPhone: ownerPhone ?? this.ownerPhone,
    );
  }
}
