import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/module_gestion_annonces/models/listing_details.dart';
import 'package:immora_mobile/module_gestion_annonces/models/property.dart';
import 'package:immora_mobile/module_gestion_annonces/models/search_criteria.dart';

/// Les cinq composantes du score, avec leur poids (cahier des charges, M5).
enum MatchFactor {
  budget(0.35, 'Budget'),
  zone(0.25, 'Zone'),
  rooms(0.20, 'Chambres'),
  type(0.10, 'Type'),
  surface(0.10, 'Surface');

  const MatchFactor(this.weight, this.label);

  final double weight;
  final String label;
}

/// Résultat du matching d'une annonce avec des critères (BF5.7).
class MatchResult {
  const MatchResult({
    required this.score,
    required this.subScores,
    required this.reasons,
    this.excluded = false,
  });

  /// 0 à 100.
  final int score;

  /// Sous-score de 0 à 1 par composante.
  final Map<MatchFactor, double> subScores;

  /// Une raison lisible par sous-score ≥ 0,8 (« Dans votre budget »…).
  final List<String> reasons;

  /// Contrainte stricte non respectée (vente / location, parking indispensable).
  final bool excluded;

  bool get isProposed => !excluded && score >= MatchingEngine.minScore;

  /// « Très compatible », « Compatible »…
  String get label => score >= MatchingEngine.alertScore
      ? 'Très compatible'
      : score >= 65
          ? 'Compatible'
          : score >= MatchingEngine.minScore
              ? 'Assez compatible'
              : 'Peu compatible';
}

/// Annonce accompagnée de son score.
class ScoredListing {
  const ScoredListing(this.details, this.match);

  final ListingDetails details;
  final MatchResult match;
}

/// Moteur de recherche intelligente et de matching (Module 5, BF5.6 – BF5.9).
///
///   match = 100 × (0,35·s_budget + 0,25·s_zone + 0,20·s_chambres
///                  + 0,10·s_type + 0,10·s_surface)
///
/// Chaque sous-score vaut entre 0 et 1 ; un critère non renseigné vaut 1
/// (« peu importe »). Vente / location et « parking indispensable » sont des
/// contraintes strictes : une annonce qui ne les respecte pas est exclue.
class MatchingEngine {
  MatchingEngine._();

  /// Seules les annonces avec un score ≥ 50 sont proposées.
  static const minScore = 50;

  /// Seuil des alertes « nouvelle annonce pour vous » (BF5.9).
  static const alertScore = 80;

  /// Taille du bloc « Pour vous » (BF5.8).
  static const recommendationsCount = 10;

  /// Une raison s'affiche pour chaque sous-score ≥ 0,8.
  static const reasonThreshold = 0.8;

  /// Tolérance au-dessus du budget max : 30 % de dépassement → 0.
  static const _overBudgetTolerance = 0.30;

  /// Tolérance sous le budget min : 50 % en dessous → 0.
  static const _underBudgetTolerance = 0.50;

  /// BF5.7 — score de compatibilité d'un bien affiché à [price] avec [c].
  static MatchResult score(Property p, double price, SearchCriteria c) {
    final excluded = (c.dealType != null && c.dealType != p.dealType) ||
        (c.needsParking && !p.amenities.contains('parking'));

    final sub = <MatchFactor, double>{
      MatchFactor.budget: _budget(price, c),
      MatchFactor.zone: _zone(p, c),
      MatchFactor.rooms: _rooms(p, c),
      MatchFactor.type: c.types.isEmpty || c.types.contains(p.type) ? 1.0 : 0.0,
      MatchFactor.surface: c.minSurface == null || c.minSurface! <= 0
          ? 1.0
          : (p.surface / c.minSurface!).clamp(0.0, 1.0),
    };
    final total = sub.entries.fold<double>(0, (s, e) => s + e.key.weight * e.value);

    return MatchResult(
      score: excluded ? 0 : (100 * total).round(),
      subScores: sub,
      reasons: excluded ? const [] : _reasons(p, c, sub),
      excluded: excluded,
    );
  }

  static MatchResult scoreListing(ListingDetails d, SearchCriteria c) =>
      score(d.property, d.listing.displayedPrice, c);

  /// Annonces proposées (score ≥ [min]), de la plus compatible à la moins compatible.
  static List<ScoredListing> rank(List<ListingDetails> listings, SearchCriteria c,
      {int min = minScore}) {
    final scored = [
      for (final d in listings) ScoredListing(d, scoreListing(d, c)),
    ].where((s) => !s.match.excluded && s.match.score >= min).toList()
      ..sort((a, b) {
        final byScore = b.match.score.compareTo(a.match.score);
        if (byScore != 0) return byScore;
        return (b.details.listing.publishedAt ?? 0).compareTo(a.details.listing.publishedAt ?? 0);
      });
    return scored;
  }

  /// BF5.8 — sans critères enregistrés, le profil est déduit des favoris :
  /// mode le plus fréquent, types aimés, budget ± 20 %, ville la plus
  /// fréquente, chambres minimum. Renvoie null s'il n'y a aucun favori.
  static SearchCriteria? profileFromFavorites(List<ListingDetails> favorites) {
    if (favorites.isEmpty) return null;
    T mostFrequent<T>(Iterable<T> values) {
      final counts = <T, int>{};
      for (final v in values) {
        counts[v] = (counts[v] ?? 0) + 1;
      }
      return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    }

    final deal = mostFrequent(favorites.map((d) => d.property.dealType));
    final sameDeal = favorites.where((d) => d.property.dealType == deal).toList();
    final prices = sameDeal.map((d) => d.listing.displayedPrice);
    final rooms = sameDeal.map((d) => d.property.rooms).where((r) => r > 0);
    return SearchCriteria(
      dealType: deal,
      types: sameDeal.map((d) => d.property.type).toSet(),
      budgetMin: (prices.reduce((a, b) => a < b ? a : b) * 0.8).roundToDouble(),
      budgetMax: (prices.reduce((a, b) => a > b ? a : b) * 1.2).roundToDouble(),
      city: mostFrequent(sameDeal.map((d) => d.property.city)),
      minRooms: rooms.isEmpty ? null : rooms.reduce((a, b) => a < b ? a : b),
    );
  }

  /// Recherche libre (« Tunis · Appartement ») : chaque mot doit apparaître
  /// dans le titre, la ville, le quartier ou le type du bien.
  static bool matchesQuery(ListingDetails d, String query) {
    final words = normalize(query).split(RegExp(r'[\s·,]+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return true;
    final haystack = normalize([
      d.listing.title,
      d.property.city,
      d.property.district,
      d.property.type.label,
      d.property.dealType.label,
    ].join(' '));
    return words.every(haystack.contains);
  }

  /// Minuscules sans accents ni apostrophes, pour comparer les lieux.
  static String normalize(String s) {
    const from = 'àâäáãéèêëíìîïóòôöõúùûüçñ’\'';
    const to = 'aaaaaeeeeiiiiooooouuuucn  ';
    final lower = s.toLowerCase();
    final buffer = StringBuffer();
    for (final ch in lower.split('')) {
      final i = from.indexOf(ch);
      buffer.write(i < 0 ? ch : to[i]);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  // ---------------------------------------------------------------- Sous-scores

  static double _budget(double price, SearchCriteria c) {
    final max = c.budgetMax, min = c.budgetMin;
    if (max != null && max > 0 && price > max) {
      return (1 - (price - max) / (_overBudgetTolerance * max)).clamp(0.0, 1.0);
    }
    if (min != null && min > 0 && price < min) {
      return (1 - (min - price) / (_underBudgetTolerance * min)).clamp(0.0, 1.0);
    }
    return 1.0;
  }

  /// Quartier demandé → 1 s'il correspond, 0,6 si seule la ville correspond.
  /// Ville demandée → 1 si elle correspond (ville ou quartier du bien).
  static double _zone(Property p, SearchCriteria c) {
    final city = normalize(c.city), district = normalize(c.district);
    final pCity = normalize(p.city), pDistrict = normalize(p.district);
    bool same(String wanted, String actual) =>
        actual.isNotEmpty && (actual.contains(wanted) || wanted.contains(actual));
    if (district.isNotEmpty) {
      if (same(district, pDistrict)) return 1.0;
      if (city.isNotEmpty && same(city, pCity)) return 0.6;
      return 0.0;
    }
    if (city.isNotEmpty) return same(city, pCity) || same(city, pDistrict) ? 1.0 : 0.0;
    return 1.0;
  }

  /// Assez de chambres → 1 ; une de moins → 0,5 ; sinon 0.
  static double _rooms(Property p, SearchCriteria c) {
    final min = c.minRooms;
    if (min == null || min <= 0) return 1.0;
    if (p.rooms >= min) return 1.0;
    if (p.rooms == min - 1 && p.rooms > 0) return 0.5;
    return 0.0;
  }

  /// Raisons des sous-scores ≥ 0,8, seulement pour les critères renseignés.
  static List<String> _reasons(Property p, SearchCriteria c, Map<MatchFactor, double> sub) {
    bool good(MatchFactor f) => sub[f]! >= reasonThreshold;
    return [
      if ((c.budgetMin != null || c.budgetMax != null) && good(MatchFactor.budget))
        'Dans votre budget',
      if ((c.city.trim().isNotEmpty || c.district.trim().isNotEmpty) && good(MatchFactor.zone))
        'À ${c.district.trim().isNotEmpty ? p.district : p.city}',
      if (c.minRooms != null && good(MatchFactor.rooms))
        '${p.rooms} chambre${p.rooms > 1 ? 's' : ''}',
      if (c.types.isNotEmpty && good(MatchFactor.type)) 'Type recherché',
      if (c.minSurface != null && good(MatchFactor.surface)) '${p.surface.round()} m²',
    ];
  }
}
