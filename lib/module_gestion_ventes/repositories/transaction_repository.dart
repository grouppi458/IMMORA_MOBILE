import 'package:sqflite/sqflite.dart' hide Transaction;

import 'package:immora_mobile/ai/anomaly_detector.dart';
import 'package:immora_mobile/core/database/database_helper.dart';
import 'package:immora_mobile/core/errors/app_exception.dart';
import 'package:immora_mobile/core/utils/constants.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/module_gestion_ventes/models/payment.dart';
import 'package:immora_mobile/module_gestion_ventes/models/transaction.dart';
import 'package:immora_mobile/module_gestion_ventes/models/transaction_details.dart';

/// Transactions du Module 4 : cycle de vie (brouillon → en cours → signée →
/// terminée, annulable avant la signature), échéancier de paiements et
/// déclenchement du détecteur d'anomalies. Les règles métier lèvent une
/// [AdminException] affichée telle quelle.
class TransactionRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  /// Statuts « en cours » : une seule transaction ouverte par bien.
  static const _activeStatuses = ['draft', 'ongoing', 'signed'];

  static const selectDetails = '''
    SELECT t.*,
      p.title AS propertyTitle, p.type AS propertyType, p.price AS propertyPrice,
      ua.fullName AS agentName
    FROM transactions t
    JOIN properties p ON p.id = t.propertyId
    LEFT JOIN agents ag ON ag.id = t.agentId
    LEFT JOIN users ua ON ua.id = ag.userId''';

  static TransactionDetails detailsFromRow(Map<String, dynamic> m) => TransactionDetails(
        transaction: Transaction.fromMap(m),
        propertyTitle: m['propertyTitle'] ?? '',
        propertyType: PropertyType.values.byName(m['propertyType']),
        propertyPrice: (m['propertyPrice'] as num?)?.toDouble() ?? 0,
        agentName: m['agentName'],
      );

  // ---------------------------------------------------------------- Lecture

  /// Transactions d'une agence, triées par avancement — en cours, signée,
  /// terminée, brouillon puis annulée (maquette « Transactions ») — et, à
  /// statut égal, des plus récentes aux plus anciennes. [query] cherche dans
  /// le titre du bien et le nom du client.
  Future<List<TransactionDetails>> agencyTransactions(int agencyId,
      {DealType? dealType, TransactionStatus? status, String query = ''}) async {
    final where = ['t.agencyId = ?'];
    final args = <Object>[agencyId];
    if (dealType != null) {
      where.add('t.dealType = ?');
      args.add(dealType.name);
    }
    if (status != null) {
      where.add('t.status = ?');
      args.add(status.name);
    }
    final q = query.trim();
    if (q.isNotEmpty) {
      where.add('(p.title LIKE ? OR t.clientName LIKE ?)');
      args.add('%$q%');
      args.add('%$q%');
    }
    final rows = await (await _db).rawQuery(
      '$selectDetails WHERE ${where.join(' AND ')} '
      'ORDER BY CASE t.status '
      "WHEN 'ongoing' THEN 0 WHEN 'signed' THEN 1 WHEN 'completed' THEN 2 "
      "WHEN 'draft' THEN 3 ELSE 4 END, t.createdAt DESC",
      args,
    );
    return rows.map(detailsFromRow).toList();
  }

  Future<TransactionDetails> details(int id) async => _get(await _db, id);

  /// Biens proposés au formulaire (« Bien ») : disponibles et sans autre
  /// transaction ouverte. [currentTransactionId] conserve le bien d'une
  /// transaction en cours de modification. Renvoie (id, titre, prix affiché).
  Future<List<(int, String, double)>> propertyOptions(int agencyId,
      {int? currentTransactionId}) async {
    final rows = await (await _db).rawQuery('''
      SELECT p.id, p.title, p.price FROM properties p
      WHERE p.agencyId = ? AND p.status = ?
        AND NOT EXISTS (
          SELECT 1 FROM transactions t
          WHERE t.propertyId = p.id AND t.status IN (?, ?, ?)
            ${currentTransactionId == null ? '' : 'AND t.id <> ?'})
      ORDER BY p.title''', [
      agencyId,
      PropertyStatus.available.name,
      ..._activeStatuses,
      ?currentTransactionId,
    ]);
    return [
      for (final r in rows)
        (r['id'] as int, r['title'] as String, (r['price'] as num).toDouble()),
    ];
  }

  /// Agents proposés au formulaire (« Agent », maquette « Nouvelle
  /// transaction ») : les agents actifs de l'agence, par ordre alphabétique.
  Future<List<(int, String)>> agentOptions(int agencyId) async {
    final rows = await (await _db).rawQuery(
        'SELECT ag.id, u.fullName FROM agents ag JOIN users u ON u.id = ag.userId '
        'WHERE ag.agencyId = ? AND u.isActive = 1 ORDER BY u.fullName',
        [agencyId]);
    return [for (final r in rows) (r['id'] as int, r['fullName'] as String)];
  }

  // ------------------------------------------------------------ Cycle de vie

  /// Crée une transaction depuis « Nouvelle transaction » : en brouillon ou
  /// directement en cours. Renvoie son identifiant.
  Future<int> create({
    required int agencyId,
    required int propertyId,
    required String clientName,
    required DealType dealType,
    required double amount,
    required double commissionRate,
    required DateTime startDate,
    TransactionStatus status = TransactionStatus.draft,
    int? clientId,
    int? agentId,
    DateTime? endDate,
    String? contractPath,
  }) async {
    final name = _validate(
        clientName: clientName,
        amount: amount,
        commissionRate: commissionRate,
        startDate: startDate,
        endDate: endDate);
    final db = await _db;
    await _ensurePropertyFree(db, agencyId: agencyId, propertyId: propertyId);
    final now = DateTime.now().millisecondsSinceEpoch;
    final ref = (Sqflite.firstIntValue(await db.rawQuery(
              'SELECT MAX(ref) FROM transactions WHERE agencyId = ?',
              [agencyId],
            )) ??
            1000) +
        1;
    final id = await db.insert('transactions', {
      'agencyId': agencyId,
      'ref': ref,
      'propertyId': propertyId,
      'clientId': clientId ?? await _clientByName(db, name),
      'clientName': name,
      'agentId': agentId,
      'dealType': dealType.name,
      'amount': amount,
      'commissionRate': commissionRate,
      'commissionAmount': amount * commissionRate,
      'status': status.name,
      'startDate': startDate.millisecondsSinceEpoch,
      'endDate': endDate?.millisecondsSinceEpoch,
      'contractPath': _clean(contractPath),
      'createdAt': now,
      'updatedAt': now,
    });
    await AnomalyDetector.onTransactionSaved(db, id);
    return id;
  }

  /// Modifie une transaction non terminée ; le bien peut être changé tant
  /// qu'il est libre. Le détecteur réévalue les alertes ensuite.
  Future<void> update(
    int id, {
    required int propertyId,
    required String clientName,
    required DealType dealType,
    required double amount,
    required double commissionRate,
    required DateTime startDate,
    int? agentId,
    DateTime? endDate,
    String? contractPath,
  }) async {
    final db = await _db;
    final current = await _get(db, id);
    if (current.transaction.isFinal) {
      throw AdminException(
          'Une transaction ${current.transaction.status.label.toLowerCase()} '
          'ne peut plus être modifiée.');
    }
    final name = _validate(
        clientName: clientName,
        amount: amount,
        commissionRate: commissionRate,
        startDate: startDate,
        endDate: endDate);
    if (propertyId != current.transaction.propertyId) {
      await _ensurePropertyFree(db, agencyId: current.transaction.agencyId, propertyId: propertyId);
    }
    await db.update(
        'transactions',
        {
          'propertyId': propertyId,
          'clientId': current.transaction.clientId ?? await _clientByName(db, name),
          'clientName': name,
          'agentId': agentId,
          'dealType': dealType.name,
          'amount': amount,
          'commissionRate': commissionRate,
          'commissionAmount': amount * commissionRate,
          'startDate': startDate.millisecondsSinceEpoch,
          'endDate': endDate?.millisecondsSinceEpoch,
          'contractPath': _clean(contractPath),
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id]);
    await AnomalyDetector.onTransactionSaved(db, id);
  }

  /// Brouillon → en cours (« Créer » depuis le brouillon).
  Future<void> activate(int id) async {
    final db = await _db;
    final tx = (await _get(db, id)).transaction;
    if (tx.status != TransactionStatus.draft) {
      throw AdminException('Seule une transaction « brouillon » peut être mise en cours.');
    }
    await _save(db, id, {'status': TransactionStatus.ongoing.name});
  }

  /// En cours → signée : le bien passe en « Vendu » (vente) ou « Loué »
  /// (location) ; ses annonces sont retirées à la prochaine lecture
  /// (BF5.4, géré par `ListingRepository.refreshStatuses`).
  Future<void> sign(int id) async {
    final db = await _db;
    final tx = (await _get(db, id)).transaction;
    if (tx.status != TransactionStatus.ongoing) {
      throw AdminException('Seule une transaction « en cours » peut être signée.');
    }
    await _save(db, id, {
      'status': TransactionStatus.signed.name,
      'signedAt': DateTime.now().millisecondsSinceEpoch,
    });
    await db.update(
        'properties',
        {
          'status': tx.dealType == DealType.sale
              ? PropertyStatus.sold.name
              : PropertyStatus.rented.name,
        },
        where: 'id = ?',
        whereArgs: [tx.propertyId]);
  }

  /// Signée → terminée : la fin d'une location repasse le bien en
  /// « Disponible » (une vente reste « Vendu »).
  Future<void> complete(int id) async {
    final db = await _db;
    final tx = (await _get(db, id)).transaction;
    if (tx.status != TransactionStatus.signed) {
      throw AdminException('Seule une transaction « signée » peut être terminée.');
    }
    await _save(db, id, {
      'status': TransactionStatus.completed.name,
      'endDate': DateTime.now().millisecondsSinceEpoch,
    });
    if (tx.dealType == DealType.rent) {
      await db.update('properties', {'status': PropertyStatus.available.name},
          where: 'id = ?', whereArgs: [tx.propertyId]);
    }
  }

  /// Annule un brouillon ou une transaction en cours (jamais une signature).
  Future<void> cancel(int id, {required String reason}) async {
    final db = await _db;
    final tx = (await _get(db, id)).transaction;
    if (tx.status != TransactionStatus.draft && tx.status != TransactionStatus.ongoing) {
      throw AdminException(
          'Une transaction ${tx.status.label.toLowerCase()} ne peut plus être annulée.');
    }
    final r = reason.trim();
    if (r.isEmpty) throw AdminException('Indiquez un motif d’annulation.', field: 'reason');
    await _save(db, id, {'status': TransactionStatus.cancelled.name, 'cancelReason': r});
  }

  // -------------------------------------------------------------- Paiements

  /// Échéances d'une transaction, dans l'ordre du calendrier.
  Future<List<Payment>> payments(int transactionId) async {
    final rows = await (await _db).query('payments',
        where: 'transactionId = ?', whereArgs: [transactionId], orderBy: 'dueDate, id');
    return rows.map(Payment.fromMap).toList();
  }

  /// Somme encaissée (« Reste à payer » du formulaire de paiement).
  Future<double> paidAmount(int transactionId) async {
    final rows = await (await _db).rawQuery(
        'SELECT COALESCE(SUM(amount), 0) AS paid FROM payments '
        'WHERE transactionId = ? AND paidDate IS NOT NULL',
        [transactionId]);
    return (rows.first['paid'] as num).toDouble();
  }

  /// Ajoute une échéance (« + Ajouter » du détail). Le libellé est déduit de
  /// la position (« Tranche 4 »…) quand [label] est absent.
  Future<int> insertPayment(
    int transactionId, {
    String? label,
    required double amount,
    required DateTime dueDate,
    DateTime? paidDate,
    PaymentMethod? method,
  }) async {
    final db = await _db;
    final tx = (await _get(db, transactionId)).transaction;
    if (tx.isFinal) {
      throw AdminException(
          'Une transaction ${tx.status.label.toLowerCase()} n’accepte plus de paiement.');
    }
    if (amount <= 0) throw AdminException('Indiquez un montant supérieur à 0.', field: 'amount');
    final l = label?.trim();
    final count = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM payments WHERE transactionId = ?',
          [transactionId],
        )) ??
        0;
    return db.insert('payments', {
      'transactionId': transactionId,
      'label': l == null || l.isEmpty ? 'Tranche ${count + 1}' : l,
      'amount': amount,
      'dueDate': dueDate.millisecondsSinceEpoch,
      'paidDate': paidDate?.millisecondsSinceEpoch,
      'method': paidDate == null ? null : method?.name,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Enregistre une échéance. [paid] à true encaisse le paiement (date et
  /// méthode), à false il repasse « en attente » ou « en retard » selon
  /// l'échéance. Un montant modifié de plus de 5 % déclenche l'alerte
  /// « Paiement différent de l'attendu » (maquette « Paiement »).
  Future<void> updatePayment(
    int id, {
    required double amount,
    required DateTime dueDate,
    required bool paid,
    DateTime? paidDate,
    PaymentMethod? method,
  }) async {
    final db = await _db;
    final rows = await db.query('payments', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) throw AdminException('Paiement introuvable.');
    final current = Payment.fromMap(rows.first);
    final tx = (await _get(db, current.transactionId)).transaction;
    if (tx.isFinal) {
      throw AdminException(
          'Une transaction ${tx.status.label.toLowerCase()} n’accepte plus de paiement.');
    }
    if (amount <= 0) throw AdminException('Indiquez un montant supérieur à 0.', field: 'amount');
    await db.update(
        'payments',
        {
          'amount': amount,
          'dueDate': dueDate.millisecondsSinceEpoch,
          'paidDate': paid ? (paidDate ?? DateTime.now()).millisecondsSinceEpoch : null,
          'method': paid ? method?.name : null,
        },
        where: 'id = ?',
        whereArgs: [id]);
    if (amount != current.amount) {
      await AnomalyDetector.onPaymentUpdated(db, id, previousAmount: current.amount);
    }
  }

  // ---------------------------------------------------------------- Interne

  String _validate({
    required String clientName,
    required double amount,
    required double commissionRate,
    required DateTime startDate,
    DateTime? endDate,
  }) {
    final name = clientName.trim();
    if (name.isEmpty) {
      throw AdminException('Indiquez le client de la transaction.', field: 'client');
    }
    if (amount <= 0) {
      throw AdminException('Indiquez un montant supérieur à 0.', field: 'amount');
    }
    if (commissionRate < commissionMinPercent / 100 ||
        commissionRate > commissionMaxPercent / 100) {
      throw AdminException(
          'Le taux de commission doit être entre '
          '${formatRate(commissionMinPercent / 100)} % '
          'et ${formatRate(commissionMaxPercent / 100)} %.',
          field: 'commission');
    }
    if (endDate != null && endDate.isBefore(startDate)) {
      throw AdminException('La date de fin doit suivre la date de début.', field: 'endDate');
    }
    return name;
  }

  /// Le bien doit appartenir à l'agence, être disponible et libre de toute
  /// autre transaction ouverte.
  Future<void> _ensurePropertyFree(Database db,
      {required int agencyId, required int propertyId, int? excludeTransactionId}) async {
    final rows = await db.query('properties',
        columns: ['agencyId', 'status'], where: 'id = ?', whereArgs: [propertyId]);
    if (rows.isEmpty || rows.first['agencyId'] != agencyId) {
      throw AdminException('Ce bien n’appartient pas à l’agence.', field: 'property');
    }
    final status = PropertyStatus.values.byName(rows.first['status'] as String);
    if (status != PropertyStatus.available) {
      throw AdminException(
          'Ce bien est ${status.label.toLowerCase()} : choisissez un bien disponible.',
          field: 'property');
    }
    final open = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM transactions WHERE propertyId = ? AND status IN (?, ?, ?)'
          '${excludeTransactionId == null ? '' : ' AND id <> ?'}',
          [propertyId, ..._activeStatuses, ?excludeTransactionId],
        )) ??
        0;
    if (open > 0) {
      throw AdminException('Ce bien a déjà une transaction en cours.', field: 'property');
    }
  }

  /// Rattache la transaction au compte client quand le nom saisi correspond
  /// (« Yassine Trabelsi ») : historique et notifications côté client.
  Future<int?> _clientByName(Database db, String name) async {
    final rows = await db.query('users',
        columns: ['id'],
        where: 'role = ? AND isActive = 1 AND fullName = ? COLLATE NOCASE',
        whereArgs: [UserRole.client.name, name],
        limit: 1);
    return rows.isEmpty ? null : rows.first['id'] as int;
  }

  Future<TransactionDetails> _get(Database db, int id) async {
    final rows = await db.rawQuery('$selectDetails WHERE t.id = ?', [id]);
    if (rows.isEmpty) throw AdminException('Transaction introuvable.');
    return detailsFromRow(rows.first);
  }

  Future<void> _save(Database db, int id, Map<String, Object?> values) => db.update(
      'transactions', {...values, 'updatedAt': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?', whereArgs: [id]);

  String? _clean(String? value) {
    final v = value?.trim();
    return v == null || v.isEmpty ? null : v;
  }
}
