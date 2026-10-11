import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/module_gestion_biens/models/property.dart';

/// BF3.8 — un modèle de phrase est rempli avec les champs du bien, puis les
/// équipements présents sont ajoutés (maquette « Description IA »).
class DescriptionGenerator {
  static const _saleTemplate = '« {typeLabel} S+{rooms} de {surface} m² situé à '
      '{district}, {city}, {conditionLabel}, disposant {features}. '
      'Prix : {price} TND. »';
  static const _rentTemplate = '« {typeLabel} S+{rooms} de {surface} m² situé à '
      '{district}, {city}, {conditionLabel}, disposant {features}. '
      'Loyer : {price} TND /mois. »';

  /// Modèle affiché dans la carte « Modèle (vente) » / « (location) ».
  static String template(DealType deal) =>
      deal == DealType.rent ? _rentTemplate : _saleTemplate;

  /// Texte proposé, modifiable avant validation (bouton « Utiliser »).
  static String generate(Property p) {
    final feminine = switch (p.type) {
      PropertyType.house || PropertyType.villa || PropertyType.shop => true,
      _ => false,
    };
    final rooms = p.rooms > 0 ? ' S+${p.rooms}' : '';
    final located = feminine ? 'située' : 'situé';
    final condition = _conditionPhrase(p.condition, feminine: feminine);
    final features =
        p.amenities.isEmpty ? '' : ', disposant ${_featureList(p.amenities)}';
    final price = p.dealType == DealType.rent
        ? 'Loyer : ${formatNumber(p.price)} TND /mois.'
        : 'Prix : ${formatNumber(p.price)} TND.';
    return '${p.type.label}$rooms de ${formatNumber(p.surface.round())} m² '
        '$located ${_placePhrase(p.district, p.city)}, $condition$features. $price';
  }

  /// Puces « Équipements détectés » : Parking, Ascenseur, Étage 4, Bon état.
  static List<String> detectedFeatures(Property p) => [
        for (final a in p.amenities) amenityLabel(a),
        if ((p.floor ?? 0) > 0) 'Étage ${p.floor}',
        p.condition.label,
      ];

  /// « parking » → « Parking » (puces et listes).
  static String amenityLabel(String amenity) {
    final label = _amenityLabels[amenity] ??
        (amenity.isEmpty ? amenity : '${amenity[0].toUpperCase()}${amenity.substring(1)}');
    return label;
  }

  static const _amenityLabels = {
    'parking': 'Parking',
    'ascenseur': 'Ascenseur',
    'jardin': 'Jardin',
    'piscine': 'Piscine',
    'meublé': 'Meublé',
  };

  static const _amenityPhrases = {
    'parking': 'un parking',
    'ascenseur': 'un ascenseur',
    'jardin': 'un jardin',
    'piscine': 'une piscine',
    'meublé': 'un intérieur meublé',
  };

  /// « un parking, un ascenseur et un jardin ».
  static String _featureList(List<String> amenities) {
    final phrases = amenities.map(_dePhrase).toList();
    if (phrases.length == 1) return phrases.first;
    return '${phrases.sublist(0, phrases.length - 1).join(', ')} '
        'et ${phrases.last}';
  }

  /// « un parking » → « d’un parking », « meublé » → « de meublé ».
  static String _dePhrase(String amenity) {
    final phrase = _amenityPhrases[amenity] ?? amenity;
    return phrase.startsWith('un ') || phrase.startsWith('une ')
        ? 'd’$phrase'
        : 'de $phrase';
  }

  /// « aux Berges du Lac, Tunis » ou « à Tunis » (district vide).
  static String _placePhrase(String district, String city) =>
      district.isEmpty ? 'à $city' : '${_aContraction(district)}, $city';

  /// « à » + article : « Les Berges du Lac » → « aux Berges du Lac ».
  static String _aContraction(String place) {
    if (place.startsWith('Les ')) return 'aux ${place.substring(4)}';
    if (place.startsWith('Le ')) return 'au ${place.substring(3)}';
    if (place.startsWith("L'") || place.startsWith('L’')) {
      return 'à l’${place.substring(2)}';
    }
    return 'à $place';
  }

  /// « en bon état », « neuf » / « neuve », « à rénover ».
  static String _conditionPhrase(PropertyCondition condition,
          {required bool feminine}) =>
      switch (condition) {
        PropertyCondition.asNew => feminine ? 'neuve' : 'neuf',
        PropertyCondition.good => 'en bon état',
        PropertyCondition.toRenovate => 'à rénover',
      };
}
