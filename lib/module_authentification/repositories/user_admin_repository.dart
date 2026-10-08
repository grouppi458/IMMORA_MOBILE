import 'package:sqflite/sqflite.dart';

import 'package:immora_mobile/core/database/database_helper.dart';
import 'package:immora_mobile/core/database/db_inspector.dart';
import 'package:immora_mobile/core/errors/app_exception.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/validators.dart';
import 'package:immora_mobile/module_authentification/models/agent.dart';
import 'package:immora_mobile/module_authentification/models/agent_with_user.dart';
import 'package:immora_mobile/module_authentification/models/user.dart';
import 'package:immora_mobile/module_authentification/services/password_service.dart';
import 'package:immora_mobile/module_gestion_agences/repositories/subscription_repository.dart';

/// Résultat d'une demande de suppression (BF1.5).
enum DeleteOutcome { deleted, deactivated }

/// Gestion des utilisateurs par l'admin ou l'agence (Module 1, BF1.1 à BF1.5).
class UserAdminRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;
  final _subscriptions = SubscriptionRepository();

  /// Tables des autres modules qui pointent vers users.id : si une ligne existe,
  /// l'utilisateur est désactivé au lieu d'être supprimé.
  static const _userLinks = [
    ('properties', 'ownerId'),
    ('visits', 'clientId'),
    ('transactions', 'clientId'),
  ];

  /// Tables qui pointent vers agents.id.
  static const _agentLinks = [
    ('properties', 'agentId'),
    ('visits', 'agentId'),
    ('transactions', 'agentId'),
  ];

  // ---------------------------------------------------------------- Lecture

  /// BF1.3 — liste filtrée par rôle et par agence, les plus récemment connectés d'abord.
  Future<List<User>> users({UserRole? role, int? agencyId}) async {
    final where = <String>[];
    final args = <Object>[];
    if (role != null) {
      where.add('role = ?');
      args.add(role.name);
    }
    if (agencyId != null) {
      where.add('agencyId = ?');
      args.add(agencyId);
    }
    final rows = await (await _db).query(
      'users',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'lastLoginAt IS NULL, lastLoginAt DESC, fullName',
    );
    return rows.map(User.fromMap).toList();
  }

  /// Agents d'une agence avec leur compte (jointure agents ⋈ users).
  Future<List<AgentWithUser>> agentsOfAgency(int agencyId) async {
    final rows = await (await _db).rawQuery(
      'SELECT u.*, ag.id AS agentId, ag.agencyId AS agentAgencyId, ag.speciality, '
      'ag.commissionRate, ag.hireDate FROM agents ag JOIN users u ON u.id = ag.userId '
      'WHERE ag.agencyId = ? ORDER BY u.fullName',
      [agencyId],
    );
    return rows.map(_agentFromRow).toList();
  }

  static AgentWithUser _agentFromRow(Map<String, Object?> r) => AgentWithUser(
        user: User.fromMap(r),
        agent: Agent(
          id: r['agentId'] as int,
          userId: r['id'] as int,
          agencyId: r['agentAgencyId'] as int,
          speciality: r['speciality'] as String?,
          commissionRate: (r['commissionRate'] as num).toDouble(),
          hireDate: (r['hireDate'] as int?) ?? 0,
        ),
      );

  // ---------------------------------------------------------- Utilisateurs

  /// BF1.1 / BF1.2 / BF1.4 — crée ou modifie un compte (hors agents, gérés
  /// par [saveAgent]). Renvoie le mot de passe temporaire à la création, sinon null.
  Future<String?> saveUser({
    User? existing,
    required String fullName,
    required String email,
    required String phone,
    required UserRole role,
    int? agencyId,
    String? cin,
    String? address,
    required bool isActive,
  }) async {
    _check([
      Validators.fullName(fullName),
      Validators.email(email),
      Validators.phone(phone),
      if (role == UserRole.owner) ...[
        Validators.cin(cin),
        Validators.address(address),
      ],
    ]);
    if (role == UserRole.agent && existing?.role != UserRole.agent) {
      throw AdminException('Un agent se crée depuis la fiche de son agence.');
    }
    if (existing?.role == UserRole.agent && role != UserRole.agent) {
      throw AdminException('Le rôle d’un agent ne peut pas être changé : supprimez-le de l’agence.');
    }
    if (role == UserRole.agency && agencyId == null) {
      throw AdminException('Choisissez l’agence de ce compte.', field: 'agency');
    }
    final cleanEmail = email.trim().toLowerCase();
    await _ensureUserEmailFree(cleanEmail, exceptUserId: existing?.id);

    // BF2.8 : réactiver un agent depuis la liste des utilisateurs respecte aussi le plan.
    if (existing != null &&
        existing.role == UserRole.agent &&
        isActive &&
        !existing.isActive &&
        existing.agencyId != null) {
      await _ensureAgentQuota(existing.agencyId!);
    }

    final db = await _db;
    final isOwner = role == UserRole.owner;
    final fields = <String, Object?>{
      'fullName': _cleanName(fullName),
      'email': cleanEmail,
      'phone': Validators.normalizePhone(phone),
      'role': role.name, // BF1.4 : changement de rôle
      'isActive': isActive ? 1 : 0,
      'cin': isOwner ? cin!.trim() : null,
      'address': isOwner ? address!.trim() : null,
      // Seuls les comptes agence et agent sont rattachés à une agence.
      if (role != UserRole.agent) 'agencyId': role == UserRole.agency ? agencyId : null,
    };

    if (existing != null) {
      await db.update('users', fields, where: 'id = ?', whereArgs: [existing.id]);
      return null;
    }

    final tempPassword = PasswordService.generateTemporaryPassword();
    final salt = PasswordService.generateSalt();
    await db.insert('users', {
      ...fields,
      'passwordHash': PasswordService.hash(tempPassword, salt),
      'passwordSalt': salt,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    return tempPassword;
  }

  /// BF1.5 — supprime le compte, ou le désactive s'il est lié à des biens,
  /// visites ou transactions (pour garder l'historique).
  Future<DeleteOutcome> deleteUser(User user, {required int currentUserId}) async {
    if (user.id == currentUserId) {
      throw AdminException('Vous ne pouvez pas supprimer votre propre compte.');
    }
    final db = await _db;
    if (user.role == UserRole.admin && user.isActive) {
      final admins = Sqflite.firstIntValue(await db.rawQuery(
              "SELECT COUNT(*) FROM users WHERE role = 'admin' AND isActive = 1")) ??
          0;
      if (admins <= 1) throw AdminException('Il doit rester au moins un administrateur actif.');
    }

    final agentRows =
        await db.query('agents', columns: ['id'], where: 'userId = ?', whereArgs: [user.id]);
    final agentId = agentRows.isEmpty ? null : agentRows.first['id'] as int;

    var links = 0;
    for (final (table, column) in _userLinks) {
      links += await DbInspector.countWhere(db, table, column, user.id!);
    }
    if (agentId != null) {
      for (final (table, column) in _agentLinks) {
        links += await DbInspector.countWhere(db, table, column, agentId);
      }
    }

    if (links > 0) {
      await db.update('users', {'isActive': 0}, where: 'id = ?', whereArgs: [user.id]);
      return DeleteOutcome.deactivated;
    }

    await db.transaction((txn) async {
      // Suppressions explicites : les bases créées en v1 n'ont pas ON DELETE CASCADE.
      await txn.delete('activity_logs', where: 'userId = ?', whereArgs: [user.id]);
      await txn.delete('agents', where: 'userId = ?', whereArgs: [user.id]);
      if (await DbInspector.hasColumn(txn, 'favorites', 'clientId')) {
        await txn.delete('favorites', where: 'clientId = ?', whereArgs: [user.id]);
      }
      await txn.delete('users', where: 'id = ?', whereArgs: [user.id]);
    });
    return DeleteOutcome.deleted;
  }

  // ---------------------------------------------------------------- Agents

  /// BF1.1 / BF1.2 — crée (existing == null) ou modifie un agent et sa fiche
  /// (spécialité, commission, date d'embauche).
  /// Renvoie le mot de passe temporaire à la création, sinon null.
  Future<String?> saveAgent({
    AgentWithUser? existing,
    required int agencyId,
    required String fullName,
    required String email,
    required String phone,
    required String speciality,
    required String commissionPercent,
    required DateTime hireDate,
    required bool isActive,
  }) async {
    _check([
      Validators.fullName(fullName),
      Validators.email(email),
      Validators.phone(phone),
      Validators.commissionPercent(commissionPercent),
    ]);
    if (!agentSpecialities.containsKey(speciality)) {
      throw AdminException('Choisissez une spécialité.');
    }
    final cleanEmail = email.trim().toLowerCase();
    await _ensureUserEmailFree(cleanEmail, exceptUserId: existing?.user.id);

    // BF2.8 : limite du plan sur le nombre d'agents actifs.
    final becomesActive = isActive && (existing == null || !existing.user.isActive);
    if (becomesActive) await _ensureAgentQuota(agencyId);

    final db = await _db;
    final rate = Validators.parsePercent(commissionPercent) / 100;
    final userFields = {
      'fullName': _cleanName(fullName),
      'email': cleanEmail,
      'phone': Validators.normalizePhone(phone),
      'isActive': isActive ? 1 : 0,
    };
    final agentFields = {
      'speciality': speciality,
      'commissionRate': rate,
      'hireDate': hireDate.millisecondsSinceEpoch,
    };

    if (existing != null) {
      await db.transaction((txn) async {
        await txn.update('users', userFields, where: 'id = ?', whereArgs: [existing.user.id]);
        await txn.update('agents', agentFields, where: 'id = ?', whereArgs: [existing.agent.id]);
      });
      return null;
    }

    final tempPassword = PasswordService.generateTemporaryPassword();
    final salt = PasswordService.generateSalt();
    await db.transaction((txn) async {
      final userId = await txn.insert('users', {
        ...userFields,
        'agencyId': agencyId,
        'passwordHash': PasswordService.hash(tempPassword, salt),
        'passwordSalt': salt,
        'role': UserRole.agent.name,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      await txn.insert('agents', {...agentFields, 'userId': userId, 'agencyId': agencyId});
    });
    return tempPassword;
  }

  // ---------------------------------------------------------------- Règles

  static String _cleanName(String name) => name.trim().replaceAll(RegExp(r'\s+'), ' ');

  void _check(List<String?> errors) {
    final first = errors.whereType<String>().firstOrNull;
    if (first != null) throw AdminException(first);
  }

  Future<void> _ensureUserEmailFree(String email, {int? exceptUserId}) async {
    final rows = await (await _db).query('users',
        columns: ['id'],
        where: exceptUserId == null ? 'email = ?' : 'email = ? AND id != ?',
        whereArgs: exceptUserId == null ? [email] : [email, exceptUserId]);
    if (rows.isNotEmpty) {
      throw AdminException('Cet email est déjà utilisé par un autre compte', field: 'email');
    }
  }

  Future<void> _ensureAgentQuota(int agencyId) async {
    final sub = await _subscriptions.getCurrent(agencyId);
    if (sub == null || sub.status != SubscriptionStatus.active) {
      throw AdminException('L’abonnement de l’agence n’est pas actif.');
    }
    final active = Sqflite.firstIntValue(await (await _db).rawQuery(
          'SELECT COUNT(*) FROM agents ag JOIN users u ON u.id = ag.userId '
          'WHERE ag.agencyId = ? AND u.isActive = 1',
          [agencyId],
        )) ??
        0;
    if (active >= sub.maxAgents) {
      throw AdminException(
          'Limite du plan ${sub.plan.label} atteinte : ${sub.maxAgents} agent(s) actif(s) maximum.');
    }
  }
}
