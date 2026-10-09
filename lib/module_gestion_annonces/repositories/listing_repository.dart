import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'package:immora_mobile/core/database/database_helper.dart';
import 'package:immora_mobile/core/errors/app_exception.dart';
import 'package:immora_mobile/core/utils/constants.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/module_gestion_annonces/models/listing.dart';
import 'package:immora_mobile/module_gestion_annonces/models/listing_details.dart';
import 'package:immora_mobile/module_gestion_annonces/models/property.dart';
import 'package:immora_mobile/module_gestion_annonces/repositories/matching_repository.dart';

/// Gestion des annonces (Module 5, BF5.1, BF5.3 à BF5.5).
/// Les règles métier lèvent une [AdminException] affichée telle quelle.
class ListingRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  static const _day = Duration.millisecondsPerDay;

  /// Statuts d'une annonce « en cours » : un bien n'en a qu'une à la fois.
  static const _openStatuses = [
    ListingStatus.draft,
    ListingStatus.published,
    ListingStatus.suspended,
  ];

  /// Jointure annonce ⋈ bien ⋈ agence + nombre de favoris. Les colonnes du
  /// bien sont préfixées `p_` (lues par [Property.fromMap]). Réutilisée par
  /// le FavoriteRepository.
  static final String selectDetails = '''
    SELECT l.*, a.name AS agencyName, a.phone AS agencyPhone,
      (SELECT COUNT(*) FROM favorites f WHERE f.listingId = l.id) AS favoritesCount,
      (SELECT u.fullName FROM agents ag JOIN users u ON u.id = ag.userId
        WHERE ag.id = p.agentId) AS agentName,
      ${Property.columns.map((c) => 'p.$c AS p_$c').join(', ')}
    FROM listings l
    JOIN properties p ON p.id = l.propertyId
    JOIN agencies a ON a.id = l.agencyId''';

  static ListingDetails detailsFromRow(Map<String, dynamic> row) => ListingDetails(
        listing: Listing.fromMap(row),
        property: Property.fromMap(row, prefix: 'p_'),
        agencyName: row['agencyName'] ?? '',
        favoritesCount: row['favoritesCount'] ?? 0,
        agencyPhone: row['agencyPhone'] ?? '',
        agentName: row['agentName'],
      );

  // ---------------------------------------------------------------- Lecture

  /// BF5.4 — passe en « expirée » les annonces publiées dont la durée est
  /// dépassée, et en « retirée » celles dont le bien est vendu ou loué.
  /// Appelée avant chaque lecture pour que les statuts soient toujours à jour.
  Future<void> refreshStatuses() async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'listings',
      {'status': ListingStatus.expired.name, 'updatedAt': now},
      where: 'status = ? AND expiresAt IS NOT NULL AND expiresAt <= ?',
      whereArgs: [ListingStatus.published.name, now],
    );
    await db.rawUpdate('''
      UPDATE listings SET status = ?, updatedAt = ?
      WHERE status IN (?, ?, ?)
        AND propertyId IN (SELECT id FROM properties WHERE status IN (?, ?))''', [
      ListingStatus.withdrawn.name,
      now,
      ..._openStatuses.map((s) => s.name),
      PropertyStatus.sold.name,
      PropertyStatus.rented.name,
    ]);
  }

  /// BF5.3 — annonces de l'agence (toutes ou d'un statut), avec vues et favoris.
  Future<List<ListingDetails>> agencyListings(int agencyId, {ListingStatus? status}) async {
    await refreshStatuses();
    final rows = await (await _db).rawQuery(
      '$selectDetails WHERE l.agencyId = ?${status == null ? '' : ' AND l.status = ?'} '
      'ORDER BY l.updatedAt DESC',
      [agencyId, if (status != null) status.name],
    );
    return rows.map(detailsFromRow).toList();
  }

  /// BF5.3 — vitrine du client : annonces publiées des agences actives,
  /// les annonces mises en avant d'abord, puis les plus récentes.
  Future<List<ListingDetails>> publishedListings() async {
    await refreshStatuses();
    final rows = await (await _db).rawQuery(
      '$selectDetails WHERE l.status = ? AND a.isActive = 1 '
      'ORDER BY l.isFeatured DESC, l.publishedAt DESC',
      [ListingStatus.published.name],
    );
    return rows.map(detailsFromRow).toList();
  }

  Future<ListingDetails?> details(int id) async {
    await refreshStatuses();
    final rows = await (await _db).rawQuery('$selectDetails WHERE l.id = ?', [id]);
    return rows.isEmpty ? null : detailsFromRow(rows.first);
  }

  /// Nombre d'annonces de l'agence par statut (onglets de la liste).
  Future<Map<ListingStatus, int>> countByStatus(int agencyId) async {
    await refreshStatuses();
    final rows = await (await _db).rawQuery(
        'SELECT status, COUNT(*) AS n FROM listings WHERE agencyId = ? GROUP BY status',
        [agencyId]);
    return {
      for (final r in rows) ListingStatus.values.byName(r['status'] as String): r['n'] as int,
    };
  }

  /// BF5.3 — une ouverture de la fiche par un client compte une vue.
  Future<void> recordView(int id) async => (await _db)
      .rawUpdate('UPDATE listings SET viewsCount = viewsCount + 1 WHERE id = ?', [id]);

  // ---------------------------------------------------------------- Création

  /// BF5.1 — crée une annonce à partir d'un bien disponible de l'agence.
  /// Brouillon par défaut, ou publiée tout de suite si [publish].
  Future<int> create({
    required int propertyId,
    required int agencyId,
    int? createdBy,
    required String title,
    required String text,
    required double displayedPrice,
    required int durationDays,
    bool isFeatured = false,
    bool publish = false,
  }) async {
    _validate(title: title, text: text, price: displayedPrice, durationDays: durationDays);
    final db = await _db;
    final propertyRows =
        await db.query('properties', where: 'id = ?', whereArgs: [propertyId], limit: 1);
    if (propertyRows.isEmpty) throw AdminException('Bien introuvable.', field: 'property');
    final property = Property.fromMap(propertyRows.first);
    if (property.agencyId != agencyId) {
      throw AdminException('Ce bien n’appartient pas à votre agence.', field: 'property');
    }
    if (!property.isAvailable) {
      throw AdminException('Seul un bien disponible peut être publié '
          '(statut actuel : ${property.status.label}).', field: 'property');
    }
    if (await _hasOpenListing(db, propertyId)) {
      throw AdminException('Ce bien a déjà une annonce en cours.', field: 'property');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await db.insert('listings', {
      'propertyId': propertyId,
      'agencyId': agencyId,
      'createdBy': createdBy,
      'title': title.trim(),
      'text': text.trim(),
      'displayedPrice': displayedPrice,
      'durationDays': durationDays,
      'status': (publish ? ListingStatus.published : ListingStatus.draft).name,
      'isFeatured': isFeatured ? 1 : 0,
      'viewsCount': 0,
      'publishedAt': publish ? now : null,
      'expiresAt': publish ? now + durationDays * _day : null,
      'createdAt': now,
      'updatedAt': now,
    });
    if (publish) await _onFirstPublication(id);
    return id;
  }

  // ---------------------------------------------------------------- Modification

  /// BF5.4 — modifie le contenu d'une annonce (pas son statut).
  Future<void> updateContent(int id,
      {required String title, required String text, required double displayedPrice}) async {
    _validate(title: title, text: text, price: displayedPrice);
    final listing = await _get(id);
    if (listing.status == ListingStatus.withdrawn) {
      throw AdminException('Une annonce retirée ne peut plus être modifiée.');
    }
    await _save(id, {
      'title': title.trim(),
      'text': text.trim(),
      'displayedPrice': displayedPrice,
    });
  }

  /// BF5.4 — publie un brouillon, ou remet en ligne une annonce suspendue.
  Future<void> publish(int id) async {
    final listing = await _get(id);
    await _ensurePropertyAvailable(listing.propertyId);
    final now = DateTime.now().millisecondsSinceEpoch;
    switch (listing.status) {
      case ListingStatus.draft:
        await _save(id, {
          'status': ListingStatus.published.name,
          'publishedAt': now,
          'expiresAt': now + listing.durationDays * _day,
        });
        await _onFirstPublication(id);
      case ListingStatus.suspended:
        if (listing.expiresAt != null && listing.expiresAt! <= now) {
          throw AdminException('La durée de cette annonce est dépassée : prolongez-la.');
        }
        await _save(id, {'status': ListingStatus.published.name});
      default:
        throw AdminException(
            'Une annonce « ${listing.status.label} » ne peut pas être publiée.');
    }
  }

  /// BF5.4 — retire temporairement une annonce publiée de la vitrine.
  Future<void> suspend(int id) async {
    final listing = await _get(id);
    if (listing.status != ListingStatus.published) {
      throw AdminException('Seule une annonce publiée peut être suspendue.');
    }
    await _save(id, {'status': ListingStatus.suspended.name});
  }

  /// BF5.4 — prolonge de 30, 60 ou 90 jours à partir de la date d'expiration
  /// (ou d'aujourd'hui si elle est passée). Une annonce expirée est republiée.
  Future<void> extend(int id, int days) async {
    if (!listingDurations.contains(days)) {
      throw AdminException('Durée invalide : ${listingDurations.join(', ')} jours.',
          field: 'duration');
    }
    final listing = await _get(id);
    if (!const [ListingStatus.published, ListingStatus.suspended, ListingStatus.expired]
        .contains(listing.status)) {
      throw AdminException(
          'Une annonce « ${listing.status.label} » ne peut pas être prolongée.');
    }
    await _ensurePropertyAvailable(listing.propertyId);
    final now = DateTime.now().millisecondsSinceEpoch;
    final from = max(now, listing.expiresAt ?? now);
    await _save(id, {
      'durationDays': listing.durationDays + days,
      'expiresAt': from + days * _day,
      if (listing.status == ListingStatus.expired) 'status': ListingStatus.published.name,
      if (listing.publishedAt == null) 'publishedAt': now,
    });
  }

  /// BF5.4 — mise en avant (affichée en premier dans la vitrine).
  Future<void> setFeatured(int id, bool featured) async {
    final listing = await _get(id);
    if (listing.status == ListingStatus.withdrawn) {
      throw AdminException('Une annonce retirée ne peut pas être mise en avant.');
    }
    await _save(id, {'isFeatured': featured ? 1 : 0});
  }

  // ---------------------------------------------------------------- Suppression

  /// BF5.5 — supprime une annonce brouillon, expirée ou retirée. Ses favoris
  /// sont supprimés en cascade (ON DELETE CASCADE).
  Future<void> delete(int id) async {
    final listing = await _get(id);
    if (!const [ListingStatus.draft, ListingStatus.expired, ListingStatus.withdrawn]
        .contains(listing.status)) {
      throw AdminException('Seule une annonce brouillon ou expirée peut être supprimée. '
          'Suspendez-la d’abord si vous voulez la retirer de la vitrine.');
    }
    await (await _db).delete('listings', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------- Interne

  /// BF5.9 — une nouvelle annonce en ligne : alerte les clients compatibles.
  /// Une erreur d'alerte ne doit pas empêcher la publication.
  Future<void> _onFirstPublication(int id) async {
    try {
      await MatchingRepository().notifyNewListing(id);
    } catch (e) {
      debugPrint('ListingRepository: alertes non envoyées ($e)');
    }
  }

  static void _validate(
      {required String title, required String text, required double price, int? durationDays}) {
    final t = title.trim();
    if (t.length < listingTitleMinLength || t.length > listingTitleMaxLength) {
      throw AdminException(
          'Le titre doit contenir entre $listingTitleMinLength et $listingTitleMaxLength caractères.',
          field: 'title');
    }
    if (text.trim().length < 20) {
      throw AdminException('Le texte de l’annonce doit contenir au moins 20 caractères.',
          field: 'text');
    }
    if (price <= 0) {
      throw AdminException('Le prix affiché doit être supérieur à 0.', field: 'price');
    }
    if (durationDays != null && !listingDurations.contains(durationDays)) {
      throw AdminException('Durée invalide : ${listingDurations.join(', ')} jours.',
          field: 'duration');
    }
  }

  Future<Listing> _get(int id) async {
    await refreshStatuses();
    final rows = await (await _db).query('listings', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) throw AdminException('Annonce introuvable.');
    return Listing.fromMap(rows.first);
  }

  Future<void> _save(int id, Map<String, Object?> values) async => (await _db).update(
      'listings', {...values, 'updatedAt': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?', whereArgs: [id]);

  Future<bool> _hasOpenListing(DatabaseExecutor db, int propertyId) async =>
      (Sqflite.firstIntValue(await db.rawQuery(
              'SELECT COUNT(*) FROM listings WHERE propertyId = ? AND status IN (?, ?, ?)',
              [propertyId, ..._openStatuses.map((s) => s.name)])) ??
          0) >
      0;

  Future<void> _ensurePropertyAvailable(int propertyId) async {
    final rows = await (await _db)
        .query('properties', columns: ['status'], where: 'id = ?', whereArgs: [propertyId]);
    if (rows.isEmpty || rows.first['status'] != PropertyStatus.available.name) {
      throw AdminException('Le bien n’est plus disponible.');
    }
  }
}
