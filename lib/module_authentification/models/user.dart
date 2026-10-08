import 'package:immora_mobile/core/utils/enums.dart';

/// Un compte de la table `users`. Admin, agence, agent, client et
/// propriétaire sont tous des rôles de cette même table (BF1.1).
class User {
  final int? id;
  final int? agencyId; // null pour admin, client et propriétaire indépendants
  final String fullName;
  final String email;
  final String phone;
  final String passwordHash;
  final String passwordSalt;
  final UserRole role;
  final bool isActive;
  final int createdAt;
  final int? lastLoginAt;
  final String? cin; // profil propriétaire (BF1.2)
  final String? address; // profil propriétaire (BF1.2)

  User({
    this.id,
    this.agencyId,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.passwordHash,
    required this.passwordSalt,
    required this.role,
    this.isActive = true,
    required this.createdAt,
    this.lastLoginAt,
    this.cin,
    this.address,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'agencyId': agencyId,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'passwordHash': passwordHash,
        'passwordSalt': passwordSalt,
        'role': role.name,
        'isActive': isActive ? 1 : 0,
        'createdAt': createdAt,
        'lastLoginAt': lastLoginAt,
        'cin': cin,
        'address': address,
      };

  factory User.fromMap(Map<String, dynamic> m) => User(
        id: m['id'],
        agencyId: m['agencyId'],
        fullName: m['fullName'],
        email: m['email'],
        phone: m['phone'] ?? '',
        passwordHash: m['passwordHash'],
        passwordSalt: m['passwordSalt'],
        role: UserRole.values.byName(m['role']),
        isActive: m['isActive'] == 1,
        createdAt: m['createdAt'],
        lastLoginAt: m['lastLoginAt'],
        cin: m['cin'],
        address: m['address'],
      );
}
