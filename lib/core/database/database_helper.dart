import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:immora_mobile/core/utils/constants.dart';
import 'package:immora_mobile/core/database/demo_data.dart';

/// Accès unique à la base locale `immo_saas.db` (patron Singleton).
/// Les Ing. 2 et 3 ajoutent leurs CREATE TABLE dans [_createStatements]
/// et leurs migrations dans [_upgrade].
class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  Future<Database>? _database;

  Future<Database> get database => _database ??= _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), dbName);
    return openDatabase(
      path,
      version: dbVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        final batch = db.batch();
        for (final statement in _createStatements) {
          batch.execute(statement);
        }
        await batch.commit(noResult: true);
        await DemoData.seed(db);
      },
      onUpgrade: _upgrade,
    );
  }

  /// Migrations pour les téléphones qui ont déjà une ancienne base.
  static Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v2 (M1) : profil propriétaire dans users + suppression de la table clients
      // (client et propriétaire sont des rôles de la table users).
      await db.execute('ALTER TABLE users ADD COLUMN cin TEXT');
      await db.execute('ALTER TABLE users ADD COLUMN address TEXT');
      await db.execute('DROP TABLE IF EXISTS clients');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_users_role ON users(role, agencyId)');
    }
  }

  static const List<String> _createStatements = [
    // ---------- Module 2 : agences ----------
    '''
    CREATE TABLE agencies (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      email TEXT NOT NULL,
      phone TEXT,
      address TEXT,
      city TEXT,
      logoPath TEXT,
      isActive INTEGER NOT NULL DEFAULT 1,
      createdAt INTEGER NOT NULL
    )''',
    // ---------- Module 1 : utilisateurs (tous les rôles) ----------
    '''
    CREATE TABLE users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      agencyId INTEGER REFERENCES agencies(id),
      fullName TEXT NOT NULL,
      email TEXT NOT NULL UNIQUE,
      phone TEXT,
      passwordHash TEXT NOT NULL,
      passwordSalt TEXT NOT NULL,
      role TEXT NOT NULL,
      isActive INTEGER NOT NULL DEFAULT 1,
      createdAt INTEGER NOT NULL,
      lastLoginAt INTEGER,
      cin TEXT,
      address TEXT
    )''',
    '''
    CREATE TABLE agents (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      userId INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      agencyId INTEGER NOT NULL REFERENCES agencies(id),
      speciality TEXT,
      commissionRate REAL NOT NULL,
      hireDate INTEGER
    )''',
    // ---------- Module 2 : abonnements ----------
    '''
    CREATE TABLE subscriptions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      agencyId INTEGER NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
      plan TEXT NOT NULL,
      monthlyPrice REAL NOT NULL,
      maxProperties INTEGER,
      maxAgents INTEGER,
      startDate INTEGER NOT NULL,
      endDate INTEGER NOT NULL,
      status TEXT NOT NULL
    )''',
    // ---------- Module 1 : journal d'activité (lu par le score du M2) ----------
    '''
    CREATE TABLE activity_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      userId INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      agencyId INTEGER REFERENCES agencies(id),
      type TEXT NOT NULL,
      details TEXT,
      timestamp INTEGER NOT NULL
    )''',
    'CREATE INDEX idx_logs_agency_type ON activity_logs(agencyId, type, timestamp)',
    'CREATE INDEX idx_users_role ON users(role, agencyId)',
  ];
}
