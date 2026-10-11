import 'package:sqflite/sqflite.dart';

import 'package:immora_mobile/module_gestion_ventes/ai/anomaly_detector.dart';
import 'package:immora_mobile/core/database/database_helper.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/module_gestion_ventes/models/alert.dart';

/// Alertes d'anomalie du Module 4 (maquettes « Alertes » et « Alerte »). La
/// liste relance l'analyse des paiements en retard — comme
/// `ListingRepository.refreshStatuses` pour les annonces.
class AlertRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  /// Alertes d'une agence : les plus graves d'abord (High, Medium, Low) puis
  /// les plus récentes (maquette « Alertes »).
  Future<List<Alert>> list(int agencyId,
      {bool unreadOnly = false, AlertSeverity? severity}) async {
    final db = await _db;
    await AnomalyDetector.syncPaymentLate(db, agencyId: agencyId);
    final where = ['agencyId = ?'];
    final args = <Object>[agencyId];
    if (unreadOnly) where.add('isRead = 0');
    if (severity != null) {
      where.add('severity = ?');
      args.add(severity.name);
    }
    final rows = await db.query('alerts',
        where: where.join(' AND '),
        whereArgs: args,
        orderBy: "CASE severity WHEN 'high' THEN 0 WHEN 'medium' THEN 1 "
            'ELSE 2 END, createdAt DESC');
    return rows.map(Alert.fromMap).toList();
  }

  /// Compteurs des puces « Toutes · 5 / Non lues · 3 » (maquette).
  Future<({int total, int unread, Map<AlertSeverity, int> bySeverity})> counts(
      int agencyId) async {
    final db = await _db;
    await AnomalyDetector.syncPaymentLate(db, agencyId: agencyId);
    final rows = await db.rawQuery(
        'SELECT severity, isRead, COUNT(*) AS n FROM alerts '
        'WHERE agencyId = ? GROUP BY severity, isRead',
        [agencyId]);
    var total = 0;
    var unread = 0;
    final bySeverity = <AlertSeverity, int>{};
    for (final r in rows) {
      final n = r['n'] as int;
      total += n;
      if (r['isRead'] == 0) unread += n;
      bySeverity.update(AlertSeverity.values.byName(r['severity'] as String),
          (value) => value + n,
          ifAbsent: () => n);
    }
    return (total: total, unread: unread, bySeverity: bySeverity);
  }

  /// « Marquer comme lue » du détail.
  Future<void> markRead(int id) async {
    await (await _db)
        .update('alerts', {'isRead': 1}, where: 'id = ?', whereArgs: [id]);
  }

  /// Le ✓ de l'en-tête de la liste.
  Future<void> markAllRead(int agencyId) async {
    await (await _db).update('alerts', {'isRead': 1},
        where: 'agencyId = ? AND isRead = 0', whereArgs: [agencyId]);
  }

  /// « Ignorer » : supprime l'alerte — le détecteur la recréera à la
  /// prochaine analyse si l'anomalie persiste (« exécuté à chaque
  /// transaction ou paiement »).
  Future<void> ignore(int id) async {
    await (await _db).delete('alerts', where: 'id = ?', whereArgs: [id]);
  }
}
