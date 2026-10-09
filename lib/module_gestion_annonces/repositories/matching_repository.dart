import 'package:sqflite/sqflite.dart';

import 'package:immora_mobile/core/database/database_helper.dart';
import 'package:immora_mobile/core/database/db_inspector.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/module_gestion_annonces/matching/matching_engine.dart';
import 'package:immora_mobile/module_gestion_annonces/models/app_notification.dart';
import 'package:immora_mobile/module_gestion_annonces/models/listing_details.dart';
import 'package:immora_mobile/module_gestion_annonces/models/search_criteria.dart';
import 'package:immora_mobile/module_gestion_annonces/repositories/favorite_repository.dart';
import 'package:immora_mobile/module_gestion_annonces/repositories/listing_repository.dart';

/// Données de la fonction avancée du Module 5 : critères mémorisés (BF5.6),
/// biens déjà visités (BF5.8) et alertes « nouvelle annonce pour vous » (BF5.9).
class MatchingRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  // ---------------------------------------------------------------- Critères

  Future<SearchCriteria?> criteria(int clientId) async {
    final rows = await (await _db)
        .query('search_criteria', where: 'clientId = ?', whereArgs: [clientId], limit: 1);
    return rows.isEmpty ? null : SearchCriteria.fromMap(rows.first);
  }

  /// BF5.6 — mémorise les critères du client (une ligne par client).
  Future<void> saveCriteria(int clientId, SearchCriteria c) async => (await _db).insert(
      'search_criteria', c.toMap(clientId),
      conflictAlgorithm: ConflictAlgorithm.replace);

  // ---------------------------------------------------------------- Visites (M6)

  /// BF5.8 — biens que le client a déjà visités : exclus de « Pour vous ».
  /// La table visits appartient au Module 6 ; vide tant qu'elle n'existe pas.
  Future<Set<int>> visitedPropertyIds(int clientId) async {
    final db = await _db;
    if (!await DbInspector.hasColumn(db, 'visits', 'propertyId')) return {};
    final hasStatus = await DbInspector.hasColumn(db, 'visits', 'status');
    final rows = await db.rawQuery(
      'SELECT DISTINCT propertyId FROM visits WHERE clientId = ?'
      '${hasStatus ? " AND status = 'done'" : ''}',
      [clientId],
    );
    return rows.map((r) => r['propertyId'] as int).toSet();
  }

  // ---------------------------------------------------------------- Notifications

  Future<List<AppNotification>> notifications(int userId) async {
    final rows = await (await _db).query('notifications',
        where: 'userId = ?', whereArgs: [userId], orderBy: 'createdAt DESC', limit: 100);
    return rows.map(AppNotification.fromMap).toList();
  }

  Future<void> markRead(int notificationId) async => (await _db).update(
      'notifications', {'isRead': 1},
      where: 'id = ?', whereArgs: [notificationId]);

  Future<void> markAllRead(int userId) async => (await _db).update(
      'notifications', {'isRead': 1},
      where: 'userId = ? AND isRead = 0', whereArgs: [userId]);

  /// BF5.9 — à la publication d'une nouvelle annonce, notifie chaque client
  /// (alertes activées) dont le score est ≥ 80. Le profil est celui de ses
  /// critères, ou à défaut celui déduit de ses favoris. Renvoie le nombre de
  /// clients notifiés.
  Future<int> notifyNewListing(int listingId) async {
    final db = await _db;
    final listing = await ListingRepository().details(listingId);
    if (listing == null || listing.listing.status != ListingStatus.published) return 0;

    final clients = await db.query('users',
        columns: ['id'],
        where: 'role = ? AND isActive = 1',
        whereArgs: [UserRole.client.name]);
    var notified = 0;
    for (final row in clients) {
      final clientId = row['id'] as int;
      final profile = await _profile(clientId);
      if (profile == null || !profile.alertsEnabled) continue;
      final match = MatchingEngine.scoreListing(listing, profile);
      if (match.excluded || match.score < MatchingEngine.alertScore) continue;
      if (await _alreadyNotified(db, clientId, listingId)) continue;
      await db.insert('notifications', newListingNotification(clientId, listing, match.score));
      notified++;
    }
    return notified;
  }

  /// Ligne `notifications` d'une alerte « nouvelle annonce pour vous ».
  static Map<String, dynamic> newListingNotification(
          int clientId, ListingDetails d, int score, {int? at}) =>
      AppNotification(
        userId: clientId,
        type: AppNotification.newListing,
        title: 'Nouvelle annonce pour vous',
        body: '${d.listing.title} · ${d.property.district.isEmpty ? d.property.city : d.property.district}'
            ' · $score % compatible',
        listingId: d.listing.id,
        score: score,
        createdAt: at ?? DateTime.now().millisecondsSinceEpoch,
      ).toMap()
        ..remove('id');

  /// Critères enregistrés, sinon profil déduit des favoris (BF5.8).
  Future<SearchCriteria?> _profile(int clientId) async {
    final saved = await criteria(clientId);
    if (saved != null && !saved.isEmpty) return saved;
    final fromFavorites =
        MatchingEngine.profileFromFavorites(await FavoriteRepository().clientFavorites(clientId));
    if (fromFavorites == null) return null;
    return fromFavorites.copyWith(alertsEnabled: saved?.alertsEnabled ?? true);
  }

  static Future<bool> _alreadyNotified(DatabaseExecutor db, int clientId, int listingId) async =>
      (Sqflite.firstIntValue(await db.rawQuery(
              'SELECT COUNT(*) FROM notifications WHERE userId = ? AND listingId = ? AND type = ?',
              [clientId, listingId, AppNotification.newListing])) ??
          0) >
      0;
}
