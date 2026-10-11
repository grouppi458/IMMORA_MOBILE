import 'package:immora_mobile/core/utils/constants.dart';
import 'package:immora_mobile/module_gestion_biens/models/property.dart';
import 'package:immora_mobile/module_gestion_biens/repositories/property_repository.dart';

/// Résultat de l'estimation (maquette « Estimation du prix »).
class PriceEstimate {
  const PriceEstimate({
    required this.value,
    required this.low,
    required this.high,
    required this.pricePerM2,
    required this.usedFallback,
    required this.comparables,
    required this.conditionCoefficient,
    required this.roomsBonus,
    required this.amenitiesBonus,
    required this.areaLabel,
  });

  final int value; // prix estimé (arrondi à 1 000 TND)
  final int low; // fourchette basse (± estimateRangePercent)
  final int high;
  final double pricePerM2; // moyenne des comparables ou prix de la ville
  final bool usedFallback; // moins de estimateMinComparables comparables
  final List<Property> comparables;
  final double conditionCoefficient; // « Coef. état (bon) × 1,00 »
  final double roomsBonus; // « Chambres (S+3) + 4 % »
  final double amenitiesBonus; // « Équipements (parking, ascenseur) + 5 % »
  final String areaLabel; // « Prix moyen au m² (Lac) »

  int get comparablesCount => comparables.length;

  /// Écart du prix affiché à l'estimation, en % (485 000 vs 468 000 → +3,6).
  double deviationPercent(double price) =>
      value == 0 ? 0 : (price - value) / value * 100;

  /// Prix dans la fourchette ± [estimateRangePercent] : « cohérent ».
  bool isCoherent(double price) =>
      deviationPercent(price).abs() <= estimateRangePercent * 100;
}

/// BF3.6 — estimation du prix : prix moyen au m² des biens comparables
/// (même ville, type et transaction ; statut sold ou available) × surface ×
/// coefficients (état, chambres, équipements). Sous 3 comparables, le prix
/// moyen par défaut de la ville ([defaultPricePerM2]) sert de base.
class PriceEstimator {
  PriceEstimator({PropertyRepository? properties})
      : _properties = properties ?? PropertyRepository();

  final PropertyRepository _properties;

  Future<PriceEstimate> estimate(Property p) async {
    final comparables = await _properties.comparables(p);
    final usedFallback = comparables.length < estimateMinComparables;
    final pricePerM2 = usedFallback
        ? (defaultPricePerM2[p.city] ?? fallbackPricePerM2)
        : comparables.fold<double>(0, (sum, c) => sum + c.price / c.surface) /
            comparables.length;

    final conditionCoefficient = estimateConditionCoefficient[p.condition] ?? 1;
    final roomsBonus = p.rooms > 1 ? (p.rooms - 1) * estimateRoomsBonusPerRoom : 0.0;
    final amenitiesBonus = p.amenities.length * estimateAmenityBonus;
    final raw = pricePerM2 *
        p.surface *
        conditionCoefficient *
        (1 + roomsBonus) *
        (1 + amenitiesBonus);

    return PriceEstimate(
      value: _roundToThousand(raw),
      low: _roundToThousand(raw * (1 - estimateRangePercent)),
      high: _roundToThousand(raw * (1 + estimateRangePercent)),
      pricePerM2: pricePerM2,
      usedFallback: usedFallback,
      comparables: comparables,
      conditionCoefficient: conditionCoefficient,
      roomsBonus: roomsBonus,
      amenitiesBonus: amenitiesBonus,
      areaLabel: p.district.isEmpty ? p.city : p.district,
    );
  }

  static int _roundToThousand(double value) => (value / 1000).round() * 1000;
}
