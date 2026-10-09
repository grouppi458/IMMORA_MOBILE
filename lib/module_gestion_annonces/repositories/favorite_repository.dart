import 'package:sqflite/sqflite.dart';

import 'package:immora_mobile/core/database/database_helper.dart';
import 'package:immora_mobile/core/errors/app_exception.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/module_gestion_annonces/models/listing_details.dart';
import 'package:immora_mobile/module_gestion_annonces/repositories/listing_repository.dart';

/// Favoris des clients sur les annonces (Module 5, BF5.2 et BF5.5).
class FavoriteRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  /// BF5.2 — ajoute une annonce publiée aux favoris. Une même annonce ne
  /// compte qu'une fois : renvoie false si elle y était déjà.
  Future<bool> add(int clientId, int listingId) async {
    final db = await _db;
    final rows = await db.query('listings',
        columns: ['status'], where: 'id = ?', whereArgs: [listingId], limit: 1);
    if (rows.isEmpty) throw AdminException('Annonce introuvable.');
    if (rows.first['status'] != ListingStatus.published.name) {
      throw AdminException('Cette annonce n’est plus en ligne.');
    }
    if (await isFavorite(clientId, listingId)) return false;
    await db.insert('favorites', {
      'clientId': clientId,
      'listingId': listingId,
      'addedAt': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    return true;
  }

  /// BF5.5 — retire une annonce des favoris.
  Future<void> remove(int clientId, int listingId) async => (await _db).delete('favorites',
      where: 'clientId = ? AND listingId = ?', whereArgs: [clientId, listingId]);

  Future<bool> isFavorite(int clientId, int listingId) async =>
      (Sqflite.firstIntValue(await (await _db).rawQuery(
              'SELECT COUNT(*) FROM favorites WHERE clientId = ? AND listingId = ?',
              [clientId, listingId])) ??
          0) >
      0;

  /// Identifiants des annonces favorites (pour afficher le cœur dans la vitrine).
  Future<Set<int>> listingIds(int clientId) async {
    final rows = await (await _db).query('favorites',
        columns: ['listingId'], where: 'clientId = ?', whereArgs: [clientId]);
    return rows.map((r) => r['listingId'] as int).toSet();
  }

  /// Favoris du client, les plus récents d'abord. Les annonces qui ne sont
  /// plus publiées restent visibles (avec leur statut) jusqu'à ce qu'il les retire.
  Future<List<ListingDetails>> clientFavorites(int clientId) async {
    await ListingRepository().refreshStatuses();
    final rows = await (await _db).rawQuery(
      '${ListingRepository.selectDetails} '
      'JOIN favorites fav ON fav.listingId = l.id '
      'WHERE fav.clientId = ? ORDER BY fav.addedAt DESC',
      [clientId],
    );
    return rows.map(ListingRepository.detailsFromRow).toList();
  }
}
