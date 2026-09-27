import 'package:sqflite/sqflite.dart';

import '../services/password_service.dart';
import '../utils/constants.dart';
import '../utils/enums.dart';

/// Données de démonstration insérées à la création de la base.
/// Tous les comptes utilisent le mot de passe [demoPassword].
class DemoData {
  DemoData._();

  static Future<void> seed(Database db) async {
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;

    Map<String, dynamic> user(String name, String email, String phone,
        UserRole role, int? agencyId) {
      final salt = PasswordService.generateSalt();
      return {
        'agencyId': agencyId,
        'fullName': name,
        'email': email,
        'phone': phone,
        'passwordHash': PasswordService.hash(demoPassword, salt),
        'passwordSalt': salt,
        'role': role.name,
        'isActive': 1,
        'createdAt': nowMs,
      };
    }

    await db.transaction((txn) async {
      final agencyId = await txn.insert('agencies', {
        'name': 'IMMORA Démo',
        'email': 'agence@immora.tn',
        'phone': '+21671000000',
        'address': '12 avenue Habib Bourguiba',
        'city': 'Tunis',
        'isActive': 1,
        'createdAt': nowMs,
      });

      final premium = planDefaults[SubscriptionPlan.premium]!;
      await txn.insert('subscriptions', {
        'agencyId': agencyId,
        'plan': SubscriptionPlan.premium.name,
        'monthlyPrice': premium.monthlyPrice,
        'maxProperties': premium.maxProperties,
        'maxAgents': premium.maxAgents,
        'startDate': nowMs,
        'endDate': now.add(const Duration(days: 365)).millisecondsSinceEpoch,
        'status': SubscriptionStatus.active.name,
      });

      await txn.insert('users',
          user('Admin IMMORA', 'admin@immora.tn', '+21620000000', UserRole.admin, null));
      await txn.insert('users',
          user('Agence Démo', 'agence@immora.tn', '+21671000000', UserRole.agency, agencyId));

      final agentUserId = await txn.insert('users',
          user('Sami Ben Ali', 'agent@immora.tn', '+21622111222', UserRole.agent, agencyId));
      await txn.insert('agents', {
        'userId': agentUserId,
        'agencyId': agencyId,
        'speciality': 'vente',
        'commissionRate': 0.03,
        'hireDate': nowMs,
      });

      final clientUserId = await txn.insert('users',
          user('Yassine Trabelsi', 'client@immora.tn', '+21655333444', UserRole.client, null));
      await txn.insert('clients', {
        'userId': clientUserId,
        'fullName': 'Yassine Trabelsi',
        'phone': '+21655333444',
        'email': 'client@immora.tn',
        'createdAt': nowMs,
      });

      await txn.insert('users',
          user('Leila Gharbi', 'proprietaire@immora.tn', '+21698555666', UserRole.owner, null));
    });
  }
}
