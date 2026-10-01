import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/constants.dart';
import 'demo_data.dart';

/// Accès unique à la base locale `immo_saas.db`.
/// Les Ing. 2 et 3 ajoutent leurs CREATE TABLE dans [_createStatements].
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
    );
  }

  static const List<String> _createStatements = [
    // ---------- Ingénieur 1 ----------
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
      lastLoginAt INTEGER
    )''',
    '''
    CREATE TABLE agents (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      userId INTEGER NOT NULL REFERENCES users(id),
      agencyId INTEGER NOT NULL REFERENCES agencies(id),
      speciality TEXT,
      commissionRate REAL NOT NULL,
      hireDate INTEGER
    )''',
    '''
    CREATE TABLE subscriptions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      agencyId INTEGER NOT NULL REFERENCES agencies(id),
      plan TEXT NOT NULL,
      monthlyPrice REAL NOT NULL,
      maxProperties INTEGER,
      maxAgents INTEGER,
      startDate INTEGER NOT NULL,
      endDate INTEGER NOT NULL,
      status TEXT NOT NULL
    )''',
    '''
    CREATE TABLE activity_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      userId INTEGER NOT NULL REFERENCES users(id),
      agencyId INTEGER REFERENCES agencies(id),
      type TEXT NOT NULL,
      details TEXT,
      timestamp INTEGER NOT NULL
    )''',
    'CREATE INDEX idx_logs_agency_type ON activity_logs(agencyId, type, timestamp)',

    // ---------- Ingénieur 3 (nécessaire à l'inscription client) ----------
    '''
    CREATE TABLE clients (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      userId INTEGER NOT NULL REFERENCES users(id),
      agencyId INTEGER REFERENCES agencies(id),
      agentId INTEGER REFERENCES agents(id),
      fullName TEXT NOT NULL,
      phone TEXT,
      email TEXT,
      wantedListingType TEXT,
      wantedType TEXT,
      budgetMin REAL,
      budgetMax REAL,
      preferredCity TEXT,
      preferredDistrict TEXT,
      minRooms INTEGER,
      minSurface REAL,
      needsParking INTEGER DEFAULT 0,
      createdAt INTEGER NOT NULL
    )''',

    '''
CREATE TABLE favorites (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  clientId INTEGER NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  propertyId INTEGER NOT NULL,
  addedAt INTEGER NOT NULL,
  UNIQUE(clientId, propertyId)
)''',

    '''
CREATE TABLE visits (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  agencyId INTEGER NOT NULL REFERENCES agencies(id),
  propertyId INTEGER NOT NULL,
  clientId INTEGER NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  agentId INTEGER REFERENCES agents(id),
  scheduledAt INTEGER NOT NULL,
  durationMinutes INTEGER NOT NULL DEFAULT 30,
  status TEXT NOT NULL DEFAULT 'requested',
  clientMessage TEXT,
  agentNote TEXT,
  clientRating INTEGER,
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL
)''',
  ];
}
