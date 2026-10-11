import 'package:sqflite/sqflite.dart';

import 'package:immora_mobile/core/database/database_helper.dart';
import 'package:immora_mobile/core/errors/app_exception.dart';
import 'package:immora_mobile/core/utils/constants.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/module_gestion_biens/models/property.dart';
import 'package:immora_mobile/module_gestion_biens/models/property_details.dart';
import 'package:immora_mobile/module_gestion_biens/models/property_photo.dart';

/// Gestion des biens (Module 3, BF3.1 à BF3.5) : CRUD, statut, photos.
/// Les règles métier lèvent une [AdminException] affichée telle quelle.
class PropertyRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  static const _openListingStatuses = ['draft', 'published', 'suspended'];

  // ---------------------------------------------------------------- Lecture

  Future<Property?> findById(int id) async {
    final rows = await (await _db).query('properties', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Property.fromMap(rows.first);
  }

  /// BF5.1 — biens disponibles de l'agence qui n'ont pas déjà une annonce
  /// en cours (brouillon, publiée ou suspendue).
  Future<List<Property>> availableWithoutListing(int agencyId) async {
    final rows = await (await _db).rawQuery('''
      SELECT * FROM properties p
      WHERE p.agencyId = ? AND p.status = ?
        AND NOT EXISTS (
          SELECT 1 FROM listings l
          WHERE l.propertyId = p.id AND l.status IN (?, ?, ?))
      ORDER BY p.createdAt DESC''', [
      agencyId,
      PropertyStatus.available.name,
      ..._openListingStatuses,
    ]);
    return rows.map(Property.fromMap).toList();
  }

  /// BF3.1, BF3.3 — biens de l'agence, filtrés par statut et par recherche
  /// (titre, ville ou quartier).
  Future<List<Property>> agencyProperties(int agencyId,
      {PropertyStatus? status, String query = ''}) async {
    final where = StringBuffer('agencyId = ?');
    final args = <Object>[agencyId];
    if (status != null) {
      where.write(' AND status = ?');
      args.add(status.name);
    }
    if (query.trim().isNotEmpty) {
      final q = '%${query.trim()}%';
      where.write(' AND (title LIKE ? OR city LIKE ? OR district LIKE ?)');
      args.addAll([q, q, q]);
    }
    final rows = await (await _db).query('properties',
        where: where.toString(), whereArgs: args, orderBy: 'createdAt DESC');
    return rows.map(Property.fromMap).toList();
  }

  /// Nombre de biens de l'agence par statut (puces « Tous · 146 », maquette).
  Future<Map<PropertyStatus, int>> countByStatus(int agencyId) async {
    final rows = await (await _db).rawQuery(
        'SELECT status, COUNT(*) AS n FROM properties WHERE agencyId = ? GROUP BY status',
        [agencyId]);
    return {
      for (final r in rows) PropertyStatus.values.byName(r['status'] as String): r['n'] as int,
    };
  }

  /// BF3.3 — biens d'un propriétaire (espace propriétaire, lecture seule).
  Future<List<Property>> ownerProperties(int ownerId, {PropertyStatus? status}) async {
    final rows = await (await _db).query('properties',
        where: status == null ? 'ownerId = ?' : 'ownerId = ? AND status = ?',
        whereArgs: [ownerId, if (status != null) status.name],
        orderBy: 'createdAt DESC');
    return rows.map(Property.fromMap).toList();
  }

  /// Accueil propriétaire (maquette) : vues cumulées des dernières annonces
  /// de ses biens et agence qui en gère le plus (une seule en démo).
  Future<({int views, String? agencyName})> ownerHomeStats(int ownerId) async {
    final rows = await (await _db).rawQuery('''
      SELECT COALESCE(SUM((
          SELECT l.viewsCount FROM listings l
          WHERE l.propertyId = p.id ORDER BY l.createdAt DESC LIMIT 1)), 0) AS views,
        (SELECT a2.name FROM properties p2 JOIN agencies a2 ON a2.id = p2.agencyId
          WHERE p2.ownerId = ? GROUP BY a2.id
          ORDER BY COUNT(*) DESC, a2.name LIMIT 1) AS agencyName
      FROM properties p JOIN agencies a ON a.id = p.agencyId
      WHERE p.ownerId = ?''', [ownerId, ownerId]);
    final r = rows.first;
    return (views: (r['views'] as num?)?.toInt() ?? 0, agencyName: r['agencyName'] as String?);
  }

  /// BF3.6 — biens comparables pour l'estimation du prix : même ville, même
  /// type et même transaction, vendus ou disponibles (maquette « Estimation
  /// du prix »). Le bien estimé lui-même est exclu.
  Future<List<Property>> comparables(Property p) async {
    final rows = await (await _db).rawQuery('''
      SELECT * FROM properties
      WHERE city = ? AND type = ? AND dealType = ?
        AND status IN (?, ?) AND id != ? AND surface > 0
      ORDER BY createdAt DESC''', [
      p.city,
      p.type.name,
      p.dealType.name,
      PropertyStatus.sold.name,
      PropertyStatus.available.name,
      p.id ?? 0,
    ]);
    return rows.map(Property.fromMap).toList();
  }

  /// Fiche complète avec les libellés et statiques des maquettes M3.
  Future<PropertyDetails?> details(int id) async {
    final rows = await (await _db).rawQuery('''
      SELECT p.*, a.name AS agencyName, a.phone AS agencyPhone,
        u.fullName AS ownerName, u.phone AS ownerPhone,
        au.fullName AS agentName, ag.commissionRate AS agentCommissionRate,
        COALESCE((SELECT l.viewsCount FROM listings l
          WHERE l.propertyId = p.id ORDER BY l.createdAt DESC LIMIT 1), 0) AS views,
        (SELECT COUNT(*) FROM visits v WHERE v.propertyId = p.id) AS visitsCount,
        COALESCE((SELECT COUNT(*) FROM favorites f
          JOIN listings l2 ON l2.id = f.listingId
          WHERE l2.propertyId = p.id), 0) AS favoritesCount,
        (SELECT l.publishedAt FROM listings l
          WHERE l.propertyId = p.id AND l.publishedAt IS NOT NULL
          ORDER BY l.publishedAt DESC LIMIT 1) AS publishedAt,
        (SELECT l.id FROM listings l
          WHERE l.propertyId = p.id AND l.status IN (?, ?, ?)
          ORDER BY l.createdAt DESC LIMIT 1) AS listingId
      FROM properties p
      JOIN agencies a ON a.id = p.agencyId
      LEFT JOIN users u ON u.id = p.ownerId
      LEFT JOIN agents ag ON ag.id = p.agentId
      LEFT JOIN users au ON au.id = ag.userId
      WHERE p.id = ?''', [..._openListingStatuses, id]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return PropertyDetails(
      property: Property.fromMap(r),
      agencyName: (r['agencyName'] as String?) ?? '',
      agencyPhone: (r['agencyPhone'] as String?) ?? '',
      ownerName: r['ownerName'] as String?,
      ownerPhone: r['ownerPhone'] as String?,
      agentName: r['agentName'] as String?,
      agentCommissionRate: (r['agentCommissionRate'] as num?)?.toDouble(),
      views: (r['views'] as num?)?.toInt() ?? 0,
      visitsCount: (r['visitsCount'] as num?)?.toInt() ?? 0,
      favoritesCount: (r['favoritesCount'] as num?)?.toInt() ?? 0,
      publishedAt: (r['publishedAt'] as num?)?.toInt(),
      listingId: (r['listingId'] as num?)?.toInt(),
    );
  }

  /// Propriétaires proposés au formulaire (« Propriétaire », maquette M3).
  Future<List<(int, String, String)>> ownerOptions() async {
    final rows = await (await _db).query('users',
        columns: ['id', 'fullName', 'phone'],
        where: 'role = ? AND isActive = 1',
        whereArgs: [UserRole.owner.name],
        orderBy: 'fullName');
    return [
      for (final r in rows)
        (r['id'] as int, r['fullName'] as String, (r['phone'] as String?) ?? ''),
    ];
  }

  /// Agents de l'agence proposés au formulaire (« Agent responsable »).
  Future<List<(int, String)>> agentOptions(int agencyId) async {
    final rows = await (await _db).rawQuery(
        'SELECT ag.id, u.fullName FROM agents ag JOIN users u ON u.id = ag.userId '
        'WHERE ag.agencyId = ? AND u.isActive = 1 ORDER BY u.fullName',
        [agencyId]);
    return [for (final r in rows) (r['id'] as int, r['fullName'] as String)];
  }

  // ---------------------------------------------------------------- Écriture

  /// BF3.1 — création d'un bien.
  Future<int> create(Property p) async {
    _validate(p);
    final map = p.toMap()..remove('id');
    return (await _db).insert('properties', map);
  }

  /// BF3.1 — modification d'un bien.
  Future<void> update(Property p) async {
    _validate(p);
    final map = p.toMap()..remove('id');
    await (await _db).update('properties', map, where: 'id = ?', whereArgs: [p.id]);
  }

  /// BF3.5 — suppression. Refusée dès qu'un client a demandé une visite :
  /// l'historique des visites doit rester consultable (BF6.3).
  Future<void> delete(int id) async {
    final db = await _db;
    final visits = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM visits WHERE propertyId = ?', [id])) ??
        0;
    if (visits > 0) {
      throw AdminException(
          'Ce bien a des visites : il ne peut pas être supprimé.', field: 'property');
    }
    await db.delete('properties', where: 'id = ?', whereArgs: [id]);
  }

  /// BF3.4 — changement de statut (« Vendu » et « Loué » se posent aussi à la
  /// signature d'une transaction, M4). Les annonces en cours d'un bien vendu
  /// ou loué sont retirées automatiquement (BF5.4).
  Future<void> setStatus(int id, PropertyStatus status) async {
    await (await _db)
        .update('properties', {'status': status.name}, where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------- Photos (BF3.2)

  Future<List<PropertyPhoto>> photos(int propertyId) async {
    final rows = await (await _db).query('property_photos',
        where: 'propertyId = ?', whereArgs: [propertyId], orderBy: 'position, id');
    return rows.map(PropertyPhoto.fromMap).toList();
  }

  /// Ajoute une photo (10 au maximum) ; la première devient la principale.
  Future<void> addPhoto(int propertyId, String path) async {
    final db = await _db;
    final count = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM property_photos WHERE propertyId = ?', [propertyId])) ??
        0;
    if (count >= propertyPhotoMaxCount) {
      throw AdminException('$propertyPhotoMaxCount photos au maximum par bien.',
          field: 'photos');
    }
    await db.insert('property_photos', {
      'propertyId': propertyId,
      'path': path,
      'isMain': count == 0 ? 1 : 0,
      'position': count,
      'addedAt': DateTime.now().millisecondsSinceEpoch,
    });
    await _syncMainPhoto(propertyId);
  }

  /// Supprime une photo ; la principale est remplacée par la première restante.
  Future<void> removePhoto(int propertyId, int photoId) async {
    final db = await _db;
    await db.delete('property_photos',
        where: 'id = ? AND propertyId = ?', whereArgs: [photoId, propertyId]);
    final rest = await db.query('property_photos',
        columns: ['id', 'isMain'],
        where: 'propertyId = ?',
        whereArgs: [propertyId],
        orderBy: 'position, id');
    final hasMain = rest.any((r) => r['isMain'] == 1);
    final batch = db.batch();
    for (var i = 0; i < rest.length; i++) {
      batch.update('property_photos', {
        'position': i,
        if (!hasMain && i == 0) 'isMain': 1,
      }, where: 'id = ?', whereArgs: [rest[i]['id']]);
    }
    await batch.commit(noResult: true);
    await _syncMainPhoto(propertyId);
  }

  /// « Appui long pour définir comme principale » (maquette M3).
  Future<void> setMainPhoto(int propertyId, int photoId) async {
    final db = await _db;
    final batch = db.batch();
    batch.update('property_photos', {'isMain': 0},
        where: 'propertyId = ?', whereArgs: [propertyId]);
    batch.update('property_photos', {'isMain': 1},
        where: 'id = ? AND propertyId = ?', whereArgs: [photoId, propertyId]);
    await batch.commit(noResult: true);
    await _syncMainPhoto(propertyId);
  }

  /// « Glisser pour réordonner » (maquette M3) : [photoIds] dans le nouvel ordre.
  Future<void> reorderPhotos(int propertyId, List<int> photoIds) async {
    final db = await _db;
    final batch = db.batch();
    for (var i = 0; i < photoIds.length; i++) {
      batch.update('property_photos', {'position': i},
          where: 'id = ? AND propertyId = ?', whereArgs: [photoIds[i], propertyId]);
    }
    await batch.commit(noResult: true);
  }

  /// Recopie la photo principale sur `properties.mainPhotoPath` (cartes M5).
  Future<void> _syncMainPhoto(int propertyId) async {
    final db = await _db;
    final main = await db.query('property_photos',
        columns: ['path'],
        where: 'propertyId = ? AND isMain = 1',
        whereArgs: [propertyId],
        limit: 1);
    await db.update('properties', {'mainPhotoPath': main.isEmpty ? null : main.first['path']},
        where: 'id = ?', whereArgs: [propertyId]);
  }

  /// Contrôle de saisie du formulaire (BF3.1, maquette « Créer un bien »).
  void _validate(Property p) {
    final title = p.title.trim();
    if (title.length < propertyTitleMinLength || title.length > propertyTitleMaxLength) {
      throw AdminException(
          'Le titre doit faire entre $propertyTitleMinLength et $propertyTitleMaxLength caractères.',
          field: 'title');
    }
    if (p.price <= 0) {
      throw AdminException('Indiquez un prix supérieur à 0.', field: 'price');
    }
    if (p.surface <= 0) {
      throw AdminException('Indiquez une surface supérieure à 0.', field: 'surface');
    }
    if (p.requiresLandSurface && (p.landSurface ?? 0) <= 0) {
      throw AdminException('La surface du terrain est requise pour une villa.',
          field: 'landSurface');
    }
    if (p.city.trim().isEmpty) {
      throw AdminException('Indiquez la ville.', field: 'city');
    }
    if (p.description.length > propertyDescriptionMaxLength) {
      throw AdminException(
          'La description ne doit pas dépasser $propertyDescriptionMaxLength caractères.',
          field: 'description');
    }
  }
}
