import 'package:immora_mobile/core/utils/enums.dart';

/// Bien immobilier (table `properties`).
///
/// PROVISOIRE : la gestion des biens appartient au Module 3 (Ing. 2). Cette
/// classe ne contient que les champs dont les annonces (M5) ont besoin ; elle
/// sera remplacée par le modèle du M3 en gardant les mêmes noms de colonnes.
class Property {
  final int? id;
  final int agencyId;
  final int? ownerId; // users.id (rôle owner)
  final int? agentId; // agents.id
  final String title;
  final PropertyType type;
  final DealType dealType;
  final double price; // TND (prix total ou loyer mensuel)
  final double surface; // m²
  final int rooms; // chambres
  final int bathrooms;
  final String city;
  final String district; // quartier
  final double? latitude;
  final double? longitude;
  final List<String> amenities; // parking, piscine, jardin, ascenseur…
  final PropertyStatus status;
  final String? mainPhotoPath;
  final int createdAt;

  Property({
    this.id,
    required this.agencyId,
    this.ownerId,
    this.agentId,
    required this.title,
    required this.type,
    required this.dealType,
    required this.price,
    required this.surface,
    required this.rooms,
    this.bathrooms = 1,
    required this.city,
    this.district = '',
    this.latitude,
    this.longitude,
    this.amenities = const [],
    this.status = PropertyStatus.available,
    this.mainPhotoPath,
    required this.createdAt,
  });

  bool get isAvailable => status == PropertyStatus.available;

  /// « Appartement · 3 ch. · 120 m² »
  String get shortSpec => [
        type.label,
        if (rooms > 0) '$rooms ch.',
        '${surface.round()} m²',
      ].join(' · ');

  /// « La Marsa, Tunis »
  String get location => district.isEmpty ? city : '$district, $city';

  /// Colonnes de la table, utilisées aussi pour les jointures (préfixe `p_`).
  static const columns = [
    'id', 'agencyId', 'ownerId', 'agentId', 'title', 'type', 'dealType', 'price',
    'surface', 'rooms', 'bathrooms', 'city', 'district', 'latitude', 'longitude',
    'amenities', 'status', 'mainPhotoPath', 'createdAt',
  ];

  Map<String, dynamic> toMap() => {
        'id': id,
        'agencyId': agencyId,
        'ownerId': ownerId,
        'agentId': agentId,
        'title': title,
        'type': type.name,
        'dealType': dealType.name,
        'price': price,
        'surface': surface,
        'rooms': rooms,
        'bathrooms': bathrooms,
        'city': city,
        'district': district,
        'latitude': latitude,
        'longitude': longitude,
        'amenities': amenities.join(','),
        'status': status.name,
        'mainPhotoPath': mainPhotoPath,
        'createdAt': createdAt,
      };

  /// [prefix] permet de lire une ligne de jointure (`p_title`, `p_city`…).
  factory Property.fromMap(Map<String, dynamic> m, {String prefix = ''}) {
    final amenities = (m['${prefix}amenities'] as String?) ?? '';
    return Property(
      id: m['${prefix}id'],
      agencyId: m['${prefix}agencyId'],
      ownerId: m['${prefix}ownerId'],
      agentId: m['${prefix}agentId'],
      title: m['${prefix}title'],
      type: PropertyType.values.byName(m['${prefix}type']),
      dealType: DealType.values.byName(m['${prefix}dealType']),
      price: (m['${prefix}price'] as num).toDouble(),
      surface: (m['${prefix}surface'] as num).toDouble(),
      rooms: m['${prefix}rooms'] ?? 0,
      bathrooms: m['${prefix}bathrooms'] ?? 1,
      city: m['${prefix}city'] ?? '',
      district: m['${prefix}district'] ?? '',
      latitude: (m['${prefix}latitude'] as num?)?.toDouble(),
      longitude: (m['${prefix}longitude'] as num?)?.toDouble(),
      amenities: amenities.isEmpty ? const [] : amenities.split(','),
      status: PropertyStatus.values.byName(m['${prefix}status']),
      mainPhotoPath: m['${prefix}mainPhotoPath'],
      createdAt: m['${prefix}createdAt'],
    );
  }
}
