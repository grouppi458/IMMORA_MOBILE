import 'package:flutter_test/flutter_test.dart';

import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/module_gestion_annonces/matching/matching_engine.dart';
import 'package:immora_mobile/module_gestion_annonces/models/listing.dart';
import 'package:immora_mobile/module_gestion_annonces/models/listing_details.dart';
import 'package:immora_mobile/module_gestion_annonces/models/property.dart';
import 'package:immora_mobile/module_gestion_annonces/models/search_criteria.dart';

/// Moteur de matching du Module 5 (BF5.7, BF5.8) :
/// match = 100 × (0,35 budget + 0,25 zone + 0,20 chambres + 0,10 type + 0,10 surface).
void main() {
  Property flat({
    double price = 420000,
    String city = 'Tunis',
    String district = 'Les Berges du Lac',
    int rooms = 3,
    double surface = 120,
    PropertyType type = PropertyType.apartment,
    DealType deal = DealType.sale,
    List<String> amenities = const ['parking'],
  }) =>
      Property(
        agencyId: 1,
        title: 'Bien test',
        type: type,
        dealType: deal,
        price: price,
        surface: surface,
        rooms: rooms,
        city: city,
        district: district,
        amenities: amenities,
        createdAt: 0,
      );

  ListingDetails details(Property p, {int id = 1}) => ListingDetails(
        listing: Listing(
          id: id,
          propertyId: id,
          agencyId: 1,
          title: p.title,
          text: 'Texte de test assez long.',
          displayedPrice: p.price,
          durationDays: 30,
          status: ListingStatus.published,
          publishedAt: id,
          createdAt: 0,
          updatedAt: 0,
        ),
        property: p,
        agencyName: 'Agence',
        favoritesCount: 0,
      );

  const criteria = SearchCriteria(
    dealType: DealType.sale,
    types: {PropertyType.apartment},
    budgetMin: 300000,
    budgetMax: 500000,
    city: 'Tunis',
    minRooms: 2,
    minSurface: 90,
  );

  int score(Property p, [SearchCriteria c = criteria]) => MatchingEngine.score(p, p.price, c).score;

  test('tous les critères respectés = 100 avec une raison par critère', () {
    final m = MatchingEngine.score(flat(), 420000, criteria);
    expect(m.score, 100);
    expect(m.label, 'Très compatible');
    expect(m.reasons,
        ['Dans votre budget', 'À Tunis', '3 chambres', 'Type recherché', '120 m²']);
  });

  test('applique les poids : mauvaise ville = 100 − 25', () {
    expect(score(flat(city: 'Ariana', district: 'Ennasr')), 75);
  });

  test('mauvais type = 100 − 10 ; une chambre de moins = moitié des 20 %', () {
    expect(score(flat(type: PropertyType.house)), 90);
    expect(score(flat(rooms: 1)), 90);
    expect(score(flat(rooms: 0, type: PropertyType.office)), 70);
  });

  test('budget : 15 % au-dessus du max = moitié des 35 %, 30 % au-dessus = 0', () {
    expect(score(flat(price: 575000)), 83); // 100 − 17,5
    expect(score(flat(price: 650000)), 65);
    expect(score(flat(price: 900000)), 65);
  });

  test('surface : proportionnelle sous le minimum', () {
    expect(score(flat(surface: 45)), 95); // 0,10 × 0,5
  });

  test('quartier : 1 s’il correspond, 0,6 si seule la ville correspond', () {
    const c = SearchCriteria(city: 'Tunis', district: 'Berges du Lac');
    expect(score(flat(), c), 100);
    expect(score(flat(district: 'El Menzah 5'), c), 90); // 0,25 × 0,4 perdu
    // Comparaison sans accents ni majuscules
    expect(score(flat(city: 'Tunis', district: 'L’Aouina'), const SearchCriteria(district: "l'aouina")),
        100);
  });

  test('vente / location et parking indispensable sont des contraintes strictes', () {
    final rent = MatchingEngine.score(flat(deal: DealType.rent), 1500, criteria);
    expect(rent.excluded, isTrue);
    expect(rent.score, 0);
    final noParking = MatchingEngine.score(
        flat(amenities: const []), 420000, criteria.copyWith(needsParking: true));
    expect(noParking.isProposed, isFalse);
  });

  test('critères vides : tout vaut 100 mais aucune raison inventée', () {
    final m = MatchingEngine.score(flat(), 420000, SearchCriteria.empty);
    expect(m.score, 100);
    expect(m.reasons, isEmpty);
  });

  test('rank : score ≥ 50 seulement, du plus compatible au moins compatible', () {
    final ranked = MatchingEngine.rank([
      details(flat(city: 'Ariana', district: 'Ennasr'), id: 1), // 75
      details(flat(), id: 2), // 100
      details(flat(price: 900000, city: 'Sousse', district: 'Centre'), id: 3), // 40 → exclu
      details(flat(deal: DealType.rent), id: 4), // exclu
    ], criteria);
    expect(ranked.map((s) => s.details.listing.id), [2, 1]);
  });

  test('profil déduit des favoris (BF5.8)', () {
    final profile = MatchingEngine.profileFromFavorites([
      details(flat(price: 400000, rooms: 2), id: 1),
      details(flat(price: 500000, rooms: 3, type: PropertyType.house), id: 2),
      details(flat(deal: DealType.rent, price: 1200, city: 'Sousse'), id: 3),
    ])!;
    expect(profile.dealType, DealType.sale);
    expect(profile.types, {PropertyType.apartment, PropertyType.house});
    expect(profile.budgetMin, 320000);
    expect(profile.budgetMax, 600000);
    expect(profile.city, 'Tunis');
    expect(profile.minRooms, 2);
    expect(MatchingEngine.profileFromFavorites(const []), isNull);
  });

  test('recherche libre : chaque mot dans le titre, la ville, le quartier ou le type', () {
    final d = details(flat());
    expect(MatchingEngine.matchesQuery(d, 'tunis appartement'), isTrue);
    expect(MatchingEngine.matchesQuery(d, 'Berges · Lac'), isTrue);
    expect(MatchingEngine.matchesQuery(d, 'villa'), isFalse);
    expect(MatchingEngine.matchesQuery(d, ''), isTrue);
  });

  test('résumé des critères', () {
    expect(criteria.summary, 'achat · appartement · 300K–500K TND · Tunis · 2+ chambres · 90+ m²');
    expect(criteria.activeCount, 6);
  });
}
