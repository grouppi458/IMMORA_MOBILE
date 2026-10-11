import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/module_gestion_annonces/models/listing_details.dart';

/// Filtres structurés extraits d'une phrase en français par
/// [AssistantParser] : votre question → mots-clés + RegExp → PropertyFilter
/// → recherche parmi les annonces publiées (maquette Figma « Assistant »).
class PropertyFilter {
  const PropertyFilter({
    this.dealType,
    this.types = const {},
    this.maxPrice,
    this.minPrice,
    this.minRooms,
    this.city = '',
    this.district = '',
    this.availableOnly = false,
  });

  final DealType? dealType;
  final Set<PropertyType> types;
  final double? maxPrice;
  final double? minPrice;
  final int? minRooms;
  final String city;
  final String district; // quartier
  final bool availableOnly;

  /// Une recherche n'est lancée que si la phrase a livré un signal fort
  /// (achat/location, budget, chambres ou lieu). « Et une maison ? » seul
  /// est trop vague : l'assistant demande de préciser (maquette Figma).
  bool get isUsable =>
      dealType != null ||
      minRooms != null ||
      minPrice != null ||
      maxPrice != null ||
      city.isNotEmpty ||
      district.isNotEmpty;

  /// Puces « FILTRE COMPRIS » : (étiquette, valeur) affichées dans le chat.
  List<(String, String)> get chips => [
        if (types.isNotEmpty)
          ('type', types.map((t) => t.label.toLowerCase()).join(', ')),
        if (dealType != null)
          ('dealType', dealType == DealType.rent ? 'location' : 'vente'),
        if (maxPrice != null) ('maxPrice', formatNumber(maxPrice!)),
        if (minPrice != null) ('minPrice', formatNumber(minPrice!)),
        if (minRooms != null) ('chambres', '$minRooms+'),
        if (city.isNotEmpty) ('ville', city),
        if (district.isNotEmpty) ('quartier', district),
        if (availableOnly) ('status', 'disponible'),
      ];

  /// Teste une annonce publiée contre les critères compris.
  bool matches(ListingDetails d) {
    final p = d.property;
    if (dealType != null && p.dealType != dealType) return false;
    if (types.isNotEmpty && !types.contains(p.type)) return false;
    if (minRooms != null && p.rooms < minRooms!) return false;
    if (maxPrice != null && d.listing.displayedPrice > maxPrice!) return false;
    if (minPrice != null && d.listing.displayedPrice < minPrice!) return false;
    if (city.isNotEmpty && !_same(p.city, city)) return false;
    if (district.isNotEmpty && !_same(p.district, district)) return false;
    if (availableOnly && p.status != PropertyStatus.available) return false;
    return true;
  }

  static bool _same(String a, String b) => _plain(a) == _plain(b);
}

/// Analyse en langage naturel : « villas à louer à Gammarth », « S+3 à Tunis,
/// max 500 000 »… Sans réponse exploitable, l'écran retombe sur le message
/// « Je n'ai pas compris… » de la maquette.
class AssistantParser {
  AssistantParser._();

  static final _rent = RegExp(r'\b(?:louer|location|locatifs?|locatives?)\b');
  static final _sale = RegExp(r'\b(?:vendre|vente|acheter|achat)\b');
  static final _available = RegExp(r'\b(?:disponibles?|dispo|libres?)\b');

  static final _types = <PropertyType, RegExp>{
    PropertyType.apartment:
        RegExp(r'\b(?:appartements?|apparts?|studios?|duplex)\b'),
    PropertyType.house: RegExp(r'\bmaisons?\b'),
    PropertyType.villa: RegExp(r'\bvillas?\b'),
    PropertyType.land: RegExp(r'\bterrains?\b'),
    PropertyType.office: RegExp(r'\bbureaux?\b'),
  };

  // « S+3 », « s + 3 », « 3 chambres », « 3 pièces ».
  static final _sPlus = RegExp(r'\bs\s*\+\s*(\d)');
  static final _rooms = RegExp(r'(\d)\s*(?:chambres?|pieces?)\b');

  // Nombre monétaire : groupes de milliers (« 400 000 », « 400.000 »).
  static const _amount = r"(\d{1,3}(?:[\s\u00A0\u202F.,]\d{3})+|\d+)\s*(k|millions?)?";

  // « à moins de 400 000 », « max 500 », « jusqu'à 300 000 », « budget de … ».
  static final _maxPrice = RegExp(
      r'\b(moins de|maximum|max|jusqu[\u2019\x27]?a|budget(?: de)?|inferieur(?:e)? a|sous|vers)\b\s*' +
          _amount);

  // « à partir de 300 000 », « au moins 200 000 », « dès 150 000 ».
  static final _minPrice = RegExp(
      r'\b(plus de|au moins|minimum|min|a partir de|des)\b\s*' + _amount);

  /// [cities] / [districts] : lieux connus (annonces publiées) reconnus dans
  /// la phrase — « Gammarth » devient quartier, « La Marsa » ville.
  static PropertyFilter parse(
    String text, {
    List<String> cities = const [],
    List<String> districts = const [],
  }) {
    final t = _plain(text);

    final types = <PropertyType>{
      for (final e in _types.entries)
        if (e.value.hasMatch(t)) e.key,
    };

    final DealType? deal;
    if (_rent.hasMatch(t)) {
      deal = DealType.rent;
    } else if (_sale.hasMatch(t)) {
      deal = DealType.sale;
    } else {
      deal = null;
    }

    int? rooms;
    final sPlus = _sPlus.firstMatch(t) ?? _rooms.firstMatch(t);
    if (sPlus != null) {
      final n = int.parse(sPlus.group(1)!);
      if (n >= 1 && n <= 6) rooms = n;
    }

    var maxPrice = _amountOf(_maxPrice.firstMatch(t), deal);
    final minMatch = _minPrice.firstMatch(t);
    var minPrice = _amountOf(minMatch, deal);
    if (minMatch != null && maxPrice != null) {
      // Un seul montant capturé deux fois (« max 500, minimum 300 » reste rare).
      if (minMatch.start == _maxPrice.firstMatch(t)?.start) maxPrice = null;
    }
    // Un seul budget exprimé sans mot-clé « min »/« max » : « villa 2 000 000 ».
    if (maxPrice == null && minPrice == null && deal != null) {
      final loose = RegExp(_amount).firstMatch(t);
      maxPrice = _amountOf(loose, deal);
    }

    return PropertyFilter(
      dealType: deal,
      types: types,
      maxPrice: maxPrice,
      minPrice: minPrice,
      minRooms: rooms,
      city: _matchPlace(t, cities),
      district: _matchPlace(t, districts),
      availableOnly: _available.hasMatch(t),
    );
  }

  static double? _amountOf(RegExpMatch? m, DealType? deal) {
    if (m == null) return null;
    var digits = m.group(m.groupCount - 1)!;
    final suffix = m.group(m.groupCount);
    digits = digits
        .replaceAll(RegExp(r'[\s\u00A0\u202F]'), '')
        .replaceAll(RegExp(r'[.,](\d{3})$'), r'$1')
        .replaceAll(',', '.');
    var v = double.tryParse(digits);
    if (v == null) return null;
    if (suffix == 'k') return v * 1000;
    if (suffix != null && suffix.startsWith('million')) return v * 1000000;
    // « max 500 » = 500 000 TND à la vente ; un loyer s'exprime en centaines.
    if (v < 10000 && deal != DealType.rent) v *= 1000;
    return v >= 50 ? v : null;
  }

  /// Le lieu le plus long reconnu (nom complet ou mot significatif :
  /// « menzah » → « El Menzah 6 »).
  static String _matchPlace(String text, List<String> places) {
    var best = '';
    for (final p in places) {
      final n = _plain(p);
      if (n.isEmpty) continue;
      final hit = text.contains(n) ||
          n.split(' ').any((w) => w.length >= 4 && text.contains(w));
      if (hit && n.length > _plain(best).length) best = p;
    }
    return best;
  }
}

const _accents = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i', 'ô': 'o', 'ö': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'œ': 'oe', '’': "'",
};

/// Minuscules sans accents, espaces normalisés : les RegExp ci-dessus
/// matchent la même chose que l'utilisateur écrive « à louer » ou « a louer ».
String _plain(String s) {
  final buffer = StringBuffer();
  for (final rune in s.toLowerCase().runes) {
    final c = String.fromCharCode(rune);
    buffer.write(_accents[c] ?? c);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}
