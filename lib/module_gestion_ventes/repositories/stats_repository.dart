import 'package:sqflite/sqflite.dart';

import 'package:immora_mobile/core/database/database_helper.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/module_gestion_agences/models/agency_views.dart';
import 'package:immora_mobile/module_gestion_ventes/models/finance_stats.dart';

/// Chiffres de l'écran « Finances » (maquette M4). Les transactions annulées
/// sont exclues de tous les totaux ; les encaissements en attente / en retard
/// reflètent l'état courant, pas la période sélectionnée.
class StatsRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<FinanceStats> financeStats(int agencyId,
      {required DateTime from, required DateTime to}) async {
    final db = await _db;
    final start = from.millisecondsSinceEpoch;
    final end = to.millisecondsSinceEpoch;

    final rows = await db.rawQuery(
        "SELECT dealType, amount, commissionAmount FROM transactions "
        "WHERE agencyId = ? AND status <> '${TransactionStatus.cancelled.name}' "
        'AND createdAt >= ? AND createdAt <= ?',
        [agencyId, start, end]);
    var sales = 0;
    var rents = 0;
    var total = 0.0;
    var commissions = 0.0;
    for (final r in rows) {
      if (r['dealType'] == DealType.sale.name) {
        sales++;
      } else {
        rents++;
      }
      total += (r['amount'] as num).toDouble();
      commissions += (r['commissionAmount'] as num).toDouble();
    }

    // « Revenus (4 mois) » : commissions du mois de création des affaires.
    final now = DateTime.now();
    final firstMonth = DateTime(now.year, now.month - 3);
    final monthlyRows = await db.rawQuery(
        'SELECT createdAt, commissionAmount FROM transactions '
        "WHERE agencyId = ? AND status <> '${TransactionStatus.cancelled.name}' "
        'AND createdAt >= ?',
        [agencyId, firstMonth.millisecondsSinceEpoch]);
    final sums = <int, double>{};
    for (final r in monthlyRows) {
      final d = DateTime.fromMillisecondsSinceEpoch(r['createdAt'] as int);
      sums.update(d.year * 12 + d.month, (v) => v + (r['commissionAmount'] as num).toDouble(),
          ifAbsent: () => (r['commissionAmount'] as num).toDouble());
    }
    final monthly = <MonthRevenue>[];
    for (var i = 0; i < 4; i++) {
      final m = DateTime(now.year, now.month - 3 + i);
      monthly.add(MonthRevenue(m, sums[m.year * 12 + m.month] ?? 0));
    }

    // Encaissements en attente / en retard (état courant de l'agence).
    final payRows = await db.rawQuery(
        'SELECT p.amount, p.dueDate, p.paidDate FROM payments p '
        'JOIN transactions t ON t.id = p.transactionId '
        "WHERE t.agencyId = ? AND t.status <> '${TransactionStatus.cancelled.name}'",
        [agencyId]);
    var pendingCount = 0;
    var lateCount = 0;
    var pendingAmount = 0.0;
    var lateAmount = 0.0;
    final nowMs = now.millisecondsSinceEpoch;
    for (final r in payRows) {
      if (r['paidDate'] != null) continue;
      final amount = (r['amount'] as num).toDouble();
      if ((r['dueDate'] as int) < nowMs) {
        lateCount++;
        lateAmount += amount;
      } else {
        pendingCount++;
        pendingAmount += amount;
      }
    }

    // « Commissions par agent » : du meilleur au moins bon.
    final agentRows = await db.rawQuery(
        'SELECT u.fullName AS name, SUM(t.commissionAmount) AS total '
        'FROM transactions t '
        'JOIN agents ag ON ag.id = t.agentId AND ag.agencyId = t.agencyId '
        'JOIN users u ON u.id = ag.userId '
        "WHERE t.agencyId = ? AND t.status <> '${TransactionStatus.cancelled.name}' "
        'AND t.createdAt >= ? AND t.createdAt <= ? '
        'GROUP BY ag.id ORDER BY total DESC',
        [agencyId, start, end]);

    return FinanceStats(
      salesCount: sales,
      rentsCount: rents,
      totalAmount: total,
      commissions: commissions,
      monthlyRevenue: monthly,
      pendingCount: pendingCount,
      pendingAmount: pendingAmount,
      lateCount: lateCount,
      lateAmount: lateAmount,
      agentCommissions: [
        for (final r in agentRows) (r['name'] as String, (r['total'] as num).toDouble()),
      ],
    );
  }
}
