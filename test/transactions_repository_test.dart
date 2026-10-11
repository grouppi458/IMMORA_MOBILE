import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:immora_mobile/core/database/database_helper.dart';
import 'package:immora_mobile/core/errors/app_exception.dart';
import 'package:immora_mobile/core/utils/constants.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/module_gestion_annonces/repositories/listing_repository.dart';
import 'package:immora_mobile/module_gestion_ventes/models/payment.dart';
import 'package:immora_mobile/module_gestion_ventes/repositories/alert_repository.dart';
import 'package:immora_mobile/module_gestion_ventes/repositories/transaction_repository.dart';

/// Module 4 : transactions, paiements et alertes d'anomalie sur une vraie
/// base SQLite (FFI), créée avec les données de démonstration — cinq
/// transactions dans tous les statuts et cinq alertes dont trois non lues.
void main() {
  late Database db;
  final txns = TransactionRepository();
  final alerts = AlertRepository();
  final listings = ListingRepository();
  late int carthage;

  Future<int> idOf(String table, String email) async =>
      (await db.query(table, where: 'email = ?', whereArgs: [email])).first['id'] as int;

  Future<int> propertyIdOf(String title) async =>
      (await db.query('properties', columns: ['id'], where: 'title = ?', whereArgs: [title]))
          .first['id'] as int;

  Future<int> txIdByRef(int ref) async =>
      (await db.query('transactions', columns: ['id'], where: 'ref = ?', whereArgs: [ref]))
          .first['id'] as int;

  Future<PropertyStatus> propertyStatus(int id) async {
    final rows =
        await db.query('properties', columns: ['status'], where: 'id = ?', whereArgs: [id]);
    return PropertyStatus.values.byName(rows.first['status'] as String);
  }

  Future<ListingStatus> listingStatus(String title) async {
    final rows =
        await db.query('listings', columns: ['status'], where: 'title = ?', whereArgs: [title]);
    return ListingStatus.values.byName(rows.first['status'] as String);
  }

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Répertoire distinct des autres suites : chaque fichier supprime puis
    // recrée sa propre base de démonstration.
    await databaseFactoryFfi.setDatabasesPath(join(Directory.current.path, '.dart_tool',
        'sqflite_common_ffi', 'databases-transactions-tests'));
    await databaseFactory.deleteDatabase(join(await getDatabasesPath(), dbName));
    db = await DatabaseHelper.instance.database;
    carthage = await idOf('agencies', 'agence@immora.tn');
  });

  Matcher throwsAdmin([String? field]) => throwsA(
      isA<AdminException>().having((e) => e.field, 'field', field ?? anything));

  test('démo : cinq transactions triées comme la maquette', () async {
    final all = await txns.agencyTransactions(carthage);
    expect(all.map((d) => d.transaction.displayRef),
        ['#1042', '#1024', '#1031', '#1017', '#1009']);

    // « Toutes / Ventes / Locations » et les puces de statut.
    expect(await txns.agencyTransactions(carthage, dealType: DealType.sale), hasLength(4));
    expect(await txns.agencyTransactions(carthage, dealType: DealType.rent), hasLength(1));
    expect(
        (await txns.agencyTransactions(carthage, status: TransactionStatus.draft))
            .map((d) => d.transaction.displayRef),
        ['#1017']);

    final villa = all.first;
    expect(villa.propertyTitle, 'Villa avec piscine · Gammarth');
    expect(villa.agentName, 'Sirine Ben Salah');
    expect(villa.propertyPrice, 1250000);
    expect(villa.transaction.amountLabel, '${formatNumber(1250000)} TND');
    expect(villa.transaction.shortClient, 'Y. Trabelsi');
    expect(villa.transaction.commissionAmount, closeTo(37500, 0.001));

    final rent = all[1];
    expect(rent.transaction.amountLabel, '${formatNumber(1800)} TND/mois');
    expect(rent.transaction.status, TransactionStatus.signed);
  });

  test('démo : échéancier de la villa et statut déduit des dates', () async {
    final villaId = await txIdByRef(1042);
    final payments = await txns.payments(villaId);
    expect(payments.map((p) => p.label), ['Acompte', 'Tranche 2', 'Solde']);

    expect(payments[0].status, PaymentStatus.paid);
    expect(payments[0].subtitle, startsWith('Payé le'));
    expect(payments[0].subtitle, contains('virement'));
    expect(payments[1].status, PaymentStatus.late);
    expect(payments[1].lateDays, 12);
    expect(payments[1].subtitle, contains('12 j de retard'));
    expect(payments[2].status, PaymentStatus.pending);
    expect(payments[2].subtitle, startsWith('Échéance'));

    expect(await txns.paidAmount(villaId), 250000);
    expect(await txns.paidAmount(await txIdByRef(1031)), 320000);
  });

  test('formulaire : seuls les biens disponibles sans transaction ouverte', () async {
    final titles = (await txns.propertyOptions(carthage)).map((o) => o.$2).toList();
    expect(titles, contains('Terrain constructible à La Soukra')); // annulée = libre
    expect(titles, isNot(contains('Villa avec piscine · Gammarth'))); // en cours
    expect(titles, isNot(contains('Duplex Carthage'))); // brouillon
    expect(titles, isNot(contains('Bureau · Centre Urbain Nord'))); // vendu
    expect(titles, isNot(contains('Appartement S+2 · Marsa'))); // loué

    // En modification, la transaction affiche son propre bien.
    final dupTitles = (await txns.propertyOptions(carthage,
            currentTransactionId: await txIdByRef(1017)))
        .map((o) => o.$2);
    expect(dupTitles, contains('Duplex Carthage'));
  });

  test('démo : cinq alertes classées par gravité puis date, trois non lues', () async {
    final list = await alerts.list(carthage);
    expect(list.map((a) => a.title).toList(), [
      'Montant très éloigné de l’habitude',
      'Prix final éloigné du prix affiché',
      'Activité inhabituelle d’un agent',
      'Paiement différent de l’attendu',
      'Paiement en retard',
    ]);
    expect(list.map((a) => a.severity).toList(), [
      AlertSeverity.high,
      AlertSeverity.medium,
      AlertSeverity.medium,
      AlertSeverity.medium,
      AlertSeverity.low,
    ]);

    // Détails de la maquette « Alerte » (z-score de la villa).
    final outlier = list.first;
    expect(outlier.details['Montant'], '${formatNumber(1250000)} TND');
    expect(outlier.details['z-score'], '3,1 (seuil 2,5)');
    expect(outlier.details['Historique'], '38 ventes (min. 5)');
    expect(outlier.transactionId, await txIdByRef(1042));
    expect(outlier.isRead, isFalse);

    // Un retard (Low) est le plus récent mais ferme la liste ; la répétition
    // de l'analyse ne crée pas de doublon (tranche 2 toujours impayée).
    expect(list.last.subtitle, 'Tranche 2 · #1042 · 12 j');

    final counts = await alerts.counts(carthage);
    expect(counts.total, 5);
    expect(counts.unread, 3);
    expect(counts.bySeverity[AlertSeverity.high], 1);
    expect(counts.bySeverity[AlertSeverity.medium], 3);
    expect(counts.bySeverity[AlertSeverity.low], 1);

    expect(await alerts.list(carthage, unreadOnly: true), hasLength(3));
    expect(await alerts.list(carthage, severity: AlertSeverity.high), hasLength(1));

    // « Marquer comme lue » puis le ✓ de l'en-tête.
    await alerts.markRead(outlier.id!);
    expect((await alerts.counts(carthage)).unread, 2);
    await alerts.markAllRead(carthage);
    expect((await alerts.counts(carthage)).unread, 0);
  });

  test('création : contrôle de saisie et bien libre exigé', () async {
    final soukra = await propertyIdOf('Terrain constructible à La Soukra');
    final start = DateTime.now();
    Future<int> attempt({int? propertyId, String client = 'Yassine Trabelsi',
        double amount = 380000, double rate = 0.03, DateTime? endDate}) =>
        txns.create(
            agencyId: carthage,
            propertyId: propertyId ?? soukra,
            clientName: client,
            dealType: DealType.sale,
            amount: amount,
            commissionRate: rate,
            startDate: start,
            endDate: endDate);

    expect(() => attempt(client: '  '), throwsAdmin('client'));
    expect(() => attempt(amount: 0), throwsAdmin('amount'));
    expect(() => attempt(rate: 0.5), throwsAdmin('commission'));
    expect(() => attempt(endDate: start.subtract(const Duration(days: 1))),
        throwsAdmin('endDate'));

    // Bien déjà engagé, vendu, loué ou d'une autre agence.
    final stolen = await propertyIdOf('Villa avec piscine · Gammarth');
    final sold = await propertyIdOf('Bureau · Centre Urbain Nord');
    final rented = await propertyIdOf('Appartement S+2 · Marsa');
    final otherAgency = await propertyIdOf('Villa pieds dans l’eau à Gammarth');
    expect(() => attempt(propertyId: stolen), throwsAdmin('property'));
    expect(() => attempt(propertyId: sold), throwsAdmin('property'));
    expect(() => attempt(propertyId: rented), throwsAdmin('property'));
    expect(() => attempt(propertyId: otherAgency), throwsAdmin('property'));
  });

  test('création : référence suivante, commission et client rattaché', () async {
    final id = await txns.create(
        agencyId: carthage,
        propertyId: await propertyIdOf('Terrain constructible à La Soukra'),
        clientName: 'Yassine Trabelsi',
        dealType: DealType.sale,
        amount: 380000,
        commissionRate: 0.03,
        startDate: DateTime.now());
    final d = await txns.details(id);
    expect(d.transaction.ref, 1043);
    expect(d.transaction.status, TransactionStatus.draft);
    expect(d.transaction.clientId, await idOf('users', 'client@immora.tn'));
    expect(d.transaction.commissionAmount, closeTo(380000 * 0.03, 0.001));
    expect((await txns.propertyOptions(carthage)).map((o) => o.$2),
        isNot(contains('Terrain constructible à La Soukra')));

    // Annulation : motif exigé, avant signature uniquement.
    expect(() => txns.cancel(id, reason: '  '), throwsAdmin('reason'));
    await txns.cancel(id, reason: 'Erreur de saisie.');
    expect((await txns.details(id)).transaction.cancelReason, 'Erreur de saisie.');
    expect(() => txns.activate(id), throwsAdmin());
  });

  test('vente : signer passe le bien en « Vendu » et retire son annonce (BF5.4)', () async {
    final heroId = await propertyIdOf('Appartement S+3 · Lac');
    final id = await txns.create(
        agencyId: carthage,
        propertyId: heroId,
        clientName: 'Nadia Khelifi',
        dealType: DealType.sale,
        amount: 485000,
        commissionRate: 0.03,
        startDate: DateTime.now());

    expect(() => txns.sign(id), throwsAdmin()); // brouillon, pas encore signable
    await txns.activate(id);
    expect(() => txns.activate(id), throwsAdmin()); // déjà en cours

    await txns.sign(id);
    final signed = await txns.details(id);
    expect(signed.transaction.status, TransactionStatus.signed);
    expect(signed.transaction.signedAt, isNotNull);
    expect(await propertyStatus(heroId), PropertyStatus.sold);

    // L'annonce publiée du bien vendu est retirée à la prochaine lecture.
    await listings.agencyListings(carthage);
    expect(await listingStatus('Appartement S+3 aux Berges du Lac'), ListingStatus.withdrawn);

    expect(() => txns.cancel(id, reason: 'trop tard'), throwsAdmin());
    await txns.complete(id);
    expect((await txns.details(id)).transaction.status, TransactionStatus.completed);
    expect(await propertyStatus(heroId), PropertyStatus.sold); // une vente reste vendue
  });

  test('location : la signature loue le bien, la fin le libère', () async {
    final flatId = await propertyIdOf('Appartement meublé à Carthage');
    final id = await txns.create(
        agencyId: carthage,
        propertyId: flatId,
        clientName: 'Amine Gharbi',
        dealType: DealType.rent,
        amount: 2300,
        commissionRate: 0.04,
        startDate: DateTime.now());
    await txns.activate(id);
    await txns.sign(id);
    expect(await propertyStatus(flatId), PropertyStatus.rented);
    await txns.complete(id);
    expect(await propertyStatus(flatId), PropertyStatus.available);
  });

  test('paiements : ajout, encaissement et refus sur transaction terminée', () async {
    final villaId = await txIdByRef(1042);
    final due = DateTime.now().add(const Duration(days: 5));
    final id = await txns.insertPayment(villaId, amount: 100000, dueDate: due);
    var payments = await txns.payments(villaId);
    expect(payments, hasLength(4));
    // Trié par échéance : la nouvelle tranche s'intercale avant le solde.
    Future<Payment> added() async =>
        (await txns.payments(villaId)).firstWhere((p) => p.id == id);
    expect((await added()).label, 'Tranche 4');
    expect((await added()).status, PaymentStatus.pending);

    await txns.updatePayment(id,
        amount: 100000, dueDate: due, paid: true, method: PaymentMethod.cheque);
    expect((await added()).status, PaymentStatus.paid);
    expect(await txns.paidAmount(villaId), 350000);
    expect((await added()).subtitle, contains('chèque'));

    await txns.updatePayment(id, amount: 100000, dueDate: due, paid: false);
    expect((await added()).status, PaymentStatus.pending);
    expect(await txns.paidAmount(villaId), 250000);

    // Une transaction terminée n'accepte plus d'échéance.
    final bureauId = await txIdByRef(1031);
    final paid = (await txns.payments(bureauId)).first;
    expect(
        () => txns.insertPayment(bureauId, amount: 1000, dueDate: due),
        throwsA(isA<AdminException>()));
    expect(
        () => txns.updatePayment(paid.id!,
            amount: 1000, dueDate: due, paid: false),
        throwsA(isA<AdminException>()));
  });

  test('anomalie « prix final » : créée puis retirée après correction', () async {
    final manarId = await propertyIdOf('Appartement S+2 à El Manar 2');
    final start = DateTime.now();
    final id = await txns.create(
        agencyId: carthage,
        propertyId: manarId,
        clientName: 'Sami Bouhlel',
        dealType: DealType.rent,
        amount: 2800, // prix affiché : 1 400 TND → écart de 100 %
        commissionRate: 0.03,
        startDate: start,
        status: TransactionStatus.ongoing);

    var found = (await alerts.list(carthage))
        .where((a) => a.type == AlertType.priceGap && a.transactionId == id)
        .toList();
    expect(found, hasLength(1));
    expect(found.first.subtitle, 'Écart 100 % (> 30 %)');
    expect(found.first.severity, AlertSeverity.medium);
    expect(found.first.isRead, isFalse);
    expect(found.first.details['Prix affiché du bien'], '${formatNumber(1400)} TND');

    // Corriger le montant retire l'alerte (analyse à chaque enregistrement).
    await txns.update(id,
        propertyId: manarId,
        clientName: 'Sami Bouhlel',
        dealType: DealType.rent,
        amount: 1400,
        commissionRate: 0.03,
        startDate: start);
    found = (await alerts.list(carthage))
        .where((a) => a.type == AlertType.priceGap && a.transactionId == id)
        .toList();
    expect(found, isEmpty);

    // Historique trop court : pas d'alerte « montant inhabituel » live (les
    // cinq alertes de la maquette sont des données de démonstration).
    final ennasrId = await propertyIdOf('Appartement S+1 à Ennasr');
    final small = await txns.create(
        agencyId: carthage,
        propertyId: ennasrId,
        clientName: 'Rim Haddad',
        dealType: DealType.rent,
        amount: 1200,
        commissionRate: 0.03,
        startDate: start);
    expect(
        (await alerts.list(carthage))
            .where((a) => a.type == AlertType.amountOutlier && a.transactionId == small),
        isEmpty);
  });

  test('anomalie « paiement inattendu » : au-delà de 5 %', () async {
    final villaId = await txIdByRef(1042);
    final due = DateTime.now().add(const Duration(days: 10));
    final id = await txns.insertPayment(villaId, amount: 100000, dueDate: due);
    await txns.updatePayment(id, amount: 200000, dueDate: due, paid: false);

    var found = (await alerts.list(carthage))
        .where((a) => a.type == AlertType.paymentMismatch && a.paymentId == id)
        .toList();
    expect(found, hasLength(1));
    expect(found.first.subtitle, 'Écart 50 % (> 5 %)');
    expect(found.first.details['Échéance planifiée'], '${formatNumber(100000)} TND');
    expect(found.first.details['Montant reçu'], '${formatNumber(200000)} TND');

    // Revenir près de l'échéance retire l'alerte.
    await txns.updatePayment(id, amount: 195000, dueDate: due, paid: false);
    found = (await alerts.list(carthage))
        .where((a) => a.type == AlertType.paymentMismatch && a.paymentId == id)
        .toList();
    expect(found, isEmpty);
  });

  test('retard : alerte Low à la lecture, retirée une fois payé', () async {
    final villaId = await txIdByRef(1042);
    final due = DateTime.now().subtract(const Duration(days: 3));
    final id = await txns.insertPayment(villaId, amount: 50000, dueDate: due);

    var found = (await alerts.list(carthage))
        .where((a) => a.type == AlertType.paymentLate && a.paymentId == id)
        .toList();
    expect(found, hasLength(1));
    expect(found.first.severity, AlertSeverity.low);
    expect(found.first.subtitle, contains('· 3 j'));
    expect(found.first.isRead, isFalse);

    await txns.updatePayment(id,
        amount: 50000, dueDate: due, paid: true, method: PaymentMethod.cash);
    expect(
        (await alerts.list(carthage)).where((a) => a.paymentId == id),
        isEmpty);
  });

  test('ignorer : supprime l’alerte, recréée si le retard persiste', () async {
    final tranche2Id = (await txns.payments(await txIdByRef(1042)))
        .firstWhere((p) => p.label == 'Tranche 2')
        .id!;
    final alert = (await alerts.list(carthage))
        .firstWhere((a) => a.type == AlertType.paymentLate && a.paymentId == tranche2Id);

    await alerts.ignore(alert.id!);
    expect(
        (await alerts.list(carthage)).where((a) => a.id == alert.id),
        isEmpty);

    // La tranche 2 toujours impayée est re-signalée à la prochaine analyse.
    final again = (await alerts.list(carthage))
        .firstWhere((a) => a.type == AlertType.paymentLate && a.paymentId == tranche2Id);
    expect(again.isRead, isFalse);
    expect(again.id, isNot(alert.id));
  });
}
