import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';

/// Critères d'un client (table `search_criteria`, BF5.6) — utilisés aussi
/// comme filtres de la recherche. Un champ null (ou vide) = « peu importe ».
class SearchCriteria {
  const SearchCriteria({
    this.dealType,
    this.types = const {},
    this.budgetMin,
    this.budgetMax,
    this.city = '',
    this.district = '',
    this.minRooms,
    this.minSurface,
    this.needsParking = false,
    this.alertsEnabled = true,
  });

  final DealType? dealType;
  final Set<PropertyType> types;
  final double? budgetMin; // TND
  final double? budgetMax;
  final String city;
  final String district; // quartier
  final int? minRooms;
  final double? minSurface; // m²
  final bool needsParking;
  final bool alertsEnabled; // BF5.9 : « nouvelle annonce pour vous »

  static const empty = SearchCriteria();

  /// Aucun critère qui influence le score (les alertes ne comptent pas).
  bool get isEmpty =>
      dealType == null &&
      types.isEmpty &&
      budgetMin == null &&
      budgetMax == null &&
      city.trim().isEmpty &&
      district.trim().isEmpty &&
      minRooms == null &&
      minSurface == null &&
      !needsParking;

  /// Nombre de filtres actifs (« Filtres · 3 »).
  int get activeCount => [
        dealType != null,
        types.isNotEmpty,
        budgetMin != null || budgetMax != null,
        city.trim().isNotEmpty || district.trim().isNotEmpty,
        minRooms != null,
        minSurface != null,
        needsParking,
      ].where((b) => b).length;

  /// « achat · 300–500K TND · Tunis · 2+ chambres »
  String get summary {
    String k(double v) => v >= 1000 ? '${formatNumber(v / 1000)}K' : formatNumber(v);
    final parts = <String>[
      if (dealType != null) dealType == DealType.sale ? 'achat' : 'location',
      if (types.isNotEmpty) types.map((t) => t.label.toLowerCase()).join(', '),
      if (budgetMin != null && budgetMax != null)
        '${k(budgetMin!)}–${k(budgetMax!)} TND'
      else if (budgetMax != null)
        'jusqu’à ${k(budgetMax!)} TND'
      else if (budgetMin != null)
        'dès ${k(budgetMin!)} TND',
      if (district.trim().isNotEmpty) district.trim(),
      if (city.trim().isNotEmpty) city.trim(),
      if (minRooms != null) '$minRooms+ chambres',
      if (minSurface != null) '${minSurface!.round()}+ m²',
      if (needsParking) 'parking',
    ];
    return parts.join(' · ');
  }

  SearchCriteria copyWith({
    DealType? Function()? dealType,
    Set<PropertyType>? types,
    double? Function()? budgetMin,
    double? Function()? budgetMax,
    String? city,
    String? district,
    int? Function()? minRooms,
    double? Function()? minSurface,
    bool? needsParking,
    bool? alertsEnabled,
  }) =>
      SearchCriteria(
        dealType: dealType != null ? dealType() : this.dealType,
        types: types ?? this.types,
        budgetMin: budgetMin != null ? budgetMin() : this.budgetMin,
        budgetMax: budgetMax != null ? budgetMax() : this.budgetMax,
        city: city ?? this.city,
        district: district ?? this.district,
        minRooms: minRooms != null ? minRooms() : this.minRooms,
        minSurface: minSurface != null ? minSurface() : this.minSurface,
        needsParking: needsParking ?? this.needsParking,
        alertsEnabled: alertsEnabled ?? this.alertsEnabled,
      );

  Map<String, dynamic> toMap(int clientId) => {
        'clientId': clientId,
        'dealType': dealType?.name,
        'types': types.map((t) => t.name).join(','),
        'budgetMin': budgetMin,
        'budgetMax': budgetMax,
        'city': city.trim(),
        'district': district.trim(),
        'minRooms': minRooms,
        'minSurface': minSurface,
        'needsParking': needsParking ? 1 : 0,
        'alertsEnabled': alertsEnabled ? 1 : 0,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

  factory SearchCriteria.fromMap(Map<String, dynamic> m) {
    final types = (m['types'] as String?) ?? '';
    return SearchCriteria(
      dealType: m['dealType'] == null ? null : DealType.values.byName(m['dealType']),
      types: types.isEmpty
          ? const {}
          : types.split(',').map(PropertyType.values.byName).toSet(),
      budgetMin: (m['budgetMin'] as num?)?.toDouble(),
      budgetMax: (m['budgetMax'] as num?)?.toDouble(),
      city: m['city'] ?? '',
      district: m['district'] ?? '',
      minRooms: m['minRooms'],
      minSurface: (m['minSurface'] as num?)?.toDouble(),
      needsParking: m['needsParking'] == 1,
      alertsEnabled: m['alertsEnabled'] != 0,
    );
  }
}
