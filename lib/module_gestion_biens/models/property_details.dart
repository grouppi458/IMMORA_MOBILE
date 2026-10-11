import 'package:immora_mobile/module_gestion_biens/models/property.dart';

/// Fiche complète d'un bien (détail agence et statut propriétaire) :
/// bien ⋈ agence ⋈ propriétaire ⋈ agent, avec les statistiques des maquettes
/// (vues de l'annonce, visites, favoris). Construit par [PropertyRepository].
class PropertyDetails {
  final Property property;
  final String agencyName;
  final String agencyPhone;
  final String? ownerName;
  final String? ownerPhone;
  final String? agentName;
  final double? agentCommissionRate;
  final int views;
  final int visitsCount;
  final int favoritesCount;
  final int? publishedAt; // dernière publication d'annonce
  final int? listingId; // annonce en cours (brouillon, publiée ou suspendue)

  PropertyDetails({
    required this.property,
    required this.agencyName,
    required this.agencyPhone,
    this.ownerName,
    this.ownerPhone,
    this.agentName,
    this.agentCommissionRate,
    this.views = 0,
    this.visitsCount = 0,
    this.favoritesCount = 0,
    this.publishedAt,
    this.listingId,
  });
}
