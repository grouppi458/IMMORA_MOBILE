import 'package:sqflite/sqflite.dart';

import 'package:immora_mobile/module_authentification/services/password_service.dart';
import 'package:immora_mobile/core/utils/constants.dart';
import 'package:immora_mobile/core/utils/enums.dart';

/// Données de démonstration insérées à la création de la base.
/// Tous les comptes utilisent le mot de passe [demoPassword].
class DemoData {
  DemoData._();

  static Future<void> seed(Database db) async {
    final now = DateTime.now();
    int ago(int days) => now.subtract(Duration(days: days)).millisecondsSinceEpoch;
    int ahead(int days) => now.add(Duration(days: days)).millisecondsSinceEpoch;

    Map<String, dynamic> user(String name, String email, String phone,
        UserRole role, int? agencyId,
        {bool active = true, int? lastLogin}) {
      final salt = PasswordService.generateSalt();
      return {
        'agencyId': agencyId,
        'fullName': name,
        'email': email,
        'phone': phone,
        'passwordHash': PasswordService.hash(demoPassword, salt),
        'passwordSalt': salt,
        'role': role.name,
        'isActive': active ? 1 : 0,
        'createdAt': ago(200),
        'lastLoginAt': lastLogin,
      };
    }

    Future<void> subscription(Transaction txn, int agencyId, SubscriptionPlan plan,
        int start, int end, SubscriptionStatus status) async {
      final d = planDefaults[plan]!;
      await txn.insert('subscriptions', {
        'agencyId': agencyId,
        'plan': plan.name,
        'monthlyPrice': d.monthlyPrice,
        'maxProperties': d.maxProperties,
        'maxAgents': d.maxAgents,
        'startDate': start,
        'endDate': end,
        'status': status.name,
      });
    }

    /// Journal d'activité réparti sur [spanDays] jours, en finissant il y a [lastDaysAgo] jours.
    Future<void> logs(Transaction txn, int userId, int agencyId, ActivityType type,
        int count, {int lastDaysAgo = 0, int spanDays = 28}) async {
      for (var i = 0; i < count; i++) {
        final day = lastDaysAgo + (count == 1 ? 0 : (i * spanDays) ~/ count);
        await txn.insert('activity_logs', {
          'userId': userId,
          'agencyId': agencyId,
          'type': type.name,
          'details': 'démo',
          'timestamp': ago(day) - i * 3600 * 1000,
        });
      }
    }

    await db.transaction((txn) async {
      await txn.insert('users',
          user('Admin IMMORA', 'admin@immora.tn', '+21620000000', UserRole.admin, null,
              lastLogin: ago(0)));

      // 1. Carthage Immobilier — Premium, très active
      final carthage = await txn.insert('agencies', {
        'name': 'Carthage Immobilier', 'email': 'agence@immora.tn',
        'phone': '+21671080080', 'address': 'Les Berges du Lac', 'city': 'Tunis',
        'isActive': 1, 'createdAt': ago(240),
      });
      await subscription(txn, carthage, SubscriptionPlan.premium, ago(170), ahead(190),
          SubscriptionStatus.active);
      final carthageUser = await txn.insert('users',
          user('Mohamed Karray', 'agence@immora.tn', '+21671080080', UserRole.agency, carthage,
              lastLogin: ago(0)));
      for (final a in [
        ('Sami Ben Ali', 'agent@immora.tn', '+21622111222', 'vente', 0.03, true),
        ('Sirine Ben Salah', 'sirine@carthage-immo.tn', '+21698123456', 'vente', 0.03, true),
        ('Ahmed Ghorbi', 'ahmed@carthage-immo.tn', '+21655222333', 'luxe', 0.04, true),
        ('Leila Mansour', 'leila@carthage-immo.tn', '+21629444555', 'location', 0.025, false),
      ]) {
        final id = await txn.insert('users',
            user(a.$1, a.$2, a.$3, UserRole.agent, carthage, active: a.$6, lastLogin: ago(1)));
        await txn.insert('agents', {
          'userId': id, 'agencyId': carthage, 'speciality': a.$4,
          'commissionRate': a.$5, 'hireDate': ago(300),
        });
      }
      await logs(txn, carthageUser, carthage, ActivityType.login, 18);
      await logs(txn, carthageUser, carthage, ActivityType.propertyAdded, 8);
      await logs(txn, carthageUser, carthage, ActivityType.clientAdded, 6);

      // 2. Lac Property — Basic, activité moyenne
      final lac = await txn.insert('agencies', {
        'name': 'Lac Property', 'email': 'contact@lacproperty.tn',
        'phone': '+21671222333', 'address': 'Rue du Lac Biwa', 'city': 'Tunis',
        'isActive': 1, 'createdAt': ago(150),
      });
      await subscription(txn, lac, SubscriptionPlan.basic, ago(120), ahead(60),
          SubscriptionStatus.active);
      final lacUser = await txn.insert('users',
          user('Nour Haddad', 'contact@lacproperty.tn', '+21671222333', UserRole.agency, lac,
              lastLogin: ago(2)));
      await logs(txn, lacUser, lac, ActivityType.login, 10, lastDaysAgo: 2);
      await logs(txn, lacUser, lac, ActivityType.propertyAdded, 4, lastDaysAgo: 3);
      await logs(txn, lacUser, lac, ActivityType.clientAdded, 3, lastDaysAgo: 5);

      // 3. Gammarth Luxury — Premium, très active, créée ce mois-ci
      final gammarth = await txn.insert('agencies', {
        'name': 'Gammarth Luxury', 'email': 'hello@gammarth-luxury.tn',
        'phone': '+21671999888', 'address': 'Route de la Corniche', 'city': 'La Marsa',
        'isActive': 1, 'createdAt': ago(now.day > 1 ? now.day - 1 : 0),
      });
      await subscription(txn, gammarth, SubscriptionPlan.premium, ago(75), ahead(100),
          SubscriptionStatus.active);
      final gammarthUser = await txn.insert('users',
          user('Karim Jaziri', 'hello@gammarth-luxury.tn', '+21671999888', UserRole.agency,
              gammarth, lastLogin: ago(0)));
      await logs(txn, gammarthUser, gammarth, ActivityType.login, 20);
      await logs(txn, gammarthUser, gammarth, ActivityType.propertyAdded, 9);
      await logs(txn, gammarthUser, gammarth, ActivityType.clientAdded, 7);

      // 4. Sahel Estates — Basic expiré, activité faible
      final sahel = await txn.insert('agencies', {
        'name': 'Sahel Estates', 'email': 'info@sahel-estates.tn',
        'phone': '+21673555666', 'address': 'Boulevard du 14 Janvier', 'city': 'Sousse',
        'isActive': 1, 'createdAt': ago(260),
      });
      await subscription(txn, sahel, SubscriptionPlan.basic, ago(210), ago(12),
          SubscriptionStatus.expired);
      final sahelUser = await txn.insert('users',
          user('Hela Trabelsi', 'info@sahel-estates.tn', '+21673555666', UserRole.agency, sahel,
              lastLogin: ago(12)));
      await logs(txn, sahelUser, sahel, ActivityType.login, 5, lastDaysAgo: 12, spanDays: 16);
      await logs(txn, sahelUser, sahel, ActivityType.propertyAdded, 1, lastDaysAgo: 20);

      // 5. Medina Realty — Free, suspendue, inactive depuis 34 jours
      final medina = await txn.insert('agencies', {
        'name': 'Medina Realty', 'email': 'medina.realty@gmail.com',
        'phone': '+21671333444', 'address': 'Souk El Attarine', 'city': 'Tunis',
        'isActive': 0, 'createdAt': ago(100),
      });
      await subscription(txn, medina, SubscriptionPlan.free, ago(40), ahead(20),
          SubscriptionStatus.active);
      final medinaUser = await txn.insert('users',
          user('Rami Chaabane', 'medina.realty@gmail.com', '+21671333444', UserRole.agency,
              medina, lastLogin: ago(34)));
      await logs(txn, medinaUser, medina, ActivityType.login, 2, lastDaysAgo: 34, spanDays: 6);

      // Client et propriétaire
      await txn.insert('users',
          user('Yassine Trabelsi', 'client@immora.tn', '+21655333444', UserRole.client, null,
              lastLogin: ago(1)));
      await txn.insert('users', {
        ...user('Rania Nasri', 'proprietaire@immora.tn', '+21698555666', UserRole.owner, null,
            lastLogin: ago(5)),
        'cin': '08123456', // profil propriétaire (BF1.2)
        'address': '12 rue de Marseille, Tunis',
      });
    });
  }
}
