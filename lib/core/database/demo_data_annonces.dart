import 'package:sqflite/sqflite.dart';

import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/module_gestion_annonces/matching/matching_engine.dart';
import 'package:immora_mobile/module_gestion_annonces/models/search_criteria.dart';
import 'package:immora_mobile/module_gestion_annonces/repositories/listing_repository.dart';
import 'package:immora_mobile/module_gestion_annonces/repositories/matching_repository.dart';

/// Données de démonstration du Module 5 : biens (provisoires, en attendant le
/// M3), annonces dans tous les statuts et favoris du client de démo.
/// S'appuie sur les comptes créés par [DemoData] (recherchés par e-mail) ;
/// ne fait rien si les annonces existent déjà ou si ces comptes manquent.
class DemoDataAnnonces {
  DemoDataAnnonces._();

  static Future<void> seed(Database db) async {
    final existing =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM listings')) ?? 0;
    if (existing > 0) return;

    Future<int?> idWhere(String table, String column, Object value) async {
      final rows = await db.query(table,
          columns: ['id'], where: '$column = ?', whereArgs: [value], limit: 1);
      return rows.isEmpty ? null : rows.first['id'] as int;
    }

    final carthage = await idWhere('agencies', 'email', 'agence@immora.tn');
    final gammarth = await idWhere('agencies', 'email', 'hello@gammarth-luxury.tn');
    final carthageUser = await idWhere('users', 'email', 'agence@immora.tn');
    final gammarthUser = await idWhere('users', 'email', 'hello@gammarth-luxury.tn');
    final owner = await idWhere('users', 'email', 'proprietaire@immora.tn');
    final client = await idWhere('users', 'email', 'client@immora.tn');
    if (carthage == null || gammarth == null) return;

    final carthageAgents = (await db.query('agents',
            columns: ['id'], where: 'agencyId = ?', whereArgs: [carthage], orderBy: 'id'))
        .map((r) => r['id'] as int)
        .toList();
    int? agent(int i) => carthageAgents.isEmpty ? null : carthageAgents[i % carthageAgents.length];

    final now = DateTime.now();
    int ago(int days) => now.subtract(Duration(days: days)).millisecondsSinceEpoch;
    const day = Duration.millisecondsPerDay;

    await db.transaction((txn) async {
      Future<int> property(int agencyId, int? agentId, String title, PropertyType type,
          DealType deal, double price, double surface, int rooms, String city,
          String district, double lat, double lng, List<String> amenities,
          {PropertyStatus status = PropertyStatus.available, int createdDaysAgo = 60}) {
        return txn.insert('properties', {
          'agencyId': agencyId,
          'ownerId': owner,
          'agentId': agentId,
          'title': title,
          'type': type.name,
          'dealType': deal.name,
          'price': price,
          'surface': surface,
          'rooms': rooms,
          'bathrooms': rooms >= 3 ? 2 : 1,
          'city': city,
          'district': district,
          'latitude': lat,
          'longitude': lng,
          'amenities': amenities.join(','),
          'status': status.name,
          'createdAt': ago(createdDaysAgo),
        });
      }

      /// [publishedDaysAgo] null = brouillon jamais publié.
      Future<int> listing(int propertyId, int agencyId, int? createdBy, String title,
          String text, double price, int duration, ListingStatus status,
          {int? publishedDaysAgo, bool featured = false, int views = 0}) {
        final publishedAt = publishedDaysAgo == null ? null : ago(publishedDaysAgo);
        return txn.insert('listings', {
          'propertyId': propertyId,
          'agencyId': agencyId,
          'createdBy': createdBy,
          'title': title,
          'text': text,
          'displayedPrice': price,
          'durationDays': duration,
          'status': status.name,
          'isFeatured': featured ? 1 : 0,
          'viewsCount': views,
          'publishedAt': publishedAt,
          'expiresAt': publishedAt == null ? null : publishedAt + duration * day,
          'createdAt': ago((publishedDaysAgo ?? 1) + 1),
          'updatedAt': ago(publishedDaysAgo ?? 1),
        });
      }

      // ---------- Carthage Immobilier ----------
      final lac = await property(carthage, agent(0), 'Appartement S+2 aux Berges du Lac 2',
          PropertyType.apartment, DealType.sale, 420000, 115, 2, 'Tunis',
          'Les Berges du Lac 2', 36.8455, 10.2731, ['parking', 'ascenseur']);
      final marsa = await property(carthage, agent(2), 'Villa avec piscine à La Marsa',
          PropertyType.villa, DealType.sale, 1450000, 380, 5, 'La Marsa', 'Sidi Abdelaziz',
          36.8890, 10.3240, ['parking', 'piscine', 'jardin']);
      final ennasr = await property(carthage, agent(1), 'Appartement S+1 à Ennasr',
          PropertyType.apartment, DealType.rent, 1100, 75, 1, 'Ariana', 'Ennasr 2',
          36.8600, 10.1640, ['ascenseur']);
      final menzah = await property(carthage, agent(0), 'Maison familiale à El Menzah 6',
          PropertyType.house, DealType.sale, 690000, 220, 4, 'Tunis', 'El Menzah 6',
          36.8460, 10.1780, ['parking', 'jardin']);
      final carthageFlat = await property(carthage, agent(3), 'Appartement meublé à Carthage',
          PropertyType.apartment, DealType.rent, 2300, 130, 3, 'Carthage', 'Dermech',
          36.8530, 10.3300, ['parking', 'ascenseur']);
      final office = await property(carthage, agent(1), 'Bureau au Centre Urbain Nord',
          PropertyType.office, DealType.rent, 3200, 160, 0, 'Tunis', 'Centre Urbain Nord',
          36.8470, 10.1960, ['parking', 'ascenseur']);
      final soukra = await property(carthage, agent(0), 'Terrain constructible à La Soukra',
          PropertyType.land, DealType.sale, 380000, 500, 0, 'Ariana', 'La Soukra',
          36.8750, 10.2400, []);
      final aouina = await property(carthage, agent(2), 'Appartement S+3 à L’Aouina',
          PropertyType.apartment, DealType.sale, 510000, 150, 3, 'Tunis', 'L’Aouina',
          36.8520, 10.2550, ['parking', 'ascenseur'], status: PropertyStatus.sold);
      // Bien disponible sans annonce : pour essayer « Créer une annonce » (BF5.1).
      await property(carthage, agent(1), 'Appartement S+2 à El Manar 2',
          PropertyType.apartment, DealType.rent, 1400, 100, 2, 'Tunis', 'El Manar 2',
          36.8400, 10.1550, ['ascenseur'], createdDaysAgo: 4);

      final lacListing = await listing(lac, carthage, carthageUser, 'Bel S+2 lumineux aux Berges du Lac 2',
          'Appartement S+2 de 115 m² au 4e étage d’une résidence sécurisée aux Berges du Lac 2. '
              'Séjour lumineux, cuisine équipée, deux chambres et une salle de bain. '
              'Parking en sous-sol et ascenseur.',
          420000, 30, ListingStatus.published, publishedDaysAgo: 10, featured: true, views: 128);
      await listing(marsa, carthage, carthageUser, 'Villa d’exception avec piscine à La Marsa',
          'Villa de 380 m² sur un terrain arboré à Sidi Abdelaziz : cinq chambres, '
              'grand salon ouvert sur le jardin, piscine et garage. À deux pas de la plage.',
          1450000, 60, ListingStatus.published, publishedDaysAgo: 5, featured: true, views: 342);
      final ennasrListing = await listing(ennasr, carthage, carthageUser, 'S+1 moderne à louer à Ennasr 2',
          'Appartement S+1 de 75 m² proche des commerces et des écoles. '
              'Chambre avec placard, cuisine ouverte, ascenseur. Libre immédiatement.',
          1100, 30, ListingStatus.published, publishedDaysAgo: 3, views: 57);
      await listing(menzah, carthage, carthageUser, 'Maison familiale avec jardin à El Menzah 6',
          'Maison de 220 m² sur deux niveaux : quatre chambres, deux salles de bain, '
              'jardin et garage. Quartier calme et recherché.',
          690000, 90, ListingStatus.published, publishedDaysAgo: 40, views: 211);
      await listing(carthageFlat, carthage, carthageUser, 'S+3 meublé avec vue à Carthage',
          'Appartement meublé de 130 m² à Dermech, trois chambres, terrasse avec vue '
              'sur le golfe. Parking et ascenseur.',
          2300, 60, ListingStatus.suspended, publishedDaysAgo: 15, views: 74);
      await listing(office, carthage, carthageUser, 'Plateau de bureaux au Centre Urbain Nord',
          'Plateau de 160 m² aménageable, climatisé, avec places de parking. '
              'Idéal pour un siège social.',
          3200, 30, ListingStatus.draft);
      await listing(soukra, carthage, carthageUser, 'Terrain de 500 m² à La Soukra',
          'Terrain constructible de 500 m² dans une zone résidentielle de La Soukra, '
              'titre bleu, toutes commodités à proximité.',
          380000, 30, ListingStatus.expired, publishedDaysAgo: 35, views: 96);
      await listing(aouina, carthage, carthageUser, 'S+3 spacieux à L’Aouina',
          'Appartement S+3 de 150 m², double séjour, cuisine équipée, parking.',
          510000, 90, ListingStatus.withdrawn, publishedDaysAgo: 50, views: 180);

      // ---------- Gammarth Luxury ----------
      final villa = await property(gammarth, null, 'Villa pieds dans l’eau à Gammarth',
          PropertyType.villa, DealType.sale, 2900000, 450, 6, 'La Marsa', 'Gammarth',
          36.9180, 10.2870, ['parking', 'piscine', 'jardin']);
      final penthouse = await property(gammarth, null, 'Penthouse avec piscine à Gammarth',
          PropertyType.apartment, DealType.rent, 6500, 220, 3, 'La Marsa', 'Gammarth',
          36.9120, 10.2900, ['parking', 'piscine', 'ascenseur']);
      final villaListing = await listing(villa, gammarth, gammarthUser,
          'Villa pieds dans l’eau à Gammarth',
          'Villa contemporaine de 450 m² avec accès direct à la plage : six chambres, '
              'piscine à débordement, jardin paysager.',
          2900000, 60, ListingStatus.published, publishedDaysAgo: 2, featured: true, views: 41);
      await listing(penthouse, gammarth, gammarthUser, 'Penthouse avec piscine privée',
          'Penthouse de 220 m² au dernier étage, trois chambres, piscine privée sur le toit '
              'et vue panoramique sur la mer.',
          6500, 30, ListingStatus.published, publishedDaysAgo: 8, views: 63);

      // ---------- Favoris du client de démo ----------
      if (client != null) {
        for (final f in [lacListing, ennasrListing, villaListing]) {
          await txn.insert('favorites',
              {'clientId': client, 'listingId': f, 'addedAt': ago(1)});
        }
      }
    });
  }

  /// v4 — critères du client de démo (« achat · 300–500K TND · Tunis ·
  /// 2+ chambres ») et ses alertes « nouvelle annonce pour vous », calculées
  /// par le moteur de matching sur les annonces publiées.
  static Future<void> seedMatching(Database db) async {
    final existing =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM search_criteria')) ?? 0;
    if (existing > 0) return;
    final rows = await db.query('users',
        columns: ['id'], where: 'email = ?', whereArgs: ['client@immora.tn'], limit: 1);
    if (rows.isEmpty) return;
    final client = rows.first['id'] as int;

    const criteria = SearchCriteria(
      dealType: DealType.sale,
      types: {PropertyType.apartment},
      budgetMin: 300000,
      budgetMax: 500000,
      city: 'Tunis',
      minRooms: 2,
      minSurface: 90,
    );
    await db.insert('search_criteria', criteria.toMap(client));
    await _seedMatchingListings(db);

    final published = (await db.rawQuery(
            '${ListingRepository.selectDetails} WHERE l.status = ? ORDER BY l.publishedAt DESC',
            [ListingStatus.published.name]))
        .map(ListingRepository.detailsFromRow);
    var first = true;
    for (final d in published) {
      final match = MatchingEngine.scoreListing(d, criteria);
      if (match.excluded || match.score < MatchingEngine.alertScore) continue;
      await db.insert('notifications', {
        ...MatchingRepository.newListingNotification(client, d, match.score,
            at: d.listing.publishedAt),
        'isRead': first ? 0 : 1, // la plus récente reste non lue
      });
      first = false;
    }
  }

  /// Trois appartements de plus, plus ou moins proches des critères du client
  /// de démo, pour que « Pour vous » et la recherche montrent des scores variés.
  static Future<void> _seedMatchingListings(Database db) async {
    final agencies = await db.query('agencies',
        columns: ['id'], where: 'email = ?', whereArgs: ['agence@immora.tn'], limit: 1);
    if (agencies.isEmpty) return;
    final agency = agencies.first['id'] as int;
    final users = await db.query('users',
        columns: ['id'], where: 'email = ?', whereArgs: ['agence@immora.tn'], limit: 1);
    final agencyUser = users.isEmpty ? null : users.first['id'] as int;
    final owners = await db.query('users',
        columns: ['id'], where: 'email = ?', whereArgs: ['proprietaire@immora.tn'], limit: 1);
    final owner = owners.isEmpty ? null : owners.first['id'] as int;
    final agents = await db.query('agents',
        columns: ['id'], where: 'agencyId = ?', whereArgs: [agency], orderBy: 'id', limit: 2);
    final agent = agents.isEmpty ? null : agents.last['id'] as int;

    final now = DateTime.now();
    int ago(int days) => now.subtract(Duration(days: days)).millisecondsSinceEpoch;
    const day = Duration.millisecondsPerDay;

    for (final (title, district, city, price, surface, rooms, lat, lng, text, days) in [
      ('S+3 familial à El Menzah 5', 'El Menzah 5', 'Tunis', 445000.0, 130.0, 3, 36.8420,
          10.1700,
          'Appartement S+3 de 130 m² au 2e étage, double séjour, cuisine équipée, '
              'balcon et place de parking. Proche écoles et commerces.', 1),
      ('S+2 récent à Ennasr', 'Ennasr', 'Ariana', 320000.0, 98.0, 2, 36.8620, 10.1610,
          'Appartement S+2 de 98 m² dans une résidence récente avec ascenseur et parking.', 6),
      ('Studio meublé à Lafayette', 'Lafayette', 'Tunis', 210000.0, 52.0, 1, 36.8150,
          10.1810,
          'Studio de 52 m² rénové, idéal premier achat ou investissement locatif.', 9),
    ]) {
      final property = await db.insert('properties', {
        'agencyId': agency,
        'ownerId': owner,
        'agentId': agent,
        'title': title,
        'type': PropertyType.apartment.name,
        'dealType': DealType.sale.name,
        'price': price,
        'surface': surface,
        'rooms': rooms,
        'bathrooms': rooms >= 3 ? 2 : 1,
        'city': city,
        'district': district,
        'latitude': lat,
        'longitude': lng,
        'amenities': 'parking,ascenseur',
        'status': PropertyStatus.available.name,
        'createdAt': ago(days + 5),
      });
      await db.insert('listings', {
        'propertyId': property,
        'agencyId': agency,
        'createdBy': agencyUser,
        'title': title,
        'text': text,
        'displayedPrice': price,
        'durationDays': 60,
        'status': ListingStatus.published.name,
        'isFeatured': 0,
        'viewsCount': 20 + days * 7,
        'publishedAt': ago(days),
        'expiresAt': ago(days) + 60 * day,
        'createdAt': ago(days + 1),
        'updatedAt': ago(days),
      });
    }
  }
}
