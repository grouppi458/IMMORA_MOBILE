import 'package:sqflite/sqflite.dart';

import 'package:immora_mobile/module_authentification/models/user.dart';
import 'package:immora_mobile/module_authentification/services/password_service.dart';
import 'package:immora_mobile/core/utils/constants.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/validators.dart';
import 'package:immora_mobile/core/database/database_helper.dart';
import 'package:immora_mobile/module_authentification/repositories/activity_log_repository.dart';
import 'package:immora_mobile/module_gestion_agences/repositories/agency_repository.dart';
import 'package:immora_mobile/module_gestion_agences/repositories/subscription_repository.dart';
import 'package:immora_mobile/module_authentification/repositories/user_repository.dart';

/// Erreur métier affichée telle quelle à l'utilisateur.
class AuthException implements Exception {
  AuthException(this.message, {this.field});

  final String message;

  /// Champ concerné ('email'…) pour afficher l'erreur sous ce champ.
  final String? field;

  @override
  String toString() => message;
}

/// Données saisies dans le formulaire d'inscription.
class RegistrationData {
  RegistrationData({
    required this.role,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.password,
    this.agencyName,
    this.agencyCity,
    this.agencyAddress,
  });

  final UserRole role; // client, owner ou agency
  final String fullName;
  final String email;
  final String phone;
  final String password;
  final String? agencyName;
  final String? agencyCity;
  final String? agencyAddress;
}

class AuthRepository {
  final _users = UserRepository();
  final _agencies = AgencyRepository();
  final _subscriptions = SubscriptionRepository();
  final _logs = ActivityLogRepository();

  static const _badCredentials =
      'Email ou mot de passe incorrect. Vérifiez vos identifiants et réessayez.';

  /// BF1.6 — vérifie les identifiants puis l'état du compte et de l'agence.
  Future<User> login(String email, String password) async {
    final user = await _users.findByEmail(email);
    if (user == null ||
        !PasswordService.verify(password, user.passwordSalt, user.passwordHash)) {
      throw AuthException(_badCredentials);
    }
    await ensureCanAccess(user);

    await _users.updateLastLogin(user.id!);
    await _logs.logActivity(ActivityType.login, userId: user.id, agencyId: user.agencyId);
    return (await _users.findById(user.id!))!;
  }

  /// BF1.7 — refuse un compte désactivé, ou un compte agence / agent dont
  /// l'agence est suspendue ou dont l'abonnement est expiré (BF2.8).
  /// Appelée à la connexion ET à la restauration de session.
  Future<void> ensureCanAccess(User user) async {
    if (!user.isActive) {
      throw AuthException('Ce compte est désactivé. Contactez votre agence ou IMMORA.');
    }
    final agencyId = user.agencyId;
    if (agencyId != null &&
        (user.role == UserRole.agency || user.role == UserRole.agent)) {
      final agency = await _agencies.findById(agencyId);
      if (agency == null || !agency.isActive) {
        throw AuthException('Cette agence est désactivée. Contactez IMMORA.');
      }
      if (await _subscriptions.isAgencyBlocked(agencyId)) {
        throw AuthException(
            'L’abonnement de l’agence a expiré. Renouvelez-le pour accéder à IMMORA.');
      }
    }
  }

  /// BF1.1 — inscription libre (client, propriétaire ou agence). Pour une agence,
  /// l'agence et son abonnement Free d'essai sont créés dans la même transaction.
  Future<User> register(RegistrationData data) async {
    _validate(data);

    final email = data.email.trim().toLowerCase();
    if (await _users.emailExists(email)) {
      throw AuthException('Un compte existe déjà avec cet email', field: 'email');
    }

    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final phone = Validators.normalizePhone(data.phone);
    final fullName = data.fullName.trim().replaceAll(RegExp(r'\s+'), ' ');
    final salt = PasswordService.generateSalt();

    try {
      final userId = await db.transaction<int>((txn) async {
        int? agencyId;

        if (data.role == UserRole.agency) {
          agencyId = await txn.insert('agencies', {
            'name': data.agencyName!.trim(),
            'email': email,
            'phone': phone,
            'address': data.agencyAddress!.trim(),
            'city': data.agencyCity!.trim(),
            'isActive': 1,
            'createdAt': nowMs,
          });
          final free = planDefaults[SubscriptionPlan.free]!;
          await txn.insert('subscriptions', {
            'agencyId': agencyId,
            'plan': SubscriptionPlan.free.name,
            'monthlyPrice': free.monthlyPrice,
            'maxProperties': free.maxProperties,
            'maxAgents': free.maxAgents,
            'startDate': nowMs,
            'endDate': now.add(const Duration(days: freeTrialDays)).millisecondsSinceEpoch,
            'status': SubscriptionStatus.active.name,
          });
        }

        final user = User(
          agencyId: agencyId,
          fullName: fullName,
          email: email,
          phone: phone,
          passwordHash: PasswordService.hash(data.password, salt),
          passwordSalt: salt,
          role: data.role,
          createdAt: nowMs,
        );
        final id = await txn.insert('users', user.toMap()..remove('id'));
        return id;
      });
      return (await _users.findById(userId))!;
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw AuthException('Un compte existe déjà avec cet email', field: 'email');
      }
      rethrow;
    }
  }

  /// Contrôle serveur (en plus du formulaire) : on ne fait jamais confiance à l'UI.
  void _validate(RegistrationData d) {
    if (!{UserRole.client, UserRole.owner, UserRole.agency}.contains(d.role)) {
      throw AuthException('Ce type de compte ne peut pas être créé depuis l’application.');
    }
    final errors = [
      Validators.fullName(d.fullName),
      Validators.email(d.email),
      Validators.phone(d.phone),
      Validators.password(d.password),
      if (d.role == UserRole.agency) ...[
        Validators.agencyName(d.agencyName),
        Validators.city(d.agencyCity),
        Validators.address(d.agencyAddress),
      ],
    ].whereType<String>();
    if (errors.isNotEmpty) throw AuthException(errors.first);
  }
}
