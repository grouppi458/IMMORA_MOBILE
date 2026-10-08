import 'package:sqflite/sqflite.dart';

import 'package:immora_mobile/core/database/db_inspector.dart';
import 'package:immora_mobile/core/errors/app_exception.dart';

import 'package:immora_mobile/module_gestion_agences/score/activity_scorer.dart';
import 'package:immora_mobile/module_gestion_agences/models/agency_views.dart';
import 'package:immora_mobile/module_gestion_agences/models/agency.dart';
import 'package:immora_mobile/module_authentification/services/password_service.dart';
import 'package:immora_mobile/core/utils/constants.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/validators.dart';
import 'package:immora_mobile/core/database/database_helper.dart';
import 'package:immora_mobile/module_gestion_agences/repositories/subscription_repository.dart';

/// Gestion des agences et de leurs abonnements (Module 2, BF2.1 à BF2.8).
class AgencyAdminRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;
  final _subscriptions = SubscriptionRepository();
  final _scorer = ActivityScorer();

  // ---------------------------------------------------------------- Lecture

  /// La table `properties` appartient à l'Ing. 2 : tant qu'elle n'existe pas,
  /// le nombre de biens vaut 0.
  Future<int> countProperties({int? agencyId, DateTime? since}) async {
    final db = await _db;
    if (!await DbInspector.tableExists(db, 'properties')) return 0;
    final where = <String>[];
    final args = <Object>[];
    if (agencyId != null) {
      where.add('agencyId = ?');
      args.add(agencyId);
    }
    if (since != null) {
      where.add('createdAt >= ?');
      args.add(since.millisecondsSinceEpoch);
    }
    final sql = 'SELECT COUNT(*) FROM properties${where.isEmpty ? '' : ' WHERE ${where.join(' AND ')}'}';
    return Sqflite.firstIntValue(await db.rawQuery(sql, args)) ?? 0;
  }

  /// BF2.3 — toutes les agences avec plan, statut, compteurs et score.
  Future<List<AgencySummary>> agencySummaries() async {
    final db = await _db;
    final agencies = (await db.query('agencies', orderBy: 'name')).map(Agency.fromMap);
    return [for (final agency in agencies) await _summarize(db, agency)];
  }

  /// Résumé d'une seule agence (espace agence).
  Future<AgencySummary?> agencySummary(int agencyId) async {
    final db = await _db;
    final rows = await db.query('agencies', where: 'id = ?', whereArgs: [agencyId]);
    if (rows.isEmpty) return null;
    return _summarize(db, Agency.fromMap(rows.first));
  }

  Future<AgencySummary> _summarize(Database db, Agency agency) async {
    final activeAgents = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM agents ag JOIN users u ON u.id = ag.userId '
          'WHERE ag.agencyId = ? AND u.isActive = 1',
          [agency.id],
        )) ??
        0;
    return AgencySummary(
      agency: agency,
      subscription: await _subscriptions.getCurrent(agency.id!),
      activeAgents: activeAgents,
      properties: await countProperties(agencyId: agency.id),
      activity: await _scorer.scoreAgency(agency.id!), // BF2.6
    );
  }

  Future<DashboardStats> dashboard(List<AgencySummary> agencies) async {
    final db = await _db;
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);

    final roleRows = await db.rawQuery('SELECT role, COUNT(*) AS n FROM users GROUP BY role');
    final byRole = {
      for (final r in roleRows) UserRole.values.byName(r['role'] as String): r['n'] as int,
    };

    final months = <MonthRevenue>[];
    for (var i = 5; i >= 0; i--) {
      final start = DateTime(now.year, now.month - i);
      final end = DateTime(start.year, start.month + 1);
      final row = await db.rawQuery(
        'SELECT COALESCE(SUM(monthlyPrice), 0) AS total FROM subscriptions '
        "WHERE startDate < ? AND endDate >= ? AND status != 'suspended'",
        [end.millisecondsSinceEpoch, start.millisecondsSinceEpoch],
      );
      months.add(MonthRevenue(start, (row.first['total'] as num).toDouble()));
    }

    final active = agencies.where((a) => a.status == AgencyStatus.active);
    return DashboardStats(
      activeAgencies: active.length,
      totalAgencies: agencies.length,
      agenciesThisMonth: agencies
          .where((a) => a.agency.createdAt >= monthStart.millisecondsSinceEpoch)
          .length,
      accounts: byRole.entries
          .where((e) => e.key != UserRole.admin)
          .fold(0, (sum, e) => sum + e.value),
      mrr: active.fold(0.0, (sum, a) => sum + (a.subscription?.monthlyPrice ?? 0)),
      properties: await countProperties(),
      propertiesThisMonth: await countProperties(since: monthStart),
      monthlyRevenue: months,
      accountsByRole: byRole,
    );
  }

  // ---------------------------------------------------------------- Agences

  /// Crée l'agence, son abonnement et le premier compte « agency ».
  /// Renvoie le mot de passe temporaire de ce compte.
  Future<String> createAgency({
    required String name,
    required String email,
    required String phone,
    required String city,
    required String address,
    required SubscriptionPlan plan,
    String? logoPath,
  }) async {
    _check([
      Validators.agencyName(name),
      Validators.email(email),
      Validators.phone(phone),
      Validators.city(city),
      Validators.address(address),
    ]);
    final cleanEmail = email.trim().toLowerCase();
    await _ensureAgencyEmailFree(cleanEmail);
    await _ensureUserEmailFree(cleanEmail);

    final db = await _db;
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final cleanPhone = Validators.normalizePhone(phone);
    final defaults = planDefaults[plan]!;
    final tempPassword = PasswordService.generateTemporaryPassword();
    final salt = PasswordService.generateSalt();

    await db.transaction((txn) async {
      final agencyId = await txn.insert('agencies', {
        'name': name.trim(),
        'email': cleanEmail,
        'phone': cleanPhone,
        'address': address.trim(),
        'city': city.trim(),
        'logoPath': logoPath,
        'isActive': 1,
        'createdAt': nowMs,
      });
      await txn.insert('subscriptions', {
        'agencyId': agencyId,
        'plan': plan.name,
        'monthlyPrice': defaults.monthlyPrice,
        'maxProperties': defaults.maxProperties,
        'maxAgents': defaults.maxAgents,
        'startDate': nowMs,
        'endDate': now.add(const Duration(days: subscriptionPeriodDays)).millisecondsSinceEpoch,
        'status': SubscriptionStatus.active.name,
      });
      await txn.insert('users', {
        'agencyId': agencyId,
        'fullName': name.trim(),
        'email': cleanEmail,
        'phone': cleanPhone,
        'passwordHash': PasswordService.hash(tempPassword, salt),
        'passwordSalt': salt,
        'role': UserRole.agency.name,
        'isActive': 1,
        'createdAt': nowMs,
      });
    });
    return tempPassword;
  }

  Future<void> updateAgency(Agency agency) async {
    _check([
      Validators.agencyName(agency.name),
      Validators.email(agency.email),
      Validators.phone(agency.phone),
      Validators.city(agency.city),
      Validators.address(agency.address),
    ]);
    final email = agency.email.trim().toLowerCase();
    await _ensureAgencyEmailFree(email, exceptId: agency.id);
    await (await _db).update(
      'agencies',
      {
        'name': agency.name.trim(),
        'email': email,
        'phone': Validators.normalizePhone(agency.phone),
        'address': agency.address.trim(),
        'city': agency.city.trim(),
        'logoPath': agency.logoPath,
      },
      where: 'id = ?',
      whereArgs: [agency.id],
    );
  }

  Future<void> setAgencyActive(int agencyId, bool isActive) async => (await _db).update(
      'agencies', {'isActive': isActive ? 1 : 0},
      where: 'id = ?', whereArgs: [agencyId]);

  /// BF2.5 — supprime l'agence, son abonnement, ses comptes agence / agent et
  /// leur journal. Refusé si l'agence a encore des biens ou des transactions :
  /// il faut alors la suspendre pour garder l'historique.
  Future<void> deleteAgency(int agencyId) async {
    final db = await _db;
    for (final table in ['properties', 'transactions', 'listings']) {
      if (await DbInspector.countWhere(db, table, 'agencyId', agencyId) > 0) {
        throw AdminException(
            'Cette agence possède encore des données ($table). Suspendez-la plutôt que de la supprimer.');
      }
    }
    await db.transaction((txn) async {
      final userIds = (await txn.query('users',
              columns: ['id'], where: 'agencyId = ?', whereArgs: [agencyId]))
          .map((r) => r['id'] as int)
          .toList();
      await txn.delete('activity_logs', where: 'agencyId = ?', whereArgs: [agencyId]);
      for (final id in userIds) {
        await txn.delete('activity_logs', where: 'userId = ?', whereArgs: [id]);
      }
      await txn.delete('agents', where: 'agencyId = ?', whereArgs: [agencyId]);
      await txn.delete('users', where: 'agencyId = ?', whereArgs: [agencyId]);
      await txn.delete('subscriptions', where: 'agencyId = ?', whereArgs: [agencyId]);
      await txn.delete('agencies', where: 'id = ?', whereArgs: [agencyId]);
    });
  }

  // ---------------------------------------------------------- Abonnements

  /// Change le plan de l'abonnement en cours (prix et limites suivent).
  Future<void> changePlan(int agencyId, SubscriptionPlan plan) async {
    final current = await _subscriptions.getCurrent(agencyId);
    if (current == null) throw AdminException('Aucun abonnement pour cette agence.');
    final d = planDefaults[plan]!;
    await (await _db).update(
      'subscriptions',
      {
        'plan': plan.name,
        'monthlyPrice': d.monthlyPrice,
        'maxProperties': d.maxProperties,
        'maxAgents': d.maxAgents,
      },
      where: 'id = ?',
      whereArgs: [current.id],
    );
  }

  /// Ouvre une nouvelle période de 30 jours à partir d'aujourd'hui
  /// (ou de la fin de la période en cours si elle n'est pas terminée).
  Future<void> renew(int agencyId, SubscriptionPlan plan) async {
    final current = await _subscriptions.getCurrent(agencyId);
    final now = DateTime.now();
    final start = current != null && current.status == SubscriptionStatus.active
        ? DateTime.fromMillisecondsSinceEpoch(current.endDate)
        : now;
    final d = planDefaults[plan]!;
    await (await _db).insert('subscriptions', {
      'agencyId': agencyId,
      'plan': plan.name,
      'monthlyPrice': d.monthlyPrice,
      'maxProperties': d.maxProperties,
      'maxAgents': d.maxAgents,
      'startDate': start.millisecondsSinceEpoch,
      'endDate': start.add(const Duration(days: subscriptionPeriodDays)).millisecondsSinceEpoch,
      'status': SubscriptionStatus.active.name,
    });
  }

  // ---------------------------------------------------------------- Règles

  void _check(List<String?> errors) {
    final first = errors.whereType<String>().firstOrNull;
    if (first != null) throw AdminException(first);
  }

  Future<void> _ensureAgencyEmailFree(String email, {int? exceptId}) async {
    final rows = await (await _db).query('agencies',
        columns: ['id'],
        where: exceptId == null ? 'email = ?' : 'email = ? AND id != ?',
        whereArgs: exceptId == null ? [email] : [email, exceptId]);
    if (rows.isNotEmpty) {
      throw AdminException('Cet email est déjà utilisé par une autre agence', field: 'email');
    }
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
}
