import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:immora_mobile/core/database/database_helper.dart';
import 'package:immora_mobile/core/errors/app_exception.dart';
import 'package:immora_mobile/core/utils/constants.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/module_gestion_annonces/models/app_notification.dart';
import 'package:immora_mobile/module_gestion_annonces/repositories/favorite_repository.dart';
import 'package:immora_mobile/module_gestion_annonces/repositories/listing_repository.dart';
import 'package:immora_mobile/module_gestion_annonces/repositories/matching_repository.dart';
import 'package:immora_mobile/module_gestion_annonces/models/search_criteria.dart';
import 'package:immora_mobile/module_gestion_biens/repositories/property_repository.dart';

/// Module 5 : annonces et favoris sur une vraie base SQLite (FFI), créée
/// avec les données de démonstration.
void main() {
  late Database db;
  final listings = ListingRepository();
  final favorites = FavoriteRepository();
  final properties = PropertyRepository();
  final matching = MatchingRepository();
  late int carthage;
  late int client;

  Future<int> idOf(String table, String email) async =>
      (await db.query(table, where: 'email = ?', whereArgs: [email])).first['id'] as int;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.deleteDatabase(join(await getDatabasesPath(), dbName));
    db = await DatabaseHelper.instance.database;
    carthage = await idOf('agencies', 'agence@immora.tn');
    client = await idOf('users', 'client@immora.tn');
  });

  Matcher throwsAdmin([String? field]) => throwsA(isA<AdminException>()
      .having((e) => e.field, 'field', field ?? anything));

  test('la vitrine ne montre que les annonces publiées, mises en avant d’abord', () async {
    final shown = await listings.publishedListings();
    expect(shown, hasLength(10));
    expect(shown.every((d) => d.listing.status == ListingStatus.published), isTrue);
    final featured = shown.takeWhile((d) => d.listing.isFeatured).length;
    expect(featured, 3);
    expect(shown.skip(featured).any((d) => d.listing.isFeatured), isFalse);
  });

  test('l’agence voit ses annonces par statut avec vues et favoris (BF5.3)', () async {
    final counts = await listings.countByStatus(carthage);
    expect(counts[ListingStatus.published], 8);
    expect(counts[ListingStatus.draft], 1); // la boutique (le bureau, lui, est vendu)
    expect(counts[ListingStatus.suspended], 1);
    expect(counts[ListingStatus.expired], 1);
    expect(counts[ListingStatus.withdrawn], 2); // L'Aouina (vendu) et le bureau (vendu, M4)

    final published = await listings.agencyListings(carthage, status: ListingStatus.published);
    final lac = published.firstWhere((d) => d.property.district == 'Les Berges du Lac 2');
    expect(lac.favoritesCount, 1);
    expect(lac.listing.viewsCount, 128);
    expect(lac.agencyName, 'Carthage Immobilier');
    expect(lac.agencyPhone, '+21671080080');
    expect(lac.agentName, 'Sami Ben Ali'); // agent responsable du bien
  });

  test('favoris : une seule fois par annonce, seulement si publiée (BF5.2, BF5.5)', () async {
    expect(await favorites.clientFavorites(client), hasLength(3));
    final first = (await favorites.listingIds(client)).first;
    expect(await favorites.add(client, first), isFalse);

    final draft = (await listings.agencyListings(carthage, status: ListingStatus.draft)).first;
    expect(() => favorites.add(client, draft.listing.id!), throwsAdmin());

    await favorites.remove(client, first);
    expect(await favorites.isFavorite(client, first), isFalse);
    expect(await favorites.add(client, first), isTrue);
  });

  test('cycle de vie : créer, publier, suspendre, republier (BF5.1, BF5.4)', () async {
    final available = await properties.availableWithoutListing(carthage);
    // El Manar n'a jamais eu d'annonce ; celle de La Soukra est expirée,
    // donc ces biens peuvent recevoir une nouvelle annonce. S'y ajoutent les
    // biens du M3 sans annonce (villa de Gammarth, comparable du Lac) et le
    // duplex du M4.
    expect(available.map((p) => p.district),
        ['El Manar 2', 'Amilcar', 'Gammarth', 'La Soukra', 'Les Berges du Lac']);
    final property = available.first;

    final id = await listings.create(
      propertyId: property.id!,
      agencyId: carthage,
      title: 'S+2 à louer à El Manar 2',
      text: 'Appartement S+2 de 100 m² proche de la faculté, ascenseur.',
      displayedPrice: 1400,
      durationDays: 60,
    );
    expect((await listings.details(id))!.listing.status, ListingStatus.draft);
    expect((await properties.availableWithoutListing(carthage)).map((p) => p.district),
        ['Amilcar', 'Gammarth', 'La Soukra', 'Les Berges du Lac']);

    // Un bien n'a qu'une annonce en cours.
    expect(
        () => listings.create(
            propertyId: property.id!,
            agencyId: carthage,
            title: 'Doublon',
            text: 'Deuxième annonce pour le même bien, refusée.',
            displayedPrice: 1400,
            durationDays: 30),
        throwsAdmin('property'));

    await listings.publish(id);
    var l = (await listings.details(id))!.listing;
    expect(l.status, ListingStatus.published);
    expect(l.daysLeft, inInclusiveRange(59, 60));

    await listings.suspend(id);
    expect((await listings.details(id))!.listing.status, ListingStatus.suspended);
    expect(() => listings.delete(id), throwsAdmin());

    await listings.publish(id);
    await listings.setFeatured(id, true);
    l = (await listings.details(id))!.listing;
    expect(l.status, ListingStatus.published);
    expect(l.isFeatured, isTrue);
  });

  test('expiration automatique puis prolongation (BF5.4)', () async {
    final l = (await listings.agencyListings(carthage, status: ListingStatus.published)).first;
    final id = l.listing.id!;
    await db.update('listings', {'expiresAt': DateTime.now().millisecondsSinceEpoch - 1000},
        where: 'id = ?', whereArgs: [id]);

    expect((await listings.details(id))!.listing.status, ListingStatus.expired);
    expect(() => listings.extend(id, 45), throwsAdmin('duration'));

    await listings.extend(id, 30);
    final extended = (await listings.details(id))!.listing;
    expect(extended.status, ListingStatus.published);
    expect(extended.daysLeft, inInclusiveRange(29, 30));
  });

  test('bien vendu : annonce retirée, puis supprimée avec ses favoris (BF5.4, BF5.5)', () async {
    final fav = (await favorites.clientFavorites(client))
        .firstWhere((d) => d.listing.status == ListingStatus.published);
    await db.update('properties', {'status': PropertyStatus.sold.name},
        where: 'id = ?', whereArgs: [fav.property.id]);

    final id = fav.listing.id!;
    expect((await listings.details(id))!.listing.status, ListingStatus.withdrawn);
    expect(() => listings.publish(id), throwsAdmin());

    await listings.delete(id);
    expect(await listings.details(id), isNull);
    expect(await favorites.isFavorite(client, id), isFalse);
  });

  test('migration v2 → v4 : une ancienne base reçoit les tables et la démo du M5', () async {
    // La table visits (M6) référence properties et listings : elle part en premier.
    for (final table
        in ['visits', 'notifications', 'search_criteria', 'favorites', 'listings', 'properties']) {
      await db.execute('DROP TABLE $table');
    }
    await db.setVersion(2);
    await DatabaseHelper.instance.close();

    db = await DatabaseHelper.instance.database;
    expect(await db.getVersion(), dbVersion);
    expect(await listings.countByStatus(carthage), containsPair(ListingStatus.published, 8));
    expect(await matching.criteria(client), isNotNull);
    expect(await favorites.clientFavorites(client), hasLength(3));
  });

  test('démo : critères mémorisés et alertes déjà calculées (BF5.6, BF5.9)', () async {
    final c = (await matching.criteria(client))!;
    expect(c.summary, startsWith('achat · appartement · 300K–500K TND · Tunis'));
    final alerts = (await matching.notifications(client))
        .where((n) => n.type == AppNotification.newListing)
        .toList(); // Lac 2 et El Menzah 5 : 100 % (les notifications de visite du M6 ont score null)
    expect(alerts, hasLength(2));
    expect(alerts.every((n) => n.score! >= 80), isTrue);
    expect(alerts.where((n) => !n.isRead), hasLength(1));
  });

  test('publier une annonce compatible notifie le client (BF5.9)', () async {
    // Le client cherche maintenant une location à Ariana.
    await matching.saveCriteria(client,
        const SearchCriteria(dealType: DealType.rent, city: 'Ariana', minRooms: 1));
    final before = (await matching.notifications(client)).length;

    final property = (await properties.availableWithoutListing(carthage))
        .firstWhere((p) => p.district == 'La Soukra'); // terrain à vendre : exclu
    await listings.create(
        propertyId: property.id!,
        agencyId: carthage,
        title: 'Terrain à La Soukra',
        text: 'Terrain constructible de 500 m², titre bleu, zone résidentielle.',
        displayedPrice: 380000,
        durationDays: 30,
        publish: true);
    expect((await matching.notifications(client)).length, before);

    // Republier le S+1 d'Ennasr (location à Ariana) après l'avoir supprimé.
    final ennasr = (await listings.agencyListings(carthage))
        .firstWhere((d) => d.property.district == 'Ennasr 2');
    await listings.suspend(ennasr.listing.id!);
    await db.update('listings', {'status': ListingStatus.expired.name},
        where: 'id = ?', whereArgs: [ennasr.listing.id]);
    await listings.delete(ennasr.listing.id!);
    await listings.create(
        propertyId: ennasr.property.id!,
        agencyId: carthage,
        title: 'S+1 à louer à Ennasr 2',
        text: 'Appartement S+1 de 75 m² proche des commerces, ascenseur.',
        displayedPrice: 1100,
        durationDays: 30);
    expect((await matching.notifications(client)).length, before); // brouillon : rien

    final draft = (await listings.agencyListings(carthage, status: ListingStatus.draft))
        .firstWhere((d) => d.property.district == 'Ennasr 2');
    await listings.publish(draft.listing.id!);
    final after = await matching.notifications(client);
    expect(after.length, before + 1);
    expect(after.first.listingId, draft.listing.id);
    expect(after.first.score, 100);

    // Les alertes désactivées ne notifient plus.
    await matching.saveCriteria(client,
        const SearchCriteria(dealType: DealType.rent, city: 'Ariana', alertsEnabled: false));
    expect(await matching.notifyNewListing(draft.listing.id!), 0);
    await matching.markAllRead(client);
    expect((await matching.notifications(client)).any((n) => !n.isRead), isFalse);
  });

  test('contrôle de saisie (BF5.1)', () async {
    final draft = (await listings.agencyListings(carthage, status: ListingStatus.draft)).first;
    final id = draft.listing.id!;
    expect(() => listings.updateContent(id, title: 'S+2', text: draft.listing.text,
        displayedPrice: 1000), throwsAdmin('title'));
    expect(() => listings.updateContent(id, title: draft.listing.title, text: 'Trop court',
        displayedPrice: 1000), throwsAdmin('text'));
    expect(() => listings.updateContent(id, title: draft.listing.title,
        text: draft.listing.text, displayedPrice: 0), throwsAdmin('price'));
  });
}
