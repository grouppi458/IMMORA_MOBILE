import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:immora_mobile/core/utils/constants.dart';
import 'package:immora_mobile/core/database/demo_data.dart';
import 'package:immora_mobile/core/database/demo_data_annonces.dart';

/// Accès unique à la base locale `immo_saas.db` (patron Singleton).
/// Les Ing. 2 et 3 ajoutent leurs CREATE TABLE dans [_createStatements]
/// et leurs migrations dans [_upgrade].
class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  Future<Database>? _database;

  Future<Database> get database => _database ??= _open();

  /// Ferme la base ; le prochain accès la rouvre (et applique les migrations).
  @visibleForTesting
  Future<void> close() async {
    final db = await _database;
    _database = null;
    await db?.close();
  }

  Future<Database> _open() async {
    // Dans le navigateur, la base est rangée dans IndexedDB : un simple nom suffit.
    final path = kIsWeb ? dbName : join(await getDatabasesPath(), dbName);
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
        await DemoDataAnnonces.seed(db);
        await DemoDataAnnonces.seedMatching(db);
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
    if (oldVersion < 3) {
      // v3 (M5) : annonces et favoris (+ biens provisoires).
      for (final statement in _annoncesStatements) {
        await db.execute(statement);
      }
      await DemoDataAnnonces.seed(db);
    }
    if (oldVersion < 4) {
      // v4 (M5) : critères mémorisés et notifications (matching, alertes).
      for (final statement in _matchingStatements) {
        await db.execute(statement);
      }
      await DemoDataAnnonces.seedMatching(db);
    }
  }

  /// Module 5 (Ing. 3) — fonction avancée : critères du client (BF5.6) et
  /// notifications « nouvelle annonce pour vous » (BF5.9). La table
  /// notifications pourra aussi recevoir les rappels de visite du M6.
  static const List<String> _matchingStatements = [
    '''
    CREATE TABLE IF NOT EXISTS search_criteria (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      clientId INTEGER NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
      dealType TEXT,
      types TEXT,
      budgetMin REAL,
      budgetMax REAL,
      city TEXT,
      district TEXT,
      minRooms INTEGER,
      minSurface REAL,
      needsParking INTEGER NOT NULL DEFAULT 0,
      alertsEnabled INTEGER NOT NULL DEFAULT 1,
      updatedAt INTEGER NOT NULL
    )''',
    '''
    CREATE TABLE IF NOT EXISTS notifications (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      userId INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      type TEXT NOT NULL,
      title TEXT NOT NULL,
      body TEXT,
      listingId INTEGER REFERENCES listings(id) ON DELETE CASCADE,
      score INTEGER,
      isRead INTEGER NOT NULL DEFAULT 0,
      createdAt INTEGER NOT NULL
    )''',
    'CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(userId, isRead, createdAt)',
  ];

  /// Module 5 (Ing. 3). `IF NOT EXISTS` : la table properties sera fournie
  /// par le Module 3 (Ing. 2) ; la version ci-dessous est provisoire et ne
  /// contient que les colonnes utilisées par les annonces.
  static const List<String> _annoncesStatements = [
    // ---------- Module 3 (PROVISOIRE) : biens ----------
    '''
    CREATE TABLE IF NOT EXISTS properties (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      agencyId INTEGER NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
      ownerId INTEGER REFERENCES users(id),
      agentId INTEGER REFERENCES agents(id),
      title TEXT NOT NULL,
      type TEXT NOT NULL,
      dealType TEXT NOT NULL,
      price REAL NOT NULL,
      surface REAL NOT NULL,
      rooms INTEGER NOT NULL DEFAULT 0,
      bathrooms INTEGER NOT NULL DEFAULT 1,
      city TEXT NOT NULL,
      district TEXT,
      latitude REAL,
      longitude REAL,
      amenities TEXT,
      status TEXT NOT NULL DEFAULT 'available',
      mainPhotoPath TEXT,
      createdAt INTEGER NOT NULL
    )''',
    // ---------- Module 5 : annonces ----------
    '''
    CREATE TABLE IF NOT EXISTS listings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      propertyId INTEGER NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
      agencyId INTEGER NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
      createdBy INTEGER REFERENCES users(id) ON DELETE SET NULL,
      title TEXT NOT NULL,
      text TEXT NOT NULL,
      displayedPrice REAL NOT NULL,
      durationDays INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'draft',
      isFeatured INTEGER NOT NULL DEFAULT 0,
      viewsCount INTEGER NOT NULL DEFAULT 0,
      publishedAt INTEGER,
      expiresAt INTEGER,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL
    )''',
    // ---------- Module 5 : favoris ----------
    '''
    CREATE TABLE IF NOT EXISTS favorites (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      clientId INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      listingId INTEGER NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
      addedAt INTEGER NOT NULL,
      UNIQUE(clientId, listingId)
    )''',
    'CREATE INDEX IF NOT EXISTS idx_properties_agency ON properties(agencyId, status)',
    'CREATE INDEX IF NOT EXISTS idx_listings_status ON listings(status, expiresAt)',
    'CREATE INDEX IF NOT EXISTS idx_listings_agency ON listings(agencyId, status)',
    'CREATE INDEX IF NOT EXISTS idx_favorites_listing ON favorites(listingId)',
  ];

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
    ..._annoncesStatements,
    ..._matchingStatements,
  ];
}
