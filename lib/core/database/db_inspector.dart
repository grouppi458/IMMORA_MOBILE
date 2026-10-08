import 'package:sqflite/sqflite.dart';

/// Petites requêtes sur le schéma SQLite. Les tables des Ing. 2 et 3
/// (properties, visits, transactions…) n'existent pas encore toujours :
/// on vérifie leur présence avant de les interroger.
class DbInspector {
  DbInspector._();

  static Future<bool> tableExists(DatabaseExecutor db, String table) async =>
      (Sqflite.firstIntValue(await db.rawQuery(
            "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = ?",
            [table],
          )) ??
          0) >
      0;

  static Future<bool> hasColumn(DatabaseExecutor db, String table, String column) async {
    if (!await tableExists(db, table)) return false;
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    return columns.any((c) => c['name'] == column);
  }

  /// Nombre de lignes de [table] où [column] = [value] (0 si la table ou la colonne manque).
  static Future<int> countWhere(
      DatabaseExecutor db, String table, String column, Object value) async {
    if (!await hasColumn(db, table, column)) return 0;
    return Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM $table WHERE $column = ?', [value])) ??
        0;
  }
}
