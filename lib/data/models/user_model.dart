import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/user_entity.dart';

/// [UserModel] extends [UserEntity] and adds Firestore serialization.
/// The domain layer only knows about [UserEntity]; models live in the data layer.
class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.name,
    required super.phone,
    super.email,
    super.businessName,
    super.photoUrl,
    required super.createdAt,
  });

  // ── Firestore → Model ─────────────────────────────────────────────────────

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return UserModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      email: data['email'] as String?,
      businessName: data['businessName'] as String?,
      photoUrl: data['photoUrl'] as String?,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory UserModel.fromMap(String id, Map<String, dynamic> data) {
    return UserModel(
      id: id,
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      email: data['email'] as String?,
      businessName: data['businessName'] as String?,
      photoUrl: data['photoUrl'] as String?,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // ── Model → Firestore ─────────────────────────────────────────────────────

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'phone': phone,
      if (email != null && email!.isNotEmpty) 'email': email,
      if (businessName != null) 'businessName': businessName,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      // Lowercase name for client-side search (Phase 2)
      'nameLower': name.toLowerCase(),
    };
  }

  // ── Entity → Model ────────────────────────────────────────────────────────

  factory UserModel.fromEntity(UserEntity entity) {
    return UserModel(
      id: entity.id,
      name: entity.name,
      phone: entity.phone,
      email: entity.email,
      businessName: entity.businessName,
      photoUrl: entity.photoUrl,
      createdAt: entity.createdAt,
    );
  }
}
