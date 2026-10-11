import 'package:immora_mobile/core/utils/enums.dart';

/// Bien immobilier (Module 3, table `properties`).
///
/// Partagé avec les annonces (M5) : les noms de colonnes restent stables et
/// [columns] sert aussi aux jointures préfixées `p_` (annonces, visites).
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
  final double? landSurface; // m² de terrain (villa)
  final int rooms; // chambres
  final int bathrooms;
  final int? floor; // étage (null à terre)
  final String city;
  final String district; // quartier
  final String address; // « Localisation sur la carte » (maquette M3)
  final double? latitude;
  final double? longitude;
  final List<String> amenities; // parking, ascenseur, jardin, piscine, meublé…
  final PropertyCondition condition;
  final String description;
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
    this.landSurface,
    required this.rooms,
    this.bathrooms = 1,
    this.floor,
    required this.city,
    this.district = '',
    this.address = '',
    this.latitude,
    this.longitude,
    this.amenities = const [],
    this.condition = PropertyCondition.good,
    this.description = '',
    this.status = PropertyStatus.available,
    this.mainPhotoPath,
    required this.createdAt,
  });

  bool get isAvailable => status == PropertyStatus.available;

  /// « Surface terrain » n'est demandée que pour une villa (maquette M3).
  bool get requiresLandSurface => type == PropertyType.villa;

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
    'surface', 'landSurface', 'rooms', 'bathrooms', 'floor', 'city', 'district',
    'address', 'latitude', 'longitude', 'amenities', 'condition', 'description',
    'status', 'mainPhotoPath', 'createdAt',
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
        'landSurface': landSurface,
        'rooms': rooms,
        'bathrooms': bathrooms,
        'floor': floor,
        'city': city,
        'district': district,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'amenities': amenities.join(','),
        'condition': condition.name,
        'description': description,
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
      landSurface: (m['${prefix}landSurface'] as num?)?.toDouble(),
      rooms: m['${prefix}rooms'] ?? 0,
      bathrooms: m['${prefix}bathrooms'] ?? 1,
      floor: (m['${prefix}floor'] as num?)?.toInt(),
      city: m['${prefix}city'] ?? '',
      district: m['${prefix}district'] ?? '',
      address: m['${prefix}address'] ?? '',
      latitude: (m['${prefix}latitude'] as num?)?.toDouble(),
      longitude: (m['${prefix}longitude'] as num?)?.toDouble(),
      amenities: amenities.isEmpty ? const [] : amenities.split(','),
      condition: PropertyCondition.values
          .byName((m['${prefix}condition'] as String?) ?? PropertyCondition.good.name),
      description: m['${prefix}description'] ?? '',
      status: PropertyStatus.values.byName(m['${prefix}status']),
      mainPhotoPath: m['${prefix}mainPhotoPath'],
      createdAt: m['${prefix}createdAt'],
    );
  }
}
