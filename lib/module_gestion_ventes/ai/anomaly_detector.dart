import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'package:immora_mobile/core/utils/constants.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';

/// Détecteur d'anomalies du Module 4 (bannière « lib/module_gestion_ventes/ai/anomaly_detector.dart »
/// de la maquette « Alertes ») : exécuté à chaque transaction ou paiement —
/// - **montant inhabituel** : z-score > 2,5 face aux transactions de même type
///   de l'agence (historique minimal : [anomalyMinHistory]) → High ;
/// - **prix final éloigné du prix affiché** du bien : écart > 30 % → Medium ;
/// - **activité inhabituelle** : plus de 5 transactions d'un agent en 24 h ;
/// - **paiement en retard** : échéance dépassée sans encaissement → Low ;
/// - **paiement différent de l'attendu** : montant modifié de plus de 5 %.
/// Une anomalie ne bloque jamais l'action : les erreurs sont journalisées.
class AnomalyDetector {
  AnomalyDetector._();

  /// Analyse une transaction créée ou modifiée : les alertes existantes de
  /// même type sont remplacées (une anomalie qui persiste ne s'accumule pas,
  /// une anomalie corrigée disparaît).
  static Future<void> onTransactionSaved(Database db, int transactionId) async {
    try {
      await _checkAmountOutlier(db, transactionId);
      await _checkPriceGap(db, transactionId);
      await _checkAgentActivity(db, transactionId);
    } catch (e) {
      debugPrint('AnomalyDetector : analyse de la transaction $transactionId impossible ($e)');
    }
  }

  /// Analyse un paiement modifié : [previousAmount] est l'échéance enregistrée
  /// avant la modification (montant « attendu »).
  static Future<void> onPaymentUpdated(Database db, int paymentId,
      {required double previousAmount}) async {
    try {
      await _checkPaymentMismatch(db, paymentId, previousAmount);
    } catch (e) {
      debugPrint('AnomalyDetector : analyse du paiement $paymentId impossible ($e)');
    }
  }

  /// Paiements en retard d'une agence : remplace les alertes des paiements
  /// encaissés, crée celles des échéances dépassées. Appelé à chaque lecture
  /// des alertes (comme l'expiration des annonces, BF5.4).
  static Future<void> syncPaymentLate(Database db, {required int agencyId}) async {
    try {
      // Un paiement encaissé ne peut plus être « en retard ».
      await db.rawDelete(
        "DELETE FROM alerts WHERE type = ? AND agencyId = ? AND paymentId IN "
        '(SELECT id FROM payments WHERE paidDate IS NOT NULL)',
        [AlertType.paymentLate.name, agencyId],
      );
      final now = DateTime.now();
      final rows = await db.rawQuery('''
        SELECT pay.id AS paymentId, pay.label, pay.dueDate,
          t.id AS transactionId, t.ref
        FROM payments pay
        JOIN transactions t ON t.id = pay.transactionId
        WHERE t.agencyId = ? AND pay.paidDate IS NULL AND pay.dueDate < ?
          AND NOT EXISTS (SELECT 1 FROM alerts a
            WHERE a.paymentId = pay.id AND a.type = ?)
        ORDER BY pay.dueDate''', [agencyId, now.millisecondsSinceEpoch,
        AlertType.paymentLate.name]);
      for (final r in rows) {
        final lateDays = now
            .difference(DateTime.fromMillisecondsSinceEpoch(r['dueDate'] as int))
            .inDays;
        await _insert(db,
            agencyId: agencyId,
            type: AlertType.paymentLate,
            title: 'Paiement en retard',
            subtitle: '${r['label']} · #${r['ref']} · $lateDays j',
            description: 'Le paiement « ${r['label']} » de la transaction '
                '#${r['ref']} est en retard de $lateDays jours. '
                'Relancez le client pour le règlement.',
            details: {
              'Échéance': formatDate(r['dueDate'] as int),
              'Retard': '$lateDays jours',
            },
            transactionId: r['transactionId'] as int,
            paymentId: r['paymentId'] as int);
      }
    } catch (e) {
      debugPrint('AnomalyDetector : analyse des retards impossible ($e)');
    }
  }

  // ---------------------------------------------------------------- Règles

  static Future<void> _checkAmountOutlier(Database db, int transactionId) async {
    final tx = await _txRow(db, transactionId);
    if (tx == null) return;
    final history = await db.rawQuery(
      'SELECT amount FROM transactions WHERE agencyId = ? AND dealType = ? '
      'AND status IN (?, ?, ?) AND id <> ?',
      [
        tx['agencyId'],
        tx['dealType'],
        TransactionStatus.ongoing.name,
        TransactionStatus.signed.name,
        TransactionStatus.completed.name,
        transactionId,
      ],
    );
    if (history.length < anomalyMinHistory) return;
    final values = [for (final r in history) (r['amount'] as num).toDouble()];
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
    final sd = sqrt(variance);
    if (sd == 0) return;
    final amount = (tx['amount'] as num).toDouble();
    final z = (amount - mean).abs() / sd;

    await _removePrevious(db,
        agencyId: tx['agencyId'] as int,
        type: AlertType.amountOutlier,
        transactionId: transactionId);
    if (z <= anomalyZScoreThreshold) return;

    final rent = tx['dealType'] == DealType.rent.name;
    final deals = rent ? 'locations' : 'ventes';
    final kind = rent ? 'location' : 'vente';
    await _insert(db,
        agencyId: tx['agencyId'] as int,
        type: AlertType.amountOutlier,
        title: 'Montant très éloigné de l’habitude',
        subtitle: '${tx['propertyTitle']} · z = ${_decimal(z)}',
        description: 'Le montant s’écarte fortement de la moyenne des $deals '
            'de même type dans l’agence.',
        details: {
          'Montant': '${formatNumber(amount)} TND',
          'Moyenne (agence, $kind)': '${formatNumber(mean)} TND',
          'Écart-type': '${formatNumber(sd)} TND',
          'z-score': '${_decimal(z)} (seuil ${_decimal(anomalyZScoreThreshold)})',
          'Historique': '${history.length} $deals (min. $anomalyMinHistory)',
        },
        transactionId: transactionId);
  }

  static Future<void> _checkPriceGap(Database db, int transactionId) async {
    final tx = await _txRow(db, transactionId);
    if (tx == null) return;
    final price = (tx['propertyPrice'] as num).toDouble();
    if (price <= 0) return;
    final amount = (tx['amount'] as num).toDouble();
    final gap = (amount - price).abs() / price * 100;

    await _removePrevious(db,
        agencyId: tx['agencyId'] as int,
        type: AlertType.priceGap,
        transactionId: transactionId);
    if (gap <= anomalyPriceGapPercent) return;

    final gapText = '${gap.round()} % (> ${anomalyPriceGapPercent.round()} %)';
    await _insert(db,
        agencyId: tx['agencyId'] as int,
        type: AlertType.priceGap,
        title: 'Prix final éloigné du prix affiché',
        subtitle: 'Écart $gapText',
        description: 'Le prix final s’écarte de ${gap.round()} % du prix '
            'affiché du bien (seuil ${anomalyPriceGapPercent.round()} %). '
            'Vérifiez le prix ou corrigez la fiche.',
        details: {
          'Prix final (transaction)': '${formatNumber(amount)} TND',
          'Prix affiché du bien': '${formatNumber(price)} TND',
          'Écart': gapText,
        },
        transactionId: transactionId);
  }

  static Future<void> _checkAgentActivity(Database db, int transactionId) async {
    final tx = await _txRow(db, transactionId);
    if (tx == null) return;
    final agentId = tx['agentId'];
    if (agentId == null) return;

    await _removePrevious(db,
        agencyId: tx['agencyId'] as int,
        type: AlertType.agentActivity,
        transactionId: transactionId);
    final since = DateTime.now()
        .subtract(const Duration(hours: 24))
        .millisecondsSinceEpoch;
    final count = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM transactions WHERE agentId = ? AND createdAt >= ?',
          [agentId, since],
        )) ??
        0;
    if (count <= anomalyAgentActivityMax) return;

    final agentName = await _agentName(db, agentId as int) ?? 'Agent';
    await _insert(db,
        agencyId: tx['agencyId'] as int,
        type: AlertType.agentActivity,
        title: 'Activité inhabituelle d’un agent',
        subtitle: '$count transactions en 24 h (> $anomalyAgentActivityMax)',
        description: 'L’agent a enregistré $count transactions sur les '
            'dernières 24 h (seuil $anomalyAgentActivityMax). Vérifiez les '
            'éventuelles saisies en double.',
        details: {
          'Agent': agentName,
          'Transactions (24 h)': '$count (> $anomalyAgentActivityMax)',
        },
        transactionId: transactionId);
  }

  static Future<void> _checkPaymentMismatch(
      Database db, int paymentId, double previousAmount) async {
    final rows = await db.rawQuery(
      'SELECT pay.*, t.ref, t.agencyId FROM payments pay '
      'JOIN transactions t ON t.id = pay.transactionId WHERE pay.id = ?',
      [paymentId],
    );
    if (rows.isEmpty) return;
    final payment = rows.first;
    final amount = (payment['amount'] as num).toDouble();
    if (amount <= 0) return;
    // Écart rapporté au montant reçu (maquette : 270 000 attendus vs
    // 250 000 reçus → 8 %).
    final gap = (amount - previousAmount).abs() / amount * 100;

    await _removePrevious(db,
        agencyId: payment['agencyId'] as int,
        type: AlertType.paymentMismatch,
        paymentId: paymentId);
    if (gap <= anomalyPaymentGapPercent) return;

    final gapText = '${gap.round()} % (> ${anomalyPaymentGapPercent.round()} %)';
    await _insert(db,
        agencyId: payment['agencyId'] as int,
        type: AlertType.paymentMismatch,
        title: 'Paiement différent de l’attendu',
        subtitle: 'Écart $gapText',
        description: 'Le montant reçu s’écarte de l’échéance planifiée de '
            '${gap.round()} % (seuil ${anomalyPaymentGapPercent.round()} %). '
            'Confirmez le montant avec le client.',
        details: {
          'Échéance planifiée': '${formatNumber(previousAmount)} TND',
          'Montant reçu': '${formatNumber(amount)} TND',
          'Écart': gapText,
        },
        transactionId: payment['transactionId'] as int,
        paymentId: paymentId);
  }

  // ---------------------------------------------------------------- Interne

  static Future<Map<String, Object?>?> _txRow(Database db, int id) async {
    final rows = await db.rawQuery(
      'SELECT t.*, p.title AS propertyTitle, p.price AS propertyPrice '
      'FROM transactions t JOIN properties p ON p.id = t.propertyId WHERE t.id = ?',
      [id],
    );
    return rows.isEmpty ? null : rows.first;
  }

  static Future<String?> _agentName(Database db, int agentId) async {
    final rows = await db.rawQuery(
        'SELECT u.fullName FROM agents ag JOIN users u ON u.id = ag.userId '
        'WHERE ag.id = ?',
        [agentId]);
    return rows.isEmpty ? null : rows.first['fullName'] as String?;
  }

  /// Supprime l'alerte précédente de même type pour la même cible — l'état
  /// courant remplace l'état passé, quel que soit son statut de lecture.
  static Future<void> _removePrevious(Database db,
      {required int agencyId,
      required AlertType type,
      int? transactionId,
      int? paymentId}) async {
    final where = ['agencyId = ?', 'type = ?'];
    final args = <Object>[agencyId, type.name];
    if (transactionId != null) {
      where.add('transactionId = ?');
      args.add(transactionId);
    }
    if (paymentId != null) {
      where.add('paymentId = ?');
      args.add(paymentId);
    }
    await db.delete('alerts', where: where.join(' AND '), whereArgs: args);
  }

  static Future<void> _insert(Database db,
      {required int agencyId,
      required AlertType type,
      required String title,
      String? subtitle,
      required String description,
      required Map<String, String> details,
      int? transactionId,
      int? paymentId}) async {
    await db.insert('alerts', {
      'agencyId': agencyId,
      'type': type.name,
      'severity': _severityOf(type).name,
      'title': title,
      'subtitle': subtitle,
      'description': description,
      'details': jsonEncode(details),
      'transactionId': transactionId,
      'paymentId': paymentId,
      'isRead': 0,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static AlertSeverity _severityOf(AlertType type) => switch (type) {
        AlertType.amountOutlier => AlertSeverity.high,
        AlertType.paymentLate => AlertSeverity.low,
        _ => AlertSeverity.medium,
      };

  /// « 3,1 » — z-score avec une décimale, virgule française.
  static String _decimal(double value) =>
      value.toStringAsFixed(1).replaceAll('.', ',');
}
