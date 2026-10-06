import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/customer_entity.dart';

class CustomerModel extends CustomerEntity {
  const CustomerModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.phone,
    super.secondaryPhone,
    super.address,
    super.ledgerPurpose,
    super.notes,
    super.photoPath,
    required super.createdAt,
    super.updatedAt,
    super.balance,
    super.ownerName,
    super.ownerPhone,
    super.isDefaulter,
    super.defaulterNote,
    super.defaulterMarkedAt,
  });

  factory CustomerModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return CustomerModel(
      id: doc.id,
      userId: d['userId'] as String? ?? '',
      name: d['name'] as String? ?? '',
      phone: d['phone'] as String? ?? '',
      secondaryPhone: d['secondaryPhone'] as String?,
      address: d['address'] as String?,
      ledgerPurpose: d['ledgerPurpose'] as String?,
      notes: d['notes'] as String?,
      photoPath: d['photoPath'] as String?,
      balance: (d['balance'] as num?)?.toDouble() ?? 0.0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
      // Owner info for shared ledger display
      ownerName: d['ownerName'] as String?,
      ownerPhone: d['ownerPhone'] as String?,
      isDefaulter: d['isDefaulter'] as bool? ?? false,
      defaulterNote: d['defaulterNote'] as String?,
      defaulterMarkedAt: (d['defaulterMarkedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'phone': phone,
      if (secondaryPhone != null && secondaryPhone!.isNotEmpty)
        'secondaryPhone': secondaryPhone,
      if (address != null && address!.isNotEmpty) 'address': address,
      if (ledgerPurpose != null && ledgerPurpose!.isNotEmpty)
        'ledgerPurpose': ledgerPurpose,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      if (photoPath != null && photoPath!.isNotEmpty) 'photoPath': photoPath,
      if (ownerName != null && ownerName!.isNotEmpty) 'ownerName': ownerName,
      if (ownerPhone != null && ownerPhone!.isNotEmpty)
        'ownerPhone': ownerPhone,
      'balance': balance,
      'isDefaulter': isDefaulter,
      if (defaulterNote != null && defaulterNote!.isNotEmpty)
        'defaulterNote': defaulterNote,
      if (defaulterMarkedAt != null)
        'defaulterMarkedAt': Timestamp.fromDate(defaulterMarkedAt!),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'nameLower': name.toLowerCase(),
      'namePrefix': name.toLowerCase().isNotEmpty
          ? name.toLowerCase().substring(0, 1)
          : '',
    };
  }

  factory CustomerModel.fromEntity(CustomerEntity e) {
    return CustomerModel(
      id: e.id,
      userId: e.userId,
      name: e.name,
      phone: e.phone,
      secondaryPhone: e.secondaryPhone,
      address: e.address,
      ledgerPurpose: e.ledgerPurpose,
      notes: e.notes,
      photoPath: e.photoPath,
      createdAt: e.createdAt,
      updatedAt: e.updatedAt,
      balance: e.balance,
      ownerName: e.ownerName,
      ownerPhone: e.ownerPhone,
      isDefaulter: e.isDefaulter,
      defaulterNote: e.defaulterNote,
      defaulterMarkedAt: e.defaulterMarkedAt,
    );
  }

  @override
  CustomerModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? phone,
    String? secondaryPhone,
    String? address,
    String? ledgerPurpose,
    String? notes,
    String? photoPath,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? balance,
    String? ownerName,
    String? ownerPhone,
    bool? isDefaulter,
    String? defaulterNote,
    DateTime? defaulterMarkedAt,
    bool clearSecondaryPhone = false,
    bool clearAddress = false,
    bool clearLedgerPurpose = false,
    bool clearNotes = false,
    bool clearPhotoPath = false,
    bool clearDefaulterNote = false,
    bool clearDefaulterMarkedAt = false,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      secondaryPhone:
          clearSecondaryPhone ? null : secondaryPhone ?? this.secondaryPhone,
      address: clearAddress ? null : address ?? this.address,
      ledgerPurpose:
          clearLedgerPurpose ? null : ledgerPurpose ?? this.ledgerPurpose,
      notes: clearNotes ? null : notes ?? this.notes,
      photoPath: clearPhotoPath ? null : photoPath ?? this.photoPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      balance: balance ?? this.balance,
      ownerName: ownerName ?? this.ownerName,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      isDefaulter: isDefaulter ?? this.isDefaulter,
      defaulterNote:
          clearDefaulterNote ? null : defaulterNote ?? this.defaulterNote,
      defaulterMarkedAt: clearDefaulterMarkedAt
          ? null
          : defaulterMarkedAt ?? this.defaulterMarkedAt,
    );
  }

  /// Public, read-only ledger projection. Owner-private fields are omitted.
  Map<String, dynamic> toSharedLedgerFirestore() => {
        'userId': userId,
        'name': name,
        'phone': phone,
        'phoneE164': '+91$phone',
        if (address != null && address!.isNotEmpty) 'address': address,
        if (ledgerPurpose != null && ledgerPurpose!.isNotEmpty)
          'ledgerPurpose': ledgerPurpose,
        if (ownerName != null && ownerName!.isNotEmpty) 'ownerName': ownerName,
        if (ownerPhone != null && ownerPhone!.isNotEmpty)
          'ownerPhone': ownerPhone,
        'balance': balance,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
