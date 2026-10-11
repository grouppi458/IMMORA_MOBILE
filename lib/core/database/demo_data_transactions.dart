import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';

/// Données de démonstration du Module 4, calquées sur les maquettes Figma :
/// le duplex de la liste (absent des modules 3 et 5, créé ici en vente — son
/// écart avec le prix affiché alimente l'alerte « Prix final éloigné du prix
/// affiché »), cinq transactions dans tous les statuts — Villa Gammarth en
/// cours avec ses trois paiements échelonnés, Bureau CUN terminé, location de
/// La Marsa signée, duplex en brouillon, terrain annulé — les statuts de
/// biens qui en découlent (bien vendu / loué) et cinq alertes d'anomalie dont
/// trois non lues. S'appuie sur les biens des modules 3 et 5 ; ne fait rien
/// si des transactions existent déjà.
class DemoDataTransactions {
  DemoDataTransactions._();

  static Future<void> seed(Database db) async {
    final existing =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM transactions')) ?? 0;
    if (existing > 0) return;

    Future<int?> idWhere(String table, String column, Object value) async {
      final rows = await db.query(table,
          columns: ['id'], where: '$column = ?', whereArgs: [value], limit: 1);
      return rows.isEmpty ? null : rows.first['id'] as int;
    }

    final carthage = await idWhere('agencies', 'email', 'agence@immora.tn');
    if (carthage == null) return;
    final client = await idWhere('users', 'email', 'client@immora.tn');

    Future<int?> agentOf(String email) async {
      final rows = await db.rawQuery(
          'SELECT a.id FROM agents a JOIN users u ON u.id = a.userId WHERE u.email = ? LIMIT 1',
          [email]);
      return rows.isEmpty ? null : rows.first['id'] as int;
    }

    final sirine = await agentOf('sirine@carthage-immo.tn');
    final ahmed = await agentOf('ahmed@carthage-immo.tn');
    final sami = await agentOf('agent@immora.tn');
    final leila = await agentOf('leila@carthage-immo.tn');

    Future<int?> propertyOf(String title) => idWhere('properties', 'title', title);

    final villa = await propertyOf('Villa avec piscine · Gammarth');
    final bureau = await propertyOf('Bureau · Centre Urbain Nord');
    final marsa = await propertyOf('Appartement S+2 · Marsa');
    final terrain = await propertyOf('Terrain constructible à La Soukra');

    final now = DateTime.now();
    int ago(int days) => now.subtract(Duration(days: days)).millisecondsSinceEpoch;
    int ahead(int days) => now.add(Duration(days: days)).millisecondsSinceEpoch;

    await db.transaction((txn) async {
      Future<int?> addTransaction({
        required int ref,
        required int? propertyId,
        required int? clientId,
        required String clientName,
        required int? agentId,
        required DealType deal,
        required double amount,
        required double rate,
        required TransactionStatus status,
        required int startDate,
        int? signedAt,
        int? endDate,
        String? cancelReason,
        String? contractPath,
        required int createdAt,
        required int updatedAt,
      }) async {
        if (propertyId == null) return null;
        return txn.insert('transactions', {
          'agencyId': carthage,
          'ref': ref,
          'propertyId': propertyId,
          'clientId': clientId,
          'clientName': clientName,
          'agentId': agentId,
          'dealType': deal.name,
          'amount': amount,
          'commissionRate': rate,
          'commissionAmount': amount * rate,
          'status': status.name,
          'startDate': startDate,
          'signedAt': signedAt,
          'endDate': endDate,
          'cancelReason': cancelReason,
          'contractPath': contractPath,
          'createdAt': createdAt,
          'updatedAt': updatedAt,
        });
      }

      Future<int?> addPayment(
        int? transactionId,
        String label,
        double amount,
        int dueDate, {
        int? paidDate,
        PaymentMethod? method,
        required int createdAt,
      }) async {
        if (transactionId == null) return null;
        return txn.insert('payments', {
          'transactionId': transactionId,
          'label': label,
          'amount': amount,
          'dueDate': dueDate,
          'paidDate': paidDate,
          'method': method?.name,
          'createdAt': createdAt,
        });
      }

      Future<void> addAlert(
        AlertType type,
        AlertSeverity severity,
        String title,
        String subtitle,
        String description,
        Map<String, String> details, {
        int? transactionId,
        int? paymentId,
        required bool unread,
        required int createdAt,
      }) async {
        await txn.insert('alerts', {
          'agencyId': carthage,
          'type': type.name,
          'severity': severity.name,
          'title': title,
          'subtitle': subtitle,
          'description': description,
          'details': jsonEncode(details),
          'transactionId': transactionId,
          'paymentId': paymentId,
          'isRead': unread ? 0 : 1,
          'createdAt': createdAt,
        });
      }

      // ---------- Biens ----------
      // Le duplex de la maquette « Transactions » (vente 720 000 en
      // brouillon) n'existe pas dans les modules 3 et 5 : son prix affiché —
      // 537 000 TND, soit un écart de 34 % — alimente l'alerte « Prix final
      // éloigné du prix affiché ».
      final duplex = await txn.insert('properties', {
        'agencyId': carthage,
        'agentId': leila,
        'title': 'Duplex Carthage',
        'type': PropertyType.house.name,
        'dealType': DealType.sale.name,
        'price': 537000,
        'surface': 210,
        'rooms': 4,
        'bathrooms': 2,
        'city': 'Carthage',
        'district': 'Amilcar',
        'address': 'Rue d’Amilcar, Carthage',
        'latitude': 36.8560,
        'longitude': 10.3230,
        'amenities': '',
        'condition': PropertyCondition.good.name,
        'description': 'Duplex de 210 m² sur deux niveaux à Amilcar : quatre chambres, '
            'double séjour ouvert et terrasse. Quartier calme à quelques minutes '
            'de la mer.',
        'status': PropertyStatus.available.name,
        'createdAt': ago(8),
      });

      // ---------- Transactions ----------
      // En cours : négociation, acompte reçu, contrat à signer (#1042).
      final villaTx = await addTransaction(
        ref: 1042,
        propertyId: villa,
        clientId: client,
        clientName: 'Yassine Trabelsi',
        agentId: sirine,
        deal: DealType.sale,
        amount: 1250000,
        rate: 0.03,
        status: TransactionStatus.ongoing,
        startDate: ago(15),
        contractPath: 'contrat_1042.pdf',
        createdAt: ago(15),
        updatedAt: ago(1),
      );
      // Terminée : bien passé en « Vendu », entièrement payée (#1031).
      final bureauTx = await addTransaction(
        ref: 1031,
        propertyId: bureau,
        clientId: null,
        clientName: 'Karim Bouazizi',
        agentId: sirine,
        deal: DealType.sale,
        amount: 320000,
        rate: 0.03,
        status: TransactionStatus.completed,
        startDate: ago(67),
        signedAt: ago(52),
        endDate: ago(44),
        contractPath: 'contrat_1031.pdf',
        createdAt: ago(70),
        updatedAt: ago(44),
      );
      // Signée : la location passe le bien en « Loué ».
      await addTransaction(
        ref: 1024,
        propertyId: marsa,
        clientId: null,
        clientName: 'Amine Gharbi',
        agentId: ahmed,
        deal: DealType.rent,
        amount: 1800,
        rate: 0.04,
        status: TransactionStatus.signed,
        startDate: ago(11),
        signedAt: ago(9),
        endDate: ahead(356),
        createdAt: ago(12),
        updatedAt: ago(9),
      );
      // Brouillon : non finalisée, le bien reste disponible (#1017).
      final duplexTx = await addTransaction(
        ref: 1017,
        propertyId: duplex,
        clientId: null,
        clientName: 'Walid Chaabane',
        agentId: leila,
        deal: DealType.sale,
        amount: 720000,
        rate: 0.025,
        status: TransactionStatus.draft,
        startDate: ago(4),
        createdAt: ago(4),
        updatedAt: ago(4),
      );
      // Annulée par le client (#1009).
      await addTransaction(
        ref: 1009,
        propertyId: terrain,
        clientId: null,
        clientName: 'Slim Mrad',
        agentId: sami,
        deal: DealType.sale,
        amount: 380000,
        rate: 0.03,
        status: TransactionStatus.cancelled,
        startDate: ago(95),
        cancelReason: 'Annulée par le client.',
        createdAt: ago(99),
        updatedAt: ago(90),
      );

      // ---------- Paiements ----------
      // Villa Gammarth (#1042) : acompte payé, tranche 2 en retard (12 jours,
      // même échéance que la maquette), solde à venir.
      final acompte = await addPayment(villaTx, 'Acompte', 250000, ago(13),
          paidDate: ago(13), method: PaymentMethod.transfer, createdAt: ago(15));
      final tranche2 =
          await addPayment(villaTx, 'Tranche 2', 500000, ago(12), createdAt: ago(15));
      await addPayment(villaTx, 'Solde', 500000, ahead(19), createdAt: ago(15));
      // Bureau CUN (#1031) : soldé à la signature du dossier (64 000 + 256 000).
      await addPayment(bureauTx, 'Acompte', 64000, ago(64),
          paidDate: ago(63), method: PaymentMethod.transfer, createdAt: ago(70));
      await addPayment(bureauTx, 'Solde', 256000, ago(46),
          paidDate: ago(45), method: PaymentMethod.transfer, createdAt: ago(63));

      // ---------- Statuts des biens (règles de la signature) ----------
      if (marsa != null) {
        await txn.update('properties', {'status': PropertyStatus.rented.name},
            where: 'id = ?', whereArgs: [marsa]);
      }
      if (bureau != null) {
        await txn.update('properties', {'status': PropertyStatus.sold.name},
            where: 'id = ?', whereArgs: [bureau]);
      }

      // ---------- Alertes d'anomalie (3 non lues) ----------
      // Le tri (gravité puis date) du repository place le retard de paiement
      // — le plus récent mais Low — en fin de liste, comme la maquette.
      const lateDays = 12;
      await addAlert(
        AlertType.amountOutlier,
        AlertSeverity.high,
        'Montant très éloigné de l’habitude',
        'Villa avec piscine · Gammarth · z = 3,1',
        'Le montant s’écarte fortement de la moyenne des ventes de même type dans l’agence.',
        {
          'Montant': '${formatNumber(1250000)} TND',
          'Moyenne (agence, vente)': '${formatNumber(640000)} TND',
          'Écart-type': '${formatNumber(196000)} TND',
          'z-score': '3,1 (seuil 2,5)',
          'Historique': '38 ventes (min. 5)',
        },
        transactionId: villaTx,
        unread: true,
        createdAt: ago(2),
      );
      await addAlert(
        AlertType.priceGap,
        AlertSeverity.medium,
        'Prix final éloigné du prix affiché',
        'Écart 34 % (> 30 %)',
        'Le prix final s’écarte de 34 % du prix affiché du bien (seuil 30 %). '
            'Vérifiez le prix ou corrigez la fiche.',
        {
          'Prix final (transaction)': '${formatNumber(720000)} TND',
          'Prix affiché du bien': '${formatNumber(537000)} TND',
          'Écart': '34 % (> 30 %)',
        },
        transactionId: duplexTx,
        unread: false,
        createdAt: ago(3),
      );
      await addAlert(
        AlertType.agentActivity,
        AlertSeverity.medium,
        'Activité inhabituelle d’un agent',
        '7 transactions en 24 h (> 5)',
        'L’agent a enregistré 7 transactions sur les dernières 24 h (seuil 5). '
            'Vérifiez les éventuelles saisies en double.',
        {
          'Agent': 'Ahmed Ghorbi',
          'Transactions (24 h)': '7 (> 5)',
        },
        unread: false,
        createdAt: ago(4),
      );
      await addAlert(
        AlertType.paymentMismatch,
        AlertSeverity.medium,
        'Paiement différent de l’attendu',
        'Écart 8 % (> 5 %)',
        'Le montant reçu s’écarte de l’échéance planifiée de 8 % (seuil 5 %). '
            'Confirmez le montant avec le client.',
        {
          'Échéance planifiée': '${formatNumber(270000)} TND',
          'Montant reçu': '${formatNumber(250000)} TND',
          'Écart': '8 % (> 5 %)',
        },
        transactionId: villaTx,
        paymentId: acompte,
        unread: true,
        createdAt: ago(5),
      );
      await addAlert(
        AlertType.paymentLate,
        AlertSeverity.low,
        'Paiement en retard',
        'Tranche 2 · #1042 · $lateDays j',
        'Le paiement « Tranche 2 » de la transaction #1042 est en retard de '
            '$lateDays jours. Relancez le client pour le règlement.',
        {
          'Échéance': formatDate(ago(lateDays)),
          'Retard': '$lateDays jours',
        },
        transactionId: villaTx,
        paymentId: tranche2,
        unread: true,
        createdAt: ago(1),
      );
    });
  }
}
