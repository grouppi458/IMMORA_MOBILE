import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:immora_mobile/core/database/database_helper.dart';
import 'package:immora_mobile/core/errors/app_exception.dart';
import 'package:immora_mobile/core/utils/constants.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/module_authentification/repositories/agent_performance_repository.dart';
import 'package:immora_mobile/module_gestion_annonces/models/app_notification.dart';
import 'package:immora_mobile/module_gestion_annonces/repositories/listing_repository.dart';
import 'package:immora_mobile/module_gestion_annonces/repositories/matching_repository.dart';
import 'package:immora_mobile/module_gestion_annonces/repositories/visit_repository.dart';

/// Module 6 : visites sur une vraie base SQLite (FFI), créée avec les
/// données de démonstration : le client de démo a 9 visites (2 demandées,
/// 3 confirmées, 2 effectuées dont une notée, 1 absente, 1 annulée).
void main() {
  late Database db;
  final visits = VisitRepository();
  final listings = ListingRepository();
  final matching = MatchingRepository();
  final performance = AgentPerformanceRepository();
  late int carthage;
  late int client;

  Future<int> idOf(String table, String email) async =>
      (await db.query(table, where: 'email = ?', whereArgs: [email])).first['id'] as int;

  Future<int> publishedListingId(String title) async {
    final rows = await db
        .query('listings', columns: ['id'], where: 'title = ?', whereArgs: [title], limit: 1);
    return rows.first['id'] as int;
  }

  Future<int> propertyIdOf(String listingTitle) async => (await db.query('listings',
          columns: ['propertyId'], where: 'title = ?', whereArgs: [listingTitle], limit: 1))
      .first['propertyId'] as int;

  Future<Map<String, Object?>> listingTarget(String title) async {
    final rows = await db.rawQuery(
        'SELECT l.id, l.propertyId, p.agentId FROM listings l '
        'JOIN properties p ON p.id = l.propertyId WHERE l.title = ? LIMIT 1',
        [title]);
    return rows.first;
  }

  /// [days] jours à partir d'aujourd'hui, au créneau [slot] ('10:30').
  DateTime dayAt(int days, String slot) {
    final parts = slot.split(':').map(int.parse).toList();
    final n = DateTime.now().add(Duration(days: days));
    return DateTime(n.year, n.month, n.day, parts[0], parts[1]);
  }

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Répertoire distinct de celui des tests M5 : les suites s'exécutent en
    // parallèle et chacune supprime puis recrée la base de démonstration.
    await databaseFactoryFfi.setDatabasesPath(join(
        Directory.current.path, '.dart_tool', 'sqflite_common_ffi', 'databases-visits-tests'));
    await databaseFactory.deleteDatabase(join(await getDatabasesPath(), dbName));
    db = await DatabaseHelper.instance.database;
    carthage = await idOf('agencies', 'agence@immora.tn');
    client = await idOf('users', 'client@immora.tn');
  });

  Matcher throwsAdmin([String? field]) => throwsA(
      isA<AdminException>().having((e) => e.field, 'field', field ?? anything));

  test('démo : 9 visites, dont une notée, une absente et une annulée', () async {
    final all = await visits.clientVisits(client);
    expect(all, hasLength(9));

    final byStatus = <VisitStatus, int>{};
    for (final v in all) {
      byStatus.update(v.visit.status, (n) => n + 1, ifAbsent: () => 1);
    }
    expect(byStatus[VisitStatus.requested], 2);
    expect(byStatus[VisitStatus.confirmed], 3);
    expect(byStatus[VisitStatus.done], 2);
    expect(byStatus[VisitStatus.absent], 1);
    expect(byStatus[VisitStatus.cancelled], 1);

    expect(all.every((v) => v.agencyName == 'Carthage Immobilier'), isTrue);
    expect(all.every((v) => v.displayTitle.isNotEmpty), isTrue);

    // La visite notée porte note, commentaire et compte rendu de l'agent.
    final rated = all.firstWhere((v) => v.visit.isRated);
    expect(rated.visit.rating, 4);
    expect(rated.visit.ratingComment, contains('Agent ponctuel'));
    expect(rated.visit.agentNote, contains('420'));

    // Une effectuée reste « à noter » (invitation de la maquette).
    expect(all.any((v) => v.visit.status == VisitStatus.done && !v.visit.isRated), isTrue);

    final cancelled = all.firstWhere((v) => v.visit.status == VisitStatus.cancelled);
    expect(cancelled.visit.cancelReason, contains('Indisponibilité'));

    // Les deux biens effectués sortent de « Pour vous » (BF5.8).
    final visited = await matching.visitedPropertyIds(client);
    expect(visited, contains(await propertyIdOf('S+3 familial à El Menzah 5')));
    expect(visited, contains(await propertyIdOf('S+3 meublé avec vue à Carthage')));
  });

  test('créneaux pris : visites ouvertes de l’agent du bien, ce jour-là', () async {
    // Agent du S+3 de L'Aouina : L'Aouina 10:00 et Villa La Marsa 15:30 le
    // jour J+2 (les 11:00 d'El Menzah 6 appartiennent à un autre agent).
    final aouina = await publishedListingId('S+3 spacieux à L’Aouina');
    expect(await visits.slotsTaken(listingId: aouina, day: dayAt(2, '00:00')), {600, 930});

    final ennasrConfirmed = await publishedListingId('S+2 récent à Ennasr');
    expect(await visits.slotsTaken(listingId: ennasrConfirmed, day: dayAt(3, '00:00')), {1020});

    // L'agent du S+1 d'Ennasr 2 n'a aucune visite ce jour-là.
    final ennasrRent = await publishedListingId('S+1 moderne à louer à Ennasr 2');
    expect(await visits.slotsTaken(listingId: ennasrRent, day: dayAt(2, '00:00')), isEmpty);
  });

  test('demande : visite en attente assignée à l’agent du bien', () async {
    final listingId = await publishedListingId('S+1 moderne à louer à Ennasr 2');
    final before = await visits.pendingCount(carthage);
    final id = await visits.request(
        clientId: client, listingId: listingId, scheduledAt: dayAt(1, '10:30'), note: 'Merci !');

    final created =
        (await visits.clientVisits(client)).firstWhere((v) => v.visit.id == id);
    expect(created.visit.status, VisitStatus.requested);
    expect(created.visit.clientNote, 'Merci !');
    expect(created.visit.scheduledAt, dayAt(1, '10:30').millisecondsSinceEpoch);
    expect(created.visit.agentId,
        (await listingTarget('S+1 moderne à louer à Ennasr 2'))['agentId']);

    // Côté agence : la demande est comptée et visible.
    expect(await visits.pendingCount(carthage), before + 1);
    final pending = await visits.agencyVisits(carthage, status: VisitStatus.requested);
    expect(pending.any((v) => v.visit.id == id), isTrue);

    // … et la vue par agent filtre strictement.
    expect(await visits.agencyVisits(carthage, agentId: created.visit.agentId! + 999), isEmpty);
  });

  test('demande : refuse doublon, annonce hors ligne et créneau passé', () async {
    final ennasr = await publishedListingId('S+1 moderne à louer à Ennasr 2');
    expect(() => visits.request(clientId: client, listingId: ennasr, scheduledAt: dayAt(1, '12:00')),
        throwsAdmin()); // visite déjà en cours sur ce bien

    final lac = await publishedListingId('Bel S+2 lumineux aux Berges du Lac 2');
    expect(() => visits.request(clientId: client, listingId: lac, scheduledAt: dayAt(1, '09:00')),
        throwsAdmin()); // demande de démo déjà en cours sur ce bien

    final draft = (await listings.agencyListings(carthage, status: ListingStatus.draft)).first;
    expect(
        () => visits.request(
            clientId: client, listingId: draft.listing.id!, scheduledAt: dayAt(1, '09:00')),
        throwsAdmin());

    final published = await publishedListingId('Penthouse avec piscine privée');
    expect(
        () => visits.request(
            clientId: client,
            listingId: published,
            scheduledAt: DateTime.now().subtract(const Duration(hours: 1))),
        throwsAdmin('slot'));
  });

  test('conflit d’agent : deux visites en cours au même créneau refusées', () async {
    // El Menzah 5 et S+2 récent à Ennasr partagent le même agent : sa visite
    // confirmée de démo occupe le créneau de dans 3 jours à 17:00.
    final menzah5 = await listingTarget('S+3 familial à El Menzah 5');
    final ennasr = await listingTarget('S+2 récent à Ennasr');
    expect(menzah5['agentId'], ennasr['agentId']);

    expect(
        () => visits.request(
            clientId: client, listingId: menzah5['id'] as int, scheduledAt: dayAt(3, '17:00')),
        throwsAdmin('slot'));
  });

  test('cycle : confirmer, reprogrammer, effectuer (notifications incluses)', () async {
    final listingId = await publishedListingId('S+3 familial à El Menzah 5');
    final propertyId = await propertyIdOf('S+3 familial à El Menzah 5');
    final id = await visits.request(
        clientId: client, listingId: listingId, scheduledAt: dayAt(1, '14:00'));

    final beforeNotifs = (await matching.notifications(client)).length;
    await visits.confirm(id);
    expect(
        (await visits.clientVisits(client)).firstWhere((v) => v.visit.id == id).visit.status,
        VisitStatus.confirmed);
    final afterConfirm = await matching.notifications(client);
    expect(afterConfirm, hasLength(beforeNotifs + 1));
    expect(afterConfirm.first.type, AppNotification.visitConfirmed);

    await visits.reschedule(id, dayAt(1, '16:00'));
    final rescheduled = (await visits.clientVisits(client)).firstWhere((v) => v.visit.id == id);
    expect(rescheduled.visit.scheduledAt, dayAt(1, '16:00').millisecondsSinceEpoch);
    expect(rescheduled.visit.status, VisitStatus.confirmed);

    await visits.markDone(id);
    final done = (await visits.clientVisits(client)).firstWhere((v) => v.visit.id == id);
    expect(done.visit.status, VisitStatus.done);
    expect(done.visit.doneAt, isNotNull);
    expect(await matching.visitedPropertyIds(client), contains(propertyId));

    // La performance des agents (M1) compte la visite effectuée.
    final since = DateTime.now().subtract(const Duration(days: 30));
    final ranking = await performance.ranking(agencyId: carthage, since: since);
    expect(ranking.fold<int>(0, (sum, p) => sum + p.visits), greaterThanOrEqualTo(1));
  });

  test('absente : l’agence signale un no-show et le client est notifié', () async {
    final notifCount = (await matching.notifications(client)).length;
    final confirmed = (await visits.clientVisits(client)).firstWhere(
        (v) => v.visit.status == VisitStatus.confirmed && v.displayTitle == 'S+2 récent à Ennasr');

    await visits.markAbsent(confirmed.visit.id!);
    expect(
        (await visits.clientVisits(client))
            .firstWhere((v) => v.visit.id == confirmed.visit.id)
            .visit
            .status,
        VisitStatus.absent);

    final notifs = await matching.notifications(client);
    expect(notifs, hasLength(notifCount + 1));
    expect(notifs.map((n) => n.type), contains(AppNotification.visitAbsent));
  });

  test('notation : note 1–5 du client et compte rendu de l’agent', () async {
    final all = await visits.clientVisits(client);
    final toRate = all.firstWhere((v) => v.visit.status == VisitStatus.done && !v.visit.isRated);

    await visits.rate(toRate.visit.id!, rating: 5, comment: 'Visite très agréable.');
    var rated = (await visits.clientVisits(client)).firstWhere((v) => v.visit.id == toRate.visit.id);
    expect(rated.visit.rating, 5);
    expect(rated.visit.ratingComment, 'Visite très agréable.');

    // La note peut être modifiée ; le commentaire vidé.
    await visits.rate(toRate.visit.id!, rating: 3);
    rated = (await visits.clientVisits(client)).firstWhere((v) => v.visit.id == toRate.visit.id);
    expect(rated.visit.rating, 3);
    expect(rated.visit.ratingComment, isNull);

    expect(() => visits.rate(toRate.visit.id!, rating: 0), throwsAdmin('rating'));
    expect(() => visits.rate(toRate.visit.id!, rating: 6), throwsAdmin('rating'));

    final requested = all.firstWhere((v) => v.visit.status == VisitStatus.requested);
    expect(() => visits.rate(requested.visit.id!, rating: 4), throwsAdmin());

    await visits.saveAgentNote(toRate.visit.id!, 'Client très ponctuel, à relancer.');
    final noted =
        (await visits.clientVisits(client)).firstWhere((v) => v.visit.id == toRate.visit.id);
    expect(noted.visit.agentNote, 'Client très ponctuel, à relancer.');
  });

  test('annulation : par l’agence notifie le client, par le client non', () async {
    var notifCount = (await matching.notifications(client)).length;

    // Annulation par l'agence d'une demande de démo → notification.
    final demoRequested = (await visits.clientVisits(client))
        .firstWhere((v) => v.visit.status == VisitStatus.requested);
    await visits.cancel(demoRequested.visit.id!, reason: 'Le bien est déjà réservé ce jour-là');
    notifCount++;
    final notifs = await matching.notifications(client);
    expect(notifs, hasLength(notifCount));
    expect(notifs.first.type, AppNotification.visitCancelled);
    expect(notifs.first.body, contains('Le bien est déjà réservé'));

    // Annulation par le client lui-même → pas de notification.
    final penthouse = await publishedListingId('Penthouse avec piscine privée');
    final clientVisit = await visits.request(
        clientId: client, listingId: penthouse, scheduledAt: dayAt(1, '13:00'));
    await visits.cancel(clientVisit, reason: 'empêchement', notifyClient: false);
    expect(await matching.notifications(client), hasLength(notifCount));
    expect(
        (await visits.clientVisits(client))
            .firstWhere((v) => v.visit.id == clientVisit)
            .visit
            .status,
        VisitStatus.cancelled);
  });

  test('transitions impossibles : lever une AdminException', () async {
    final all = await visits.clientVisits(client);
    final done = all.firstWhere((v) => v.visit.status == VisitStatus.done).visit.id!;

    expect(() => visits.confirm(done), throwsAdmin());
    expect(() => visits.markDone(done), throwsAdmin());
    expect(() => visits.reschedule(done, dayAt(1, '11:00')), throwsAdmin());
    expect(() => visits.markAbsent(done), throwsAdmin());
    expect(() => visits.cancel(done, reason: 'x'), throwsAdmin());

    final requested =
        all.firstWhere((v) => v.visit.status == VisitStatus.requested).visit.id!;
    expect(() => visits.reschedule(requested, dayAt(1, '12:00')), throwsAdmin());
    expect(() => visits.markAbsent(requested), throwsAdmin());
  });
}
