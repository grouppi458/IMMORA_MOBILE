import 'package:sqflite/sqflite.dart';

import '../../models/agency.dart';
import '../database_helper.dart';

class AgencyRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<int> insert(Agency agency) async =>
      (await _db).insert('agencies', agency.toMap()..remove('id'));

  Future<Agency?> findById(int id) async {
    final rows = await (await _db).query('agencies', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Agency.fromMap(rows.first);
  }

  Future<List<Agency>> getAll() async {
    final rows = await (await _db).query('agencies', orderBy: 'name');
    return rows.map(Agency.fromMap).toList();
  }

  Future<int> update(Agency agency) async => (await _db)
      .update('agencies', agency.toMap(), where: 'id = ?', whereArgs: [agency.id]);

  Future<void> setActive(int id, bool isActive) async => (await _db).update(
      'agencies', {'isActive': isActive ? 1 : 0},
      where: 'id = ?', whereArgs: [id]);

  Future<int> delete(int id) async =>
      (await _db).delete('agencies', where: 'id = ?', whereArgs: [id]);
}
