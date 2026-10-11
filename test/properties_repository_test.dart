import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:immora_mobile/core/database/database_helper.dart';
import 'package:immora_mobile/core/errors/app_exception.dart';
import 'package:immora_mobile/core/utils/constants.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/module_gestion_biens/models/property.dart';
import 'package:immora_mobile/module_gestion_biens/repositories/property_repository.dart';

/// Module 3 : le parc de Carthage Immobilier créé par les données de
/// démonstration (22 biens après les statuts posés par le M4), le
/// portefeuille de Rania Nasri (18 biens, dont deux gérés par Gammarth
/// Luxury) et le cycle de vie d'un bien : contrôle de saisie, statut,
/// photos, suppression.
void main() {
  late Database db;
  final properties = PropertyRepository();
  late int carthage;
  late int owner;
  late int sirine;

  Future<int> idOf(String table, String email) async =>
      (await db.query(table, where: 'email = ?', whereArgs: [email])).first['id'] as int;

  Future<int> propertyId(String title) async =>
      (await db.query('properties', columns: ['id'], where: 'title = ?', whereArgs: [title]))
          .first['id'] as int;

  Property villa(
    String title, {
    double price = 780000,
    double surface = 260,
    double? landSurface = 400,
    String city = 'Ben Arous',
    String description = '',
  }) =>
      Property(
        agencyId: carthage,
        ownerId: owner,
        agentId: sirine,
        title: title,
        type: PropertyType.villa,
        dealType: DealType.sale,
        price: price,
        surface: surface,
        landSurface: landSurface,
        rooms: 5,
        city: city,
        district: 'Radès',
        address: 'Rue de la Plage, Radès',
        amenities: const ['jardin'],
        description: description,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Répertoire distinct des autres suites : chaque fichier supprime puis
    // recrée sa propre base de démonstration.
    await databaseFactoryFfi.setDatabasesPath(join(Directory.current.path, '.dart_tool',
        'sqflite_common_ffi', 'databases-properties-tests'));
    await databaseFactory.deleteDatabase(join(await getDatabasesPath(), dbName));
    db = await DatabaseHelper.instance.database;
    carthage = await idOf('agencies', 'agence@immora.tn');
    owner = await idOf('users', 'proprietaire@immora.tn');
    final sirineUser = await idOf('users', 'sirine@carthage-immo.tn');
    sirine = (await db.query('agents',
            columns: ['id'], where: 'userId = ?', whereArgs: [sirineUser]))
        .first['id'] as int;
  });

  Matcher throwsAdmin([String? field]) => throwsA(
      isA<AdminException>().having((e) => e.field, 'field', field ?? anything));

  test('démo : le parc de l’agence, filtré par statut et par recherche', () async {
    expect(await properties.agencyProperties(carthage), hasLength(22));

    final counts = await properties.countByStatus(carthage);
    expect(counts[PropertyStatus.available], 15);
    expect(counts[PropertyStatus.rented], 2);
    expect(counts[PropertyStatus.reserved], 1);
    expect(counts[PropertyStatus.sold], 4);
    expect(counts.values.fold(0, (sum, n) => sum + n), 22);

    // « Loué » et « Vendu » posés par les signatures du M4.
    expect(
        (await properties.agencyProperties(carthage, status: PropertyStatus.rented))
            .map((p) => p.title),
        ['Appartement S+2 · Marsa', 'Duplex · Carthage']);
    expect(
        (await properties.agencyProperties(carthage, status: PropertyStatus.reserved))
            .map((p) => p.title),
        ['Studio · El Menzah']);

    // Recherche : titre, ville ou quartier.
    final berges = await properties.agencyProperties(carthage, query: 'Berges du Lac');
    expect(berges, hasLength(6));
    expect(berges.map((p) => p.title), contains('Appartement S+3 · Lac'));
    expect(berges.every((p) => p.district.startsWith('Les Berges du Lac')), isTrue);
  });

  test('fiche du bien central : libellés, vues et publication de la maquette', () async {
    final d = (await properties.details(await propertyId('Appartement S+3 · Lac')))!;
    expect(d.property.price, 485000);
    expect(d.property.surface, 145);
    expect(d.property.status, PropertyStatus.available);
    expect(d.agencyName, 'Carthage Immobilier');
    expect(d.ownerName, 'Rania Nasri');
    expect(d.agentName, 'Sirine Ben Salah');
    expect(d.views, 142);
    expect(d.publishedAt, isNotNull);
    expect(d.listingId, isNotNull);
    expect(d.favoritesCount, 0);

    // Listes du formulaire : « Propriétaire » et « Agent responsable ».
    expect((await properties.ownerOptions()).map((o) => o.$2), contains('Rania Nasri'));
    expect((await properties.agentOptions(carthage)).map((a) => a.$2),
        contains('Sirine Ben Salah'));
  });

  test('propriétaire : portefeuille en lecture seule et accueil', () async {
    final all = await properties.ownerProperties(owner);
    expect(all, hasLength(18));
    expect(all.every((p) => p.ownerId == owner), isTrue);
    // Le duplex du brouillon M4 n'appartient pas au propriétaire de démo.
    expect(all.map((p) => p.title), isNot(contains('Duplex Carthage')));

    expect(
        (await properties.ownerProperties(owner, status: PropertyStatus.rented))
            .map((p) => p.title),
        ['Duplex · Carthage']);

    // Accueil : vues cumulées des dernières annonces, agence principale.
    final stats = await properties.ownerHomeStats(owner);
    expect(stats.views, 1506);
    expect(stats.agencyName, 'Carthage Immobilier');
  });

  test('contrôle de saisie du formulaire (BF3.1)', () async {
    expect(() => properties.create(villa('lac')), throwsAdmin('title'));
    expect(() => properties.create(villa('Villa de test à Radès', price: 0)),
        throwsAdmin('price'));
    expect(() => properties.create(villa('Villa de test à Radès', surface: 0)),
        throwsAdmin('surface'));
    expect(() => properties.create(villa('Villa de test à Radès', landSurface: null)),
        throwsAdmin('landSurface'));
    expect(() => properties.create(villa('Villa de test à Radès', city: '')),
        throwsAdmin('city'));
    expect(
        () => properties.create(villa('Villa de test à Radès',
            description: 'x' * (propertyDescriptionMaxLength + 1))),
        throwsAdmin('description'));
  });

  test('créer, modifier, changer de statut puis supprimer (BF3.1, BF3.4, BF3.5)',
      () async {
    final id = await properties.create(villa('Villa de test à Radès'));
    var saved = (await properties.findById(id))!;
    expect(saved.title, 'Villa de test à Radès');
    expect(saved.status, PropertyStatus.available);
    expect(saved.landSurface, 400);
    expect(saved.agentId, sirine);
    expect(saved.mainPhotoPath, isNull);

    await properties.update(Property(
      id: id,
      agencyId: carthage,
      ownerId: owner,
      agentId: sirine,
      title: 'Villa de test rénovée à Radès',
      type: PropertyType.villa,
      dealType: DealType.sale,
      price: 820000,
      surface: 260,
      landSurface: 400,
      rooms: 5,
      city: 'Ben Arous',
      district: 'Radès',
      createdAt: saved.createdAt,
    ));
    saved = (await properties.findById(id))!;
    expect(saved.title, 'Villa de test rénovée à Radès');
    expect(saved.price, 820000);

    await properties.setStatus(id, PropertyStatus.sold);
    expect((await properties.findById(id))!.status, PropertyStatus.sold);

    await properties.delete(id);
    expect(await properties.findById(id), isNull);
  });

  test('photos : principale, réordonnancement et plafond (BF3.2)', () async {
    final id = await properties.create(villa('Villa photo · Radès'));

    await properties.addPhoto(id, 'a.jpg');
    await properties.addPhoto(id, 'b.jpg');
    var photos = await properties.photos(id);
    expect(photos, hasLength(2));
    expect(photos.first.path, 'a.jpg');
    expect(photos.first.isMain, isTrue);
    expect((await properties.findById(id))!.mainPhotoPath, 'a.jpg');

    // « Appui long pour définir comme principale ».
    await properties.setMainPhoto(id, photos[1].id!);
    photos = await properties.photos(id);
    expect(photos.firstWhere((p) => p.isMain).path, 'b.jpg');
    expect((await properties.findById(id))!.mainPhotoPath, 'b.jpg');

    // Retirer la principale promeut la première restante.
    await properties.removePhoto(id, photos[1].id!);
    photos = await properties.photos(id);
    expect(photos.single.path, 'a.jpg');
    expect(photos.single.isMain, isTrue);
    expect((await properties.findById(id))!.mainPhotoPath, 'a.jpg');

    // « Glisser pour réordonner ».
    for (var i = 0; i < 9; i++) {
      await properties.addPhoto(id, 'p$i.jpg');
    }
    photos = await properties.photos(id);
    expect(photos, hasLength(propertyPhotoMaxCount));
    await properties.reorderPhotos(id, photos.reversed.map((p) => p.id!).toList());
    expect((await properties.photos(id)).map((p) => p.path).toList(),
        photos.reversed.map((p) => p.path).toList());

    // Dix photos au maximum.
    expect(() => properties.addPhoto(id, 'trop.jpg'), throwsAdmin('photos'));
    expect(await properties.photos(id), hasLength(propertyPhotoMaxCount));
  });

  test('suppression refusée quand le bien a des visites (BF3.5)', () async {
    final row = (await db.rawQuery(
            'SELECT propertyId FROM visits GROUP BY propertyId ORDER BY COUNT(*) DESC LIMIT 1'))
        .first;
    final visited = row['propertyId'] as int;
    expect(() => properties.delete(visited), throwsAdmin('property'));
    expect(await properties.findById(visited), isNotNull);
  });
}
