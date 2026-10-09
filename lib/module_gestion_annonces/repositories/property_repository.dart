import 'package:sqflite/sqflite.dart';

import 'package:immora_mobile/core/database/database_helper.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/module_gestion_annonces/models/property.dart';

/// Lecture des biens pour les annonces.
///
/// PROVISOIRE : le CRUD des biens appartient au Module 3 (Ing. 2). Le M5 n'a
/// besoin que de lire les biens d'une agence pour créer une annonce (BF5.1).
class PropertyRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<Property?> findById(int id) async {
    final rows = await (await _db).query('properties', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Property.fromMap(rows.first);
  }

  /// BF5.1 — biens disponibles de l'agence qui n'ont pas déjà une annonce
  /// en cours (brouillon, publiée ou suspendue).
  Future<List<Property>> availableWithoutListing(int agencyId) async {
    final rows = await (await _db).rawQuery('''
      SELECT * FROM properties p
      WHERE p.agencyId = ? AND p.status = ?
        AND NOT EXISTS (
          SELECT 1 FROM listings l
          WHERE l.propertyId = p.id AND l.status IN (?, ?, ?))
      ORDER BY p.createdAt DESC''', [
      agencyId,
      PropertyStatus.available.name,
      ListingStatus.draft.name,
      ListingStatus.published.name,
      ListingStatus.suspended.name,
    ]);
    return rows.map(Property.fromMap).toList();
  }
}
