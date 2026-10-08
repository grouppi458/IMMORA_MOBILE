import 'package:sqflite/sqflite.dart';

import 'package:immora_mobile/core/database/db_inspector.dart';

import 'package:immora_mobile/module_gestion_agences/models/subscription.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/database/database_helper.dart';

class SubscriptionRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<int> insert(Subscription subscription) async =>
      (await _db).insert('subscriptions', subscription.toMap()..remove('id'));

  /// Abonnement le plus récent de l'agence. Passe le statut à `expired`
  /// si la date de fin est dépassée.
  Future<Subscription?> getCurrent(int agencyId) async {
    final db = await _db;
    final rows = await db.query(
      'subscriptions',
      where: 'agencyId = ?',
      whereArgs: [agencyId],
      orderBy: 'endDate DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final sub = Subscription.fromMap(rows.first);
    if (sub.status == SubscriptionStatus.active && sub.isExpired) {
      await db.update('subscriptions', {'status': SubscriptionStatus.expired.name},
          where: 'id = ?', whereArgs: [sub.id]);
      return Subscription.fromMap({...rows.first, 'status': SubscriptionStatus.expired.name});
    }
    return sub;
  }

  /// Une agence est bloquée si elle n'a pas d'abonnement actif.
  Future<bool> isAgencyBlocked(int agencyId) async {
    final sub = await getCurrent(agencyId);
    return sub == null || sub.status != SubscriptionStatus.active;
  }

  Future<int> update(Subscription subscription) async => (await _db).update(
      'subscriptions', subscription.toMap(),
      where: 'id = ?', whereArgs: [subscription.id]);

  /// BF2.8 — limite du plan sur le nombre de biens. À appeler par le Module 3
  /// (Ing. 2) avant d'ajouter un bien. Renvoie null si l'ajout est permis,
  /// sinon le message à afficher.
  Future<String?> propertyQuotaError(int agencyId) async {
    final sub = await getCurrent(agencyId);
    if (sub == null || sub.status != SubscriptionStatus.active) {
      return 'L’abonnement de l’agence n’est pas actif.';
    }
    final db = await _db;
    if (!await DbInspector.tableExists(db, 'properties')) return null;
    final count = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM properties WHERE agencyId = ?', [agencyId])) ??
        0;
    if (count >= sub.maxProperties) {
      return 'Limite du plan ${sub.plan.label} atteinte : ${sub.maxProperties} biens maximum.';
    }
    return null;
  }
}
