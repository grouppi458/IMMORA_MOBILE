import 'package:immora_mobile/module_gestion_annonces/models/listing.dart';
import 'package:immora_mobile/module_gestion_biens/models/property.dart';

/// Annonce prête à afficher : l'annonce, son bien, son agence et le nombre
/// de favoris (BF5.3).
class ListingDetails {
  const ListingDetails({
    required this.listing,
    required this.property,
    required this.agencyName,
    required this.favoritesCount,
    this.agencyPhone = '',
    this.agentName,
  });

  final Listing listing;
  final Property property;
  final String agencyName;
  final int favoritesCount;
  final String agencyPhone; // contact affiché sur la fiche client
  final String? agentName; // agent responsable du bien
}
