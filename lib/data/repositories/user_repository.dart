import 'package:sqflite/sqflite.dart';

import '../../models/user.dart';
import '../../utils/enums.dart';
import '../database_helper.dart';

class UserRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<int> insert(User user) async =>
      (await _db).insert('users', user.toMap()..remove('id'));

  Future<User?> findById(int id) async {
    final rows = await (await _db).query('users', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : User.fromMap(rows.first);
  }

  Future<User?> findByEmail(String email) async {
    final rows = await (await _db).query(
      'users',
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
    );
    return rows.isEmpty ? null : User.fromMap(rows.first);
  }

  Future<bool> emailExists(String email) async => await findByEmail(email) != null;

  Future<List<User>> getAll({UserRole? role, int? agencyId}) async {
    final where = <String>[];
    final args = <Object>[];
    if (role != null) {
      where.add('role = ?');
      args.add(role.name);
    }
    if (agencyId != null) {
      where.add('agencyId = ?');
      args.add(agencyId);
    }
    final rows = await (await _db).query(
      'users',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'fullName',
    );
    return rows.map(User.fromMap).toList();
  }

  Future<int> update(User user) async => (await _db)
      .update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);

  Future<void> setActive(int id, bool isActive) async => (await _db).update(
      'users', {'isActive': isActive ? 1 : 0},
      where: 'id = ?', whereArgs: [id]);

  Future<void> updateLastLogin(int id) async => (await _db).update(
      'users', {'lastLoginAt': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?', whereArgs: [id]);

  Future<int> delete(int id) async =>
      (await _db).delete('users', where: 'id = ?', whereArgs: [id]);
}
