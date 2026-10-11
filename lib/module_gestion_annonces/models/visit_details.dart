import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/module_gestion_annonces/models/visit.dart';

/// Visite avec les libellés à afficher (jointures visites ⋈ biens ⋈ annonces
/// ⋈ agence ⋈ comptes). Construit par [VisitRepository].
class VisitDetails {
  final Visit visit;
  final String listingTitle;
  final String propertyTitle;
  final PropertyType propertyType;
  final DealType dealType;
  final double price;
  final int rooms;
  final String city;
  final String district;
  final double? latitude;
  final double? longitude;
  final String agencyName;
  final String clientName;
  final String? clientPhone;
  final String? agentName;

  VisitDetails({
    required this.visit,
    required this.listingTitle,
    required this.propertyTitle,
    required this.propertyType,
    required this.dealType,
    required this.price,
    this.rooms = 0,
    required this.city,
    required this.district,
    this.latitude,
    this.longitude,
    required this.agencyName,
    required this.clientName,
    this.clientPhone,
    this.agentName,
  });

  String get location => district.isEmpty ? city : '$district, $city';

  String get displayTitle => listingTitle.isEmpty ? propertyTitle : listingTitle;

  /// Titre compact des cartes : « Appart. S+3 · Lac » (maquettes Figma).
  String get shortTitle {
    final base = switch (propertyType) {
      PropertyType.apartment => rooms > 0 ? 'Appart. S+$rooms' : 'Appartement',
      PropertyType.house => 'Maison',
      PropertyType.villa => 'Villa',
      PropertyType.land => 'Terrain',
      PropertyType.office => 'Bureau',
      PropertyType.shop => 'Local',
    };
    final place = district.isEmpty ? city : district;
    return place.isEmpty ? base : '$base · $place';
  }
}
