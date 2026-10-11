import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:immora_mobile/core/utils/constants.dart';
import 'package:immora_mobile/core/database/demo_data.dart';
import 'package:immora_mobile/core/database/demo_data_annonces.dart';
import 'package:immora_mobile/core/database/demo_data_biens.dart';
import 'package:immora_mobile/core/database/demo_data_transactions.dart';
import 'package:immora_mobile/core/database/demo_data_visits.dart';

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
        await DemoDataVisits.seed(db);
        await _backfillPropertyColumns(db);
        await DemoDataBiens.seed(db);
        await DemoDataTransactions.seed(db);
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
    if (oldVersion < 5) {
      // v5 (M6) : demandes de visite. Les colonnes de notation (v6) sont
      // vérifiées avant la démo : une base v4 reçoit la table complète.
      for (final statement in _visitsStatements) {
        await db.execute(statement);
      }
      await _ensureVisitRatingColumns(db);
      await DemoDataVisits.seed(db);
    }
    if (oldVersion < 6) {
      // v6 (M6) : notation du client et note de l'agent (maquettes Figma).
      // Idempotent : les CREATE du v5 incluent déjà ces colonnes.
      await _ensureVisitRatingColumns(db);
    }
    if (oldVersion < 7) {
      // v7 (M3) : champs du bien (état, étage, surface terrain, adresse,
      // description) et photos (BF3.1, BF3.2). Idempotent : le CREATE du v3
      // inclut déjà les nouvelles colonnes.
      await _ensurePropertyColumns(db);
      for (final statement in _biensStatements) {
        await db.execute(statement);
      }
      await _backfillPropertyColumns(db);
      await DemoDataBiens.seed(db);
    }
    if (oldVersion < 8) {
      // v8 (M4) : transactions, paiements et alertes d'anomalie.
      for (final statement in _transactionsStatements) {
        await db.execute(statement);
      }
      await DemoDataTransactions.seed(db);
    }
  }

  /// Ajoute à `properties` les colonnes du M3 si la table existe sans elles
  /// (bases créées par le M5 en v3–v6).
  static Future<void> _ensurePropertyColumns(Database db) async {
    final existing = (await db.rawQuery('PRAGMA table_info(properties)'))
        .map((row) => row['name'] as String)
        .toSet();
    for (final (name, ddl) in [
      ('condition', "TEXT NOT NULL DEFAULT 'good'"),
      ('floor', 'INTEGER'),
      ('landSurface', 'REAL'),
      ('description', 'TEXT'),
      ('address', 'TEXT'),
    ]) {
      if (!existing.contains(name)) {
        await db.execute('ALTER TABLE properties ADD COLUMN $name $ddl');
      }
    }
  }

  /// Complète les biens existants : description reprise de l'annonce liée et
  /// adresse « quartier, ville » — les maquettes M3 affichent ces champs.
  static Future<void> _backfillPropertyColumns(Database db) async {
    await db.execute('''
      UPDATE properties SET description = (
        SELECT l.text FROM listings l WHERE l.propertyId = properties.id
        ORDER BY l.createdAt LIMIT 1)
      WHERE description IS NULL''');
    await db.execute('''
      UPDATE properties SET address =
        CASE WHEN district IS NULL OR district = '' THEN city
             ELSE district || ', ' || city END
      WHERE address IS NULL''');
  }

  /// Ajoute à `visits` les colonnes de notation apparues en v6, si la table
  /// existe sans elles (base créée avant).
  static Future<void> _ensureVisitRatingColumns(Database db) async {
    final existing = (await db.rawQuery('PRAGMA table_info(visits)'))
        .map((row) => row['name'] as String)
        .toSet();
    for (final (name, type) in [
      ('rating', 'INTEGER'),
      ('ratingComment', 'TEXT'),
      ('agentNote', 'TEXT'),
    ]) {
      if (!existing.contains(name)) {
        await db.execute('ALTER TABLE visits ADD COLUMN $name $type');
      }
    }
  }

  /// Module 6 (Ing. 3) — visites : une demande porte sur le bien (propertyId,
  /// lu par le « Pour vous » du M5) via l'annonce (listingId, peut disparaître).
  /// Colonnes attendues ailleurs : clientId et agentId (Module 1, suppression
  /// d'un compte), status 'done' et scheduledAt (performance des agents).
  static const List<String> _visitsStatements = [
    '''
    CREATE TABLE IF NOT EXISTS visits (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      propertyId INTEGER NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
      listingId INTEGER REFERENCES listings(id) ON DELETE SET NULL,
      agencyId INTEGER NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
      clientId INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      agentId INTEGER REFERENCES agents(id) ON DELETE SET NULL,
      status TEXT NOT NULL DEFAULT 'requested',
      scheduledAt INTEGER NOT NULL,
      clientNote TEXT,
      decidedAt INTEGER,
      doneAt INTEGER,
      cancelReason TEXT,
      rating INTEGER,
      ratingComment TEXT,
      agentNote TEXT,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL
    )''',
    'CREATE INDEX IF NOT EXISTS idx_visits_client ON visits(clientId, status, scheduledAt)',
    'CREATE INDEX IF NOT EXISTS idx_visits_agency ON visits(agencyId, status, scheduledAt)',
    'CREATE INDEX IF NOT EXISTS idx_visits_agent ON visits(agentId, status)',
    'CREATE INDEX IF NOT EXISTS idx_visits_property ON visits(propertyId)',
  ];

  /// Module 4 (Ing. 2) — ventes : transactions (référence affichée « #1042 »),
  /// paiements échelonnés (le statut — payé / en retard / en attente — se
  /// déduit des dates) et alertes d'anomalie ([AnomalyDetector], seuils dans
  /// `constants.dart`).
  static const List<String> _transactionsStatements = [
    '''
    CREATE TABLE IF NOT EXISTS transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      agencyId INTEGER NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
      ref INTEGER NOT NULL,
      propertyId INTEGER NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
      clientId INTEGER REFERENCES users(id) ON DELETE SET NULL,
      clientName TEXT NOT NULL,
      agentId INTEGER REFERENCES agents(id) ON DELETE SET NULL,
      dealType TEXT NOT NULL,
      amount REAL NOT NULL,
      commissionRate REAL NOT NULL,
      commissionAmount REAL NOT NULL,
      status TEXT NOT NULL DEFAULT 'draft',
      startDate INTEGER NOT NULL,
      signedAt INTEGER,
      endDate INTEGER,
      cancelReason TEXT,
      contractPath TEXT,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL,
      UNIQUE(agencyId, ref)
    )''',
    '''
    CREATE TABLE IF NOT EXISTS payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      transactionId INTEGER NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
      label TEXT NOT NULL,
      amount REAL NOT NULL,
      dueDate INTEGER NOT NULL,
      paidDate INTEGER,
      method TEXT,
      createdAt INTEGER NOT NULL
    )''',
    '''
    CREATE TABLE IF NOT EXISTS alerts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      agencyId INTEGER NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
      type TEXT NOT NULL,
      severity TEXT NOT NULL,
      title TEXT NOT NULL,
      subtitle TEXT,
      description TEXT NOT NULL,
      details TEXT,
      transactionId INTEGER REFERENCES transactions(id) ON DELETE CASCADE,
      paymentId INTEGER REFERENCES payments(id) ON DELETE CASCADE,
      isRead INTEGER NOT NULL DEFAULT 0,
      createdAt INTEGER NOT NULL
    )''',
    'CREATE INDEX IF NOT EXISTS idx_transactions_agency ON transactions(agencyId, status, createdAt)',
    'CREATE INDEX IF NOT EXISTS idx_transactions_property ON transactions(propertyId)',
    'CREATE INDEX IF NOT EXISTS idx_payments_transaction ON payments(transactionId, dueDate)',
    'CREATE INDEX IF NOT EXISTS idx_payments_paid ON payments(paidDate)',
    'CREATE INDEX IF NOT EXISTS idx_alerts_agency ON alerts(agencyId, isRead, createdAt)',
  ];

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

  /// Module 3 (Ing. 2) — biens : photos du bien (BF3.2). La table properties
  /// elle-même est créée ici depuis la v3 (les annonces du M5 en dépendent) ;
  /// ses colonnes M3 (état, étage, surface terrain, adresse, description) sont
  /// incluses dans le CREATE et vérifiées par [_ensurePropertyColumns].
  static const List<String> _biensStatements = [
    '''
    CREATE TABLE IF NOT EXISTS property_photos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      propertyId INTEGER NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
      path TEXT NOT NULL,
      isMain INTEGER NOT NULL DEFAULT 0,
      position INTEGER NOT NULL DEFAULT 0,
      addedAt INTEGER NOT NULL
    )''',
    'CREATE INDEX IF NOT EXISTS idx_property_photos_property ON property_photos(propertyId, position)',
    'CREATE INDEX IF NOT EXISTS idx_properties_owner ON properties(ownerId, status)',
  ];

  /// Module 5 (Ing. 3). Le CREATE de properties couvre désormais le M3
  /// (Ing. 2) ; les annonces n'utilisent qu'une partie de ces colonnes.
  static const List<String> _annoncesStatements = [
    // ---------- Module 3 : biens ----------
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
      landSurface REAL,
      rooms INTEGER NOT NULL DEFAULT 0,
      bathrooms INTEGER NOT NULL DEFAULT 1,
      floor INTEGER,
      city TEXT NOT NULL,
      district TEXT,
      address TEXT,
      latitude REAL,
      longitude REAL,
      amenities TEXT,
      condition TEXT NOT NULL DEFAULT 'good',
      description TEXT,
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
    ..._visitsStatements,
    ..._biensStatements,
    ..._transactionsStatements,
  ];
}
