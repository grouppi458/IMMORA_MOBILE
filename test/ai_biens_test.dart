import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:immora_mobile/ai/description_generator.dart';
import 'package:immora_mobile/ai/price_estimator.dart';
import 'package:immora_mobile/core/database/database_helper.dart';
import 'package:immora_mobile/core/utils/constants.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/module_gestion_biens/models/property.dart';
import 'package:immora_mobile/module_gestion_biens/repositories/property_repository.dart';

/// Module 3 : description IA (BF3.8) et estimation du prix (BF3.6–BF3.7).
void main() {
  Property build({
    PropertyType type = PropertyType.apartment,
    DealType dealType = DealType.sale,
    double price = 485000,
    double surface = 145,
    int rooms = 3,
    int? floor = 4,
    String city = 'Tunis',
    String district = 'Les Berges du Lac',
    List<String> amenities = const ['parking', 'ascenseur'],
    PropertyCondition condition = PropertyCondition.good,
    PropertyStatus status = PropertyStatus.available,
    int? id,
    int agencyId = 1,
  }) =>
      Property(
        id: id,
        agencyId: agencyId,
        title: 'Appartement S+3 · Lac',
        type: type,
        dealType: dealType,
        price: price,
        surface: surface,
        rooms: rooms,
        floor: floor,
        city: city,
        district: district,
        amenities: amenities,
        condition: condition,
        status: status,
        createdAt: 0,
      );

  group('DescriptionGenerator (BF3.8)', () {
    test('remplit le modèle avec les champs puis les équipements (maquette)', () {
      final text = DescriptionGenerator.generate(build());
      expect(
          text,
          'Appartement S+3 de 145 m² situé aux Berges du Lac, Tunis, en bon état, '
          'disposant d’un parking et d’un ascenseur. Prix : ${formatNumber(485000)} TND.');
    });

    test('équipements détectés : équipements, étage, état (puces)', () {
      expect(DescriptionGenerator.detectedFeatures(build()),
          ['Parking', 'Ascenseur', 'Étage 4', 'Bon état']);
      expect(
          DescriptionGenerator.detectedFeatures(build(
              floor: null, amenities: const [], condition: PropertyCondition.toRenovate)),
          ['À rénover']);
    });

    test('location : loyer mensuel, sans district et sans équipement', () {
      final text = DescriptionGenerator.generate(build(
        dealType: DealType.rent,
        price: 1800,
        surface: 95,
        rooms: 2,
        city: 'La Marsa',
        district: '',
        amenities: const [],
      ));
      expect(text,
          'Appartement S+2 de 95 m² situé à La Marsa, en bon état. Loyer : ${formatNumber(1800)} TND /mois.');
    });

    test('accords : villa féminine, « neuve », article contracté', () {
      final text = DescriptionGenerator.generate(build(
        type: PropertyType.villa,
        surface: 320,
        rooms: 5,
        city: 'La Marsa',
        district: 'Gammarth',
        amenities: const ['jardin', 'piscine'],
        condition: PropertyCondition.asNew,
      ));
      expect(text,
          'Villa S+5 de 320 m² située à Gammarth, La Marsa, neuve, '
          'disposant d’un jardin et d’une piscine. Prix : ${formatNumber(485000)} TND.');
    });

    test('terrain : ni étage S+N ni chambre', () {
      final text = DescriptionGenerator.generate(build(
        type: PropertyType.land,
        surface: 500,
        rooms: 0,
        floor: null,
        city: 'La Soukra',
        district: 'La Soukra',
        amenities: const [],
      ));
      expect(text.startsWith('Terrain de 500 m² situé à La Soukra, La Soukra'), isTrue);
    });

    test('le modèle affiché dépend de la transaction', () {
      expect(DescriptionGenerator.template(DealType.sale), contains('Prix : {price} TND.'));
      expect(
          DescriptionGenerator.template(DealType.rent), contains('Loyer : {price} TND /mois.'));
    });
  });

  group('PriceEstimator (BF3.6–BF3.7)', () {
    late Database db;
    final properties = PropertyRepository();
    final estimator = PriceEstimator();
    late int heroId;

    setUpAll(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      // Répertoire distinct : les suites s'exécutent en parallèle et chacune
      // supprime puis recrée la base de démonstration.
      await databaseFactoryFfi.setDatabasesPath(join(
          Directory.current.path, '.dart_tool', 'sqflite_common_ffi', 'databases-ai-tests'));
      await databaseFactory.deleteDatabase(join(await getDatabasesPath(), dbName));
      db = await DatabaseHelper.instance.database;
      heroId = (await db.query('properties',
              where: 'title = ?', whereArgs: ['Appartement S+3 · Lac']))
          .first['id'] as int;
    });

    test('l’écart au prix estimé se lit en pourcentage (3,6 % de la maquette)', () {
      const est = PriceEstimate(
        value: 468000,
        low: 421000,
        high: 515000,
        pricePerM2: 3228,
        usedFallback: false,
        comparables: [],
        conditionCoefficient: 1,
        roomsBonus: 0.04,
        amenitiesBonus: 0.05,
        areaLabel: 'Lac',
      );
      expect(est.deviationPercent(485000), closeTo(3.63, 0.01));
      expect(est.isCoherent(485000), isTrue);
      expect(est.isCoherent(520000), isFalse); // +11,1 %
      expect(est.isCoherent(430000), isTrue); // −8,1 %
      expect(est.isCoherent(421000), isFalse); // −10,04 %, hors fourchette
    });

    test('base = prix moyen au m² des comparables de la ville', () async {
      final hero = (await properties.findById(heroId))!;
      final comparables = await properties.comparables(hero);
      expect(comparables.length, greaterThanOrEqualTo(estimateMinComparables));
      expect(
          comparables.every((c) =>
              c.city == hero.city &&
              c.type == hero.type &&
              c.dealType == hero.dealType &&
              c.id != hero.id &&
              (c.status == PropertyStatus.sold || c.status == PropertyStatus.available)),
          isTrue);

      final est = await estimator.estimate(hero);
      expect(est.usedFallback, isFalse);
      expect(est.comparablesCount, comparables.length);
      expect(est.areaLabel, 'Les Berges du Lac');

      final pm2 =
          comparables.fold<double>(0, (s, c) => s + c.price / c.surface) / comparables.length;
      expect(est.pricePerM2, closeTo(pm2, 0.001));
      expect(est.conditionCoefficient, 1.00);
      expect(est.roomsBonus, closeTo(2 * estimateRoomsBonusPerRoom, 1e-9));

      // 3 228 TND/m² × 145 m² × 1,04 chambres × 1,05 équipements, arrondi aux 1 000.
      final raw = pm2 * hero.surface * 1.00 * 1.04 * 1.05;
      expect(est.value, (raw / 1000).round() * 1000);
      expect(est.low, lessThan(est.value));
      expect(est.high, greaterThan(est.value));
    });

    test('moins de 3 comparables : prix moyen par défaut de la ville', () async {
      final id = await properties.create(build(
        price: 250000,
        surface: 100,
        rooms: 2,
        city: 'Sousse',
        district: 'Khezama',
        amenities: const [],
      ));
      final est = await estimator.estimate((await properties.findById(id))!);

      expect(est.usedFallback, isTrue);
      expect(est.comparablesCount, 0);
      expect(est.pricePerM2, defaultPricePerM2['Sousse']);
      expect(est.roomsBonus, closeTo(estimateRoomsBonusPerRoom, 1e-9));
      // 2 500 × 100 × 1,00 × 1,02 = 255 000 TND.
      expect(est.value, 255000);
      expect(est.low, 230000);
      expect(est.high, 281000);
    });

    test('ville inconnue : repli sur fallbackPricePerM2 et coefficients complets', () async {
      final id = await properties.create(build(
        price: 300000,
        surface: 100,
        city: 'Nabeul',
        district: 'Dar Chaabane',
        condition: PropertyCondition.toRenovate,
      ));
      final est = await estimator.estimate((await properties.findById(id))!);

      expect(est.usedFallback, isTrue);
      expect(est.pricePerM2, fallbackPricePerM2);
      expect(est.conditionCoefficient, 0.90);
      expect(est.amenitiesBonus, closeTo(2 * estimateAmenityBonus, 1e-9));
      // 3 000 × 100 × 0,90 × 1,04 × 1,05 = 294 840 → 295 000 TND.
      expect(est.value, 295000);
      expect(est.low, 265000);
      expect(est.high, 324000);
    });
  });
}
