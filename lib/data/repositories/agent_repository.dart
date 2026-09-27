import 'package:sqflite/sqflite.dart';

import '../../models/agent.dart';
import '../database_helper.dart';

class AgentRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<int> insert(Agent agent) async =>
      (await _db).insert('agents', agent.toMap()..remove('id'));

  Future<Agent?> findByUserId(int userId) async {
    final rows = await (await _db).query('agents', where: 'userId = ?', whereArgs: [userId]);
    return rows.isEmpty ? null : Agent.fromMap(rows.first);
  }

  /// Liste des agents d'une agence (menus déroulants des Ing. 2 et 3).
  Future<List<Agent>> getAgentsByAgency(int agencyId) async {
    final rows = await (await _db).query('agents', where: 'agencyId = ?', whereArgs: [agencyId]);
    return rows.map(Agent.fromMap).toList();
  }

  Future<int> countByAgency(int agencyId) async => Sqflite.firstIntValue(await (await _db)
          .rawQuery('SELECT COUNT(*) FROM agents WHERE agencyId = ?', [agencyId])) ??
      0;

  Future<int> update(Agent agent) async => (await _db)
      .update('agents', agent.toMap(), where: 'id = ?', whereArgs: [agent.id]);

  Future<int> delete(int id) async =>
      (await _db).delete('agents', where: 'id = ?', whereArgs: [id]);
}
