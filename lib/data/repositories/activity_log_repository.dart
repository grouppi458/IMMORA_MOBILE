import 'package:sqflite/sqflite.dart';

import '../../models/activity_log.dart';
import '../../services/session_service.dart';
import '../../utils/enums.dart';
import '../database_helper.dart';

class ActivityLogRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  /// Journalise une action. Utilise l'utilisateur de la session courante
  /// sauf si [userId] / [agencyId] sont fournis. Appelé par les 3 modules.
  Future<void> logActivity(
    ActivityType type, {
    String? details,
    int? userId,
    int? agencyId,
  }) async {
    var uid = userId;
    var aid = agencyId;
    if (uid == null) {
      final session = await SessionService.getSession();
      if (session.userId == 0) return;
      uid = session.userId;
      aid ??= session.agencyId;
    }
    final log = ActivityLog(
      userId: uid,
      agencyId: aid,
      type: type,
      details: details,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    await (await _db).insert('activity_logs', log.toMap()..remove('id'));
  }

  /// Nombre d'actions d'un type pour une agence depuis [since] (score d'activité).
  Future<int> countByType(int agencyId, ActivityType type, DateTime since) async =>
      Sqflite.firstIntValue(await (await _db).rawQuery(
        'SELECT COUNT(*) FROM activity_logs WHERE agencyId = ? AND type = ? AND timestamp >= ?',
        [agencyId, type.name, since.millisecondsSinceEpoch],
      )) ??
      0;

  Future<int?> lastActivityTimestamp(int agencyId) async => Sqflite.firstIntValue(
      await (await _db).rawQuery(
          'SELECT MAX(timestamp) FROM activity_logs WHERE agencyId = ?', [agencyId]));
}
