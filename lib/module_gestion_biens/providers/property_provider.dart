import 'package:flutter/foundation.dart';

import 'package:immora_mobile/core/errors/app_exception.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/module_gestion_biens/models/property.dart';
import 'package:immora_mobile/module_gestion_biens/models/property_details.dart';
import 'package:immora_mobile/module_gestion_biens/models/property_photo.dart';
import 'package:immora_mobile/module_gestion_biens/repositories/property_repository.dart';

/// État du Module 3 côté agence : les biens de l'agence connectée et leurs
/// actions (BF3.1 à BF3.5).
class PropertyProvider extends ChangeNotifier {
  PropertyProvider({PropertyRepository? properties})
      : _properties = properties ?? PropertyRepository();

  final PropertyRepository _properties;

  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;
  String? errorField; // 'title', 'price', 'surface', 'photos', 'property'…
  int? agencyId;
  int? ownerId; // mode propriétaire (espace en lecture seule)
  PropertyStatus? statusFilter;
  String query = '';
  List<Property> properties = [];
  List<Property> ownerAll = []; // mode propriétaire : liste non filtrée (accueil)
  Map<PropertyStatus, int> counts = {};

  int get totalCount => counts.values.fold(0, (sum, n) => sum + n);

  void clearError() {
    if (errorMessage == null) return;
    errorMessage = null;
    errorField = null;
    notifyListeners();
  }

  Future<void> load(int agencyId) async {
    this.agencyId = agencyId;
    ownerId = null;
    ownerAll = [];
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _refresh();
    } catch (e) {
      debugPrint('PropertyProvider.load: $e');
      errorMessage = 'Impossible de charger les biens.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Espace propriétaire : tous les biens de l'utilisateur, filtrés en local
  /// par statut (le volume reste petit).
  Future<void> loadForOwner(int ownerId) async {
    this.ownerId = ownerId;
    agencyId = null;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _refreshForOwner();
    } catch (e) {
      debugPrint('PropertyProvider.loadForOwner: $e');
      errorMessage = 'Impossible de charger vos biens.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Filtre par statut (« Tous · 146 », puces de la maquette M3).
  void setStatusFilter(PropertyStatus? status) {
    statusFilter = status;
    notifyListeners();
    if (ownerId != null) {
      _reloadOwner();
    } else {
      _reloadList();
    }
  }

  void setQuery(String value) {
    query = value;
    notifyListeners();
    _reloadList();
  }

  Future<void> _reloadList() async {
    if (agencyId == null) return;
    try {
      await _refresh();
    } catch (e) {
      debugPrint('PropertyProvider: $e');
    }
    notifyListeners();
  }

  Future<void> _reloadOwner() async {
    if (ownerId == null) return;
    try {
      await _refreshForOwner();
    } catch (e) {
      debugPrint('PropertyProvider: $e');
    }
    notifyListeners();
  }

  Future<void> _refresh() async {
    properties = await _properties.agencyProperties(agencyId!,
        status: statusFilter, query: query);
    counts = await _properties.countByStatus(agencyId!);
  }

  Future<void> _refreshForOwner() async {
    final all = await _properties.ownerProperties(ownerId!);
    counts = {};
    for (final p in all) {
      counts.update(p.status, (n) => n + 1, ifAbsent: () => 1);
    }
    ownerAll = all;
    properties = [for (final p in all) if (statusFilter == null || p.status == statusFilter) p];
  }

  Future<PropertyDetails?> details(int id) => _properties.details(id);

  Future<List<PropertyPhoto>> photos(int propertyId) => _properties.photos(propertyId);

  /// Propriétaires proposés au formulaire (« Propriétaire », maquette M3).
  Future<List<(int, String, String)>> ownerOptions() => _properties.ownerOptions();

  /// Agents proposés au formulaire (« Agent responsable »).
  Future<List<(int, String)>> agentOptions(int agencyId) =>
      _properties.agentOptions(agencyId);

  /// Accueil propriétaire : vues cumulées et agence gestionnaire.
  Future<({int views, String? agencyName})> ownerHomeStats(int ownerId) =>
      _properties.ownerHomeStats(ownerId);

  Future<bool> create(Property p) => _save(() async {
        await _properties.create(p);
      });
  Future<bool> update(Property p) => _save(() => _properties.update(p));
  Future<bool> delete(int id) => _save(() => _properties.delete(id));
  Future<bool> setStatus(int id, PropertyStatus status) =>
      _save(() => _properties.setStatus(id, status));

  Future<bool> addPhoto(int propertyId, String path) =>
      _save(() => _properties.addPhoto(propertyId, path));
  Future<bool> removePhoto(int propertyId, int photoId) =>
      _save(() => _properties.removePhoto(propertyId, photoId));
  Future<bool> setMainPhoto(int propertyId, int photoId) =>
      _save(() => _properties.setMainPhoto(propertyId, photoId));
  Future<bool> reorderPhotos(int propertyId, List<int> photoIds) =>
      _save(() => _properties.reorderPhotos(propertyId, photoIds));

  /// Exécute une action, recharge la liste, et garde l'erreur métier à afficher.
  Future<bool> _save(Future<void> Function() action) async {
    isSaving = true;
    errorMessage = null;
    errorField = null;
    notifyListeners();
    try {
      await action();
      if (agencyId != null) await _refresh();
      return true;
    } on AdminException catch (e) {
      errorMessage = e.message;
      errorField = e.field;
      return false;
    } catch (e) {
      debugPrint('PropertyProvider: $e');
      errorMessage = 'Une erreur est survenue. Réessayez.';
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
