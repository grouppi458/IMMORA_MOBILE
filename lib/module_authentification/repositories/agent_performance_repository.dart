import 'package:sqflite/sqflite.dart';

import 'package:immora_mobile/core/database/database_helper.dart';
import 'package:immora_mobile/core/database/db_inspector.dart';
import 'package:immora_mobile/module_authentification/models/agent_performance.dart';
import 'package:immora_mobile/module_authentification/models/agent_with_user.dart';
import 'package:immora_mobile/module_authentification/repositories/user_admin_repository.dart';

/// Fonction avancée du Module 1 : tableau de bord de performance des agents
/// (BF1.8 calcul, BF1.9 classement).
///
/// Les chiffres viennent des tables des autres modules. Colonnes attendues :
/// * visits (M6)        : agentId, status ('done' = effectuée), scheduledAt
/// * transactions (M4)  : agentId, type ('sale' | 'rent'), commission, status, createdAt
/// Tant qu'une table ou une colonne n'existe pas, sa valeur vaut 0.
class AgentPerformanceRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;
  final _users = UserAdminRepository();

  static const visitDoneStatus = 'done';
  static const transactionCancelledStatus = 'cancelled';

  /// Performance de chaque agent depuis [since], triée du meilleur au moins bon.
  /// [agencyId] null = tous les agents de la plateforme (vue admin).
  Future<List<AgentPerformance>> ranking({int? agencyId, required DateTime since}) async {
    final db = await _db;
    final agents = await _agents(db, agencyId);
    final from = since.millisecondsSinceEpoch;

    final hasVisits = await DbInspector.hasColumn(db, 'visits', 'agentId');
    final visitsHaveStatus = await DbInspector.hasColumn(db, 'visits', 'status');
    final visitsHaveDate = await DbInspector.hasColumn(db, 'visits', 'scheduledAt');
    final hasTx = await DbInspector.hasColumn(db, 'transactions', 'agentId');
    final txHaveType = await DbInspector.hasColumn(db, 'transactions', 'type');
    final txHaveCommission = await DbInspector.hasColumn(db, 'transactions', 'commission');
    final txHaveStatus = await DbInspector.hasColumn(db, 'transactions', 'status');
    final txHaveDate = await DbInspector.hasColumn(db, 'transactions', 'createdAt');

    final result = <AgentPerformance>[];
    for (final a in agents) {
      final id = a.agent.id!;
      var visits = 0, sales = 0, rentals = 0;
      var commissions = 0.0;

      if (hasVisits) {
        final where = ['agentId = ?'];
        final args = <Object>[id];
        if (visitsHaveStatus) {
          where.add('status = ?');
          args.add(visitDoneStatus);
        }
        if (visitsHaveDate) {
          where.add('scheduledAt >= ?');
          args.add(from);
        }
        visits = Sqflite.firstIntValue(await db.rawQuery(
                'SELECT COUNT(*) FROM visits WHERE ${where.join(' AND ')}', args)) ??
            0;
      }

      if (hasTx) {
        final where = ['agentId = ?'];
        final args = <Object>[id];
        if (txHaveStatus) {
          where.add('status != ?');
          args.add(transactionCancelledStatus);
        }
        if (txHaveDate) {
          where.add('createdAt >= ?');
          args.add(from);
        }
        final row = (await db.rawQuery(
          'SELECT '
          '${txHaveType ? "SUM(CASE WHEN type = 'sale' THEN 1 ELSE 0 END)" : 'COUNT(*)'} AS sales, '
          '${txHaveType ? "SUM(CASE WHEN type = 'rent' THEN 1 ELSE 0 END)" : '0'} AS rentals, '
          '${txHaveCommission ? 'COALESCE(SUM(commission), 0)' : '0'} AS total '
          'FROM transactions WHERE ${where.join(' AND ')}',
          args,
        ))
            .first;
        sales = (row['sales'] as num?)?.toInt() ?? 0;
        rentals = (row['rentals'] as num?)?.toInt() ?? 0;
        commissions = (row['total'] as num?)?.toDouble() ?? 0;
      }

      result.add(AgentPerformance(
        agent: a,
        visits: visits,
        sales: sales,
        rentals: rentals,
        commissions: commissions,
      ));
    }

    // BF1.9 : classement par commissions, puis affaires conclues, puis visites.
    result.sort((x, y) {
      final byCommission = y.commissions.compareTo(x.commissions);
      if (byCommission != 0) return byCommission;
      final byDeals = y.deals.compareTo(x.deals);
      if (byDeals != 0) return byDeals;
      return y.visits.compareTo(x.visits);
    });
    return result;
  }

  Future<List<AgentWithUser>> _agents(Database db, int? agencyId) async {
    if (agencyId != null) return _users.agentsOfAgency(agencyId);
    final agencyIds = (await db.query('agencies', columns: ['id'])).map((r) => r['id'] as int);
    return [for (final id in agencyIds) ...await _users.agentsOfAgency(id)];
  }
}
