import 'package:sqflite/sqflite.dart';

import '../../models/client.dart';
import '../database_helper.dart';

// Repository de l'Ingénieur 3 : version minimale pour l'inscription client.
class ClientRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<int> insert(Client client) async =>
      (await _db).insert('clients', client.toMap()..remove('id'));

  Future<Client?> findByUserId(int userId) async {
    final rows = await (await _db).query('clients', where: 'userId = ?', whereArgs: [userId]);
    return rows.isEmpty ? null : Client.fromMap(rows.first);
  }
}
