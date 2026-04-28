import 'package:equatable/equatable.dart';

/// Core user domain entity — pure Dart, no Firebase imports.
class UserEntity extends Equatable {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? businessName;
  final String? photoUrl;
  final DateTime createdAt;

  const UserEntity({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.businessName,
    this.photoUrl,
    required this.createdAt,
  });

  /// Display name with optional business appended
  String get displayName =>
      businessName != null && businessName!.isNotEmpty ? '$name ($businessName)' : name;

  /// Returns initials for avatar fallback (e.g. "Rahul Sharma" → "RS")
  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  UserEntity copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? businessName,
    String? photoUrl,
    DateTime? createdAt,
  }) {
    return UserEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      businessName: businessName ?? this.businessName,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, phone, email, businessName, photoUrl, createdAt];
}
