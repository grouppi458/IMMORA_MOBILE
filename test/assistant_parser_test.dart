import 'package:flutter_test/flutter_test.dart';

import 'package:immora_mobile/module_gestion_annonces/ai/assistant_parser.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/module_gestion_annonces/models/listing.dart';
import 'package:immora_mobile/module_gestion_annonces/models/listing_details.dart';
import 'package:immora_mobile/module_gestion_biens/models/property.dart';

const _cities = ['Tunis', 'Ariana', 'La Marsa', 'Carthage'];
const _districts = ['Les Berges du Lac 2', 'Gammarth', 'Ennasr 2', 'Lafayette'];

PropertyFilter parse(String text) =>
    AssistantParser.parse(text, cities: _cities, districts: _districts);

ListingDetails details({
  PropertyType type = PropertyType.apartment,
  DealType deal = DealType.sale,
  double price = 320000,
  int rooms = 2,
  String city = 'Ariana',
  String district = 'Ennasr 2',
  PropertyStatus status = PropertyStatus.available,
}) {
  final property = Property(
    id: 1,
    agencyId: 1,
    title: 'Bien de test',
    type: type,
    dealType: deal,
    price: price,
    surface: 100,
    rooms: rooms,
    city: city,
    district: district,
    status: status,
    createdAt: 0,
  );
  return ListingDetails(
    listing: Listing(
      id: 1,
      propertyId: 1,
      agencyId: 1,
      title: 'Bien de test',
      text: '',
      displayedPrice: price,
      durationDays: 30,
      status: ListingStatus.published,
      createdAt: 0,
      updatedAt: 0,
    ),
    property: property,
    agencyName: 'Agence test',
    favoritesCount: 0,
  );
}

void main() {
  group('AssistantParser', () {
    test('maquette : « Quels appartements sont disponibles à moins de 400 000 TND ? »',
        () {
      final f = parse('Quels appartements sont disponibles à moins de 400 000 TND ?');
      expect(f.types, {PropertyType.apartment});
      expect(f.maxPrice, 400000);
      expect(f.availableOnly, isTrue);
      expect(f.isUsable, isTrue);
      expect(f.chips, containsAll([
        ('type', 'appartement'),
        ('maxPrice', '400\u202F000'),
        ('status', 'disponible'),
      ]));
    });

    test('« Villas à louer à Gammarth » : type, location, quartier', () {
      final f = parse('Villas à louer à Gammarth');
      expect(f.types, {PropertyType.villa});
      expect(f.dealType, DealType.rent);
      expect(f.district, 'Gammarth');
      expect(f.city, isEmpty);
      expect(f.isUsable, isTrue);
    });

    test('« S+3 à Tunis, max 500 000 » : chambres, ville, budget', () {
      final f = parse('S+3 à Tunis, max 500 000');
      expect(f.minRooms, 3);
      expect(f.city, 'Tunis');
      expect(f.maxPrice, 500000);
      expect(f.types, isEmpty);
      expect(f.isUsable, isTrue);
    });

    test('« Et une maison au bord de la mer ? » : trop vague, non exploitable', () {
      final f = parse('Et une maison au bord de la mer ?');
      expect(f.types, {PropertyType.house});
      expect(f.isUsable, isFalse);
    });

    test('accents ignorés : « appartement a tunis » ≡ « appartement à Tunis »', () {
      expect(parse('appartement a tunis').city, 'Tunis');
      expect(parse('appartement à Tunis').city, 'Tunis');
    });

    test('« max 500 » à la vente vaut 500 000 TND', () {
      expect(parse('appartement max 500').maxPrice, 500000);
    });

    test('un loyer ne subit pas le raccourci ×1000 : « location à 1 500 TND »', () {
      final f = parse('appartement en location à moins de 1 500 TND');
      expect(f.dealType, DealType.rent);
      expect(f.maxPrice, 1500);
    });

    test('« budget de 1 200 000 » et « jusqu\'à 300 000 »', () {
      expect(parse('budget de 1 200 000').maxPrice, 1200000);
      expect(parse("jusqu'à 300 000").maxPrice, 300000);
    });

    test('« à partir de 300 000 » fixe un prix minimum', () {
      final f = parse('villa à partir de 300 000');
      expect(f.minPrice, 300000);
      expect(f.maxPrice, isNull);
    });

    test('quartier réduit à un mot : « menzah » retrouve « El Menzah 6 »', () {
      final f = AssistantParser.parse('appartement au Menzah, max 500 000',
          cities: _cities, districts: ['El Menzah 6', 'El Menzah 5']);
      expect(f.district, 'El Menzah 6');
    });

    test('« 3 chambres » et « studio »', () {
      expect(parse('appartement 3 chambres à Tunis').minRooms, 3);
      expect(parse('studio à Tunis').types, {PropertyType.apartment});
    });

    test('matches : filtre complet sur une annonce publiée', () {
      final f = parse('appartements disponibles à moins de 400 000 TND');
      expect(f.matches(details()), isTrue); // S+2, 320 000, disponible
      expect(f.matches(details(price: 420000)), isFalse); // trop cher
      expect(f.matches(details(type: PropertyType.villa)), isFalse); // pas un appartement
      expect(f.matches(details(status: PropertyStatus.sold)), isFalse); // vendu
    });

    test('matches : « à louer » n’accepte que la location', () {
      final f = parse('villas à louer');
      expect(f.matches(details(type: PropertyType.villa, deal: DealType.rent)), isTrue);
      expect(f.matches(details(type: PropertyType.villa, deal: DealType.sale)), isFalse);
    });

    test('matches : ville et quartier', () {
      final f = parse('appartement à Gammarth');
      expect(f.matches(details(city: 'La Marsa', district: 'Gammarth')), isTrue);
      expect(f.matches(details(city: 'Ariana', district: 'Ennasr 2')), isFalse);
    });
  });
}
