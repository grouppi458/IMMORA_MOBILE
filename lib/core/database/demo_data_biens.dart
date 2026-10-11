import 'package:sqflite/sqflite.dart';

import 'package:immora_mobile/core/utils/enums.dart';

/// Données de démonstration du Module 3, calquées sur les maquettes Figma :
/// « Appartement S+3 · Lac » (détail, estimation du prix, description IA et
/// espace propriétaire), ses comparables des Berges du Lac, le duplex et le
/// studio de Rania Nasri (propriétaire de démo), l'appartement de La Marsa et
/// la villa de Gammarth (transactions du M4). S'appuie sur les données du M5 ;
/// ne fait rien si le bien central existe déjà.
class DemoDataBiens {
  DemoDataBiens._();

  static Future<void> seed(Database db) async {
    final existing = Sqflite.firstIntValue(await db.rawQuery(
            "SELECT COUNT(*) FROM properties WHERE title = 'Appartement S+3 · Lac'")) ??
        0;
    if (existing > 0) return;

    Future<int?> idWhere(String table, String column, Object value) async {
      final rows = await db.query(table,
          columns: ['id'], where: '$column = ?', whereArgs: [value], limit: 1);
      return rows.isEmpty ? null : rows.first['id'] as int;
    }

    final carthage = await idWhere('agencies', 'email', 'agence@immora.tn');
    final carthageUser = await idWhere('users', 'email', 'agence@immora.tn');
    final owner = await idWhere('users', 'email', 'proprietaire@immora.tn');
    if (carthage == null) return;

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

    final now = DateTime.now();
    int ago(int days) => now.subtract(Duration(days: days)).millisecondsSinceEpoch;
    const day = Duration.millisecondsPerDay;

    await db.transaction((txn) async {
      Future<int> property(
        String title,
        PropertyType type,
        DealType deal,
        double price,
        double surface,
        int rooms,
        String city,
        String district,
        String address,
        double lat,
        double lng,
        List<String> amenities, {
        required int? agentId,
        int? ownerId,
        PropertyStatus status = PropertyStatus.available,
        PropertyCondition condition = PropertyCondition.good,
        int? floor,
        double? landSurface,
        String? description,
        required int createdDaysAgo,
      }) {
        return txn.insert('properties', {
          'agencyId': carthage,
          'ownerId': ownerId,
          'agentId': agentId,
          'title': title,
          'type': type.name,
          'dealType': deal.name,
          'price': price,
          'surface': surface,
          'landSurface': landSurface,
          'rooms': rooms,
          'bathrooms': rooms >= 3 ? 2 : 1,
          'floor': floor,
          'city': city,
          'district': district,
          'address': address,
          'latitude': lat,
          'longitude': lng,
          'amenities': amenities.join(','),
          'condition': condition.name,
          'description': description,
          'status': status.name,
          'createdAt': ago(createdDaysAgo),
        });
      }

      // ---------- Bien central des maquettes M3 ----------
      final hero = await property(
        'Appartement S+3 · Lac',
        PropertyType.apartment,
        DealType.sale,
        485000,
        145,
        3,
        'Tunis',
        'Les Berges du Lac',
        'Rue du Lac Léman',
        36.8421,
        10.2712,
        ['parking', 'ascenseur'],
        agentId: sirine,
        ownerId: owner,
        floor: 4,
        createdDaysAgo: 40,
        description: 'Appartement S+3 de 145 m² situé aux Berges du Lac, Tunis, en bon '
            'état, disposant d’un parking et d’un ascenseur. Lumineux, proche des '
            'commodités.',
      );
      // Annonce publiée : 142 vues (« Publié le 2 sept. 2026 » sur la maquette).
      final publishedAt = ago(39);
      await txn.insert('listings', {
        'propertyId': hero,
        'agencyId': carthage,
        'createdBy': carthageUser,
        'title': 'Appartement S+3 aux Berges du Lac',
        'text': 'Appartement S+3 de 145 m² au 4e étage avec ascenseur et place de '
            'parking, aux Berges du Lac. Double séjour lumineux, cuisine équipée, '
            'trois chambres et deux salles de bain. Proche des commerces et des écoles.',
        'displayedPrice': 485000,
        'durationDays': 90,
        'status': ListingStatus.published.name,
        'isFeatured': 0,
        'viewsCount': 142,
        'publishedAt': publishedAt,
        'expiresAt': publishedAt + 90 * day,
        'createdAt': ago(40),
        'updatedAt': publishedAt,
      });

      // ---------- Biens du propriétaire de démo ----------
      await property(
        'Duplex · Carthage',
        PropertyType.house,
        DealType.rent,
        2400,
        210,
        4,
        'Carthage',
        'Dermech',
        'Rue de la Délégation, Dermech',
        36.8520,
        10.3300,
        ['parking', 'ascenseur'],
        agentId: leila,
        ownerId: owner,
        floor: 1,
        status: PropertyStatus.rented,
        createdDaysAgo: 90,
        description: 'Duplex de 210 m² sur deux niveaux : quatre chambres, double '
            'séjour ouvert, deux salles de bain et terrasse. Quartier calme proche '
            'du site archéologique.',
      );
      await property(
        'Studio · El Menzah',
        PropertyType.apartment,
        DealType.sale,
        185000,
        52,
        1,
        'Tunis',
        'El Menzah',
        'Rue Ibn Charaf, El Menzah 6',
        36.8420,
        10.1670,
        ['ascenseur'],
        agentId: sami,
        ownerId: owner,
        floor: 2,
        status: PropertyStatus.reserved,
        createdDaysAgo: 70,
        description: 'Studio de 52 m² au 2e étage avec ascenseur, cuisine équipée et '
            'place de parking. Idéal premier achat.',
      );

      // ---------- Transactions du M4 ----------
      await property(
        'Appartement S+2 · Marsa',
        PropertyType.apartment,
        DealType.rent,
        1800,
        95,
        2,
        'La Marsa',
        'La Marsa',
        'Avenue Habib Bourguiba, La Marsa',
        36.8860,
        10.3250,
        ['parking'],
        agentId: ahmed,
        floor: 1,
        status: PropertyStatus.reserved,
        createdDaysAgo: 55,
        description: 'Appartement S+2 de 95 m² à deux pas de la plage de La Marsa, '
            'séjour lumineux, cuisine équipée et parking.',
      );
      await property(
        'Villa avec piscine · Gammarth',
        PropertyType.villa,
        DealType.sale,
        1250000,
        320,
        5,
        'La Marsa',
        'Gammarth',
        'Route de la Corniche, Gammarth',
        36.9080,
        10.2930,
        ['parking', 'piscine', 'jardin'],
        agentId: sirine,
        landSurface: 800,
        createdDaysAgo: 45,
        description: 'Villa de 320 m² sur un terrain de 800 m² à Gammarth : cinq '
            'chambres, piscine, jardin paysager et garage.',
      );

      // ---------- Comparables de « Estimation du prix » ----------
      await property(
        'Appartement S+3 · Berge du Lac',
        PropertyType.apartment,
        DealType.sale,
        470000,
        142,
        3,
        'Tunis',
        'Les Berges du Lac',
        'Rue du Lac Léman, Les Berges du Lac',
        36.8430,
        10.2730,
        ['parking', 'ascenseur'],
        agentId: sirine,
        floor: 3,
        status: PropertyStatus.sold,
        createdDaysAgo: 120,
        description: 'Appartement S+3 de 142 m² vendu aux Berges du Lac, résidence '
            'sécurisée avec parking.',
      );
      await property(
        'Appartement S+2 · Berge du Lac',
        PropertyType.apartment,
        DealType.sale,
        355000,
        110,
        2,
        'Tunis',
        'Les Berges du Lac',
        'Rue du Lac Turkana, Les Berges du Lac',
        36.8440,
        10.2740,
        ['ascenseur'],
        agentId: sirine,
        floor: 1,
        createdDaysAgo: 130,
        description: 'Appartement S+2 de 110 m² aux Berges du Lac, résidence '
            'sécurisée proche des commerces.',
      );
      await property(
        'Appartement S+4 · Berge du Lac',
        PropertyType.apartment,
        DealType.sale,
        610000,
        180,
        4,
        'Tunis',
        'Les Berges du Lac',
        'Rue du Lac Léman, Les Berges du Lac',
        36.8410,
        10.2700,
        ['parking', 'ascenseur'],
        agentId: sirine,
        floor: 5,
        status: PropertyStatus.sold,
        condition: PropertyCondition.asNew,
        createdDaysAgo: 110,
        description: 'Appartement S+4 de 180 m² neuf aux Berges du Lac, double séjour '
            'et vue dégagée.',
      );
    });
  }
}
