import 'package:sqflite/sqflite.dart';

import '../../models/favorite.dart';
import '../database_helper.dart';

class FavoriteRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<int> insert(Favorite favorite) async {
    return (await _db).insert('favorites', favorite.toMap()..remove('id'));
  }

  Future<List<Favorite>> findByClientId(int clientId) async {
    final rows = await (await _db).query(
      'favorites',
      where: 'clientId = ?',
      whereArgs: [clientId],
      orderBy: 'addedAt DESC',
    );

    return rows.map(Favorite.fromMap).toList();
  }

  Future<Favorite?> findByClientAndProperty(
    int clientId,
    int propertyId,
  ) async {
    final rows = await (await _db).query(
      'favorites',
      where: 'clientId = ? AND propertyId = ?',
      whereArgs: [clientId, propertyId],
      limit: 1,
    );

    return rows.isEmpty ? null : Favorite.fromMap(rows.first);
  }

  Future<int> delete(int id) async {
    return (await _db).delete('favorites', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteByClientAndProperty(int clientId, int propertyId) async {
    return (await _db).delete(
      'favorites',
      where: 'clientId = ? AND propertyId = ?',
      whereArgs: [clientId, propertyId],
    );
  }
}
