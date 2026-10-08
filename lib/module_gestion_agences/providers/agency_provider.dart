import 'package:flutter/foundation.dart';

import 'package:immora_mobile/core/errors/app_exception.dart';
import 'package:immora_mobile/module_gestion_agences/repositories/agency_admin_repository.dart';
import 'package:immora_mobile/module_gestion_agences/models/agency_views.dart';
import 'package:immora_mobile/module_gestion_agences/models/agency.dart';
import 'package:immora_mobile/core/utils/enums.dart';

/// État du Module 2 : agences, abonnements, tableau de bord et score d'activité.
class AgencyProvider extends ChangeNotifier {
  AgencyProvider({AgencyAdminRepository? repository})
      : _repo = repository ?? AgencyAdminRepository();

  final AgencyAdminRepository _repo;

  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;
  String? errorField;
  List<AgencySummary> agencies = [];
  DashboardStats? stats;

  AgencySummary? agencyById(int id) =>
      agencies.where((a) => a.agency.id == id).firstOrNull;

  List<AgencySummary> get lowActivityAgencies =>
      agencies.where((a) => a.activity.isLow).toList()
        ..sort((a, b) => a.activity.score.compareTo(b.activity.score));

  void clearError() {
    if (errorMessage == null) return;
    errorMessage = null;
    errorField = null;
    notifyListeners();
  }

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      agencies = await _repo.agencySummaries();
      stats = await _repo.dashboard(agencies);
    } catch (e) {
      debugPrint('AgencyProvider.load: $e');
      errorMessage = 'Impossible de charger les données.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Les actions renvoient le mot de passe temporaire (création), '' (succès
  // sans mot de passe) ou null (échec : voir errorMessage / errorField).

  Future<String?> createAgency({
    required String name,
    required String email,
    required String phone,
    required String city,
    required String address,
    required SubscriptionPlan plan,
    String? logoPath,
  }) =>
      _save(() => _repo.createAgency(
            name: name, email: email, phone: phone, city: city,
            address: address, plan: plan, logoPath: logoPath,
          ));

  Future<String?> updateAgency(Agency agency) =>
      _save(() async {
        await _repo.updateAgency(agency);
        return '';
      });

  Future<String?> setAgencyActive(int agencyId, bool isActive) =>
      _save(() async {
        await _repo.setAgencyActive(agencyId, isActive);
        return '';
      });

  Future<String?> changePlan(int agencyId, SubscriptionPlan plan) =>
      _save(() async {
        await _repo.changePlan(agencyId, plan);
        return '';
      });

  Future<String?> renew(int agencyId, SubscriptionPlan plan) =>
      _save(() async {
        await _repo.renew(agencyId, plan);
        return '';
      });

  /// BF2.5 — suppression définitive (refusée si l'agence a des données liées).
  Future<String?> deleteAgency(int agencyId) =>
      _save(() async {
        await _repo.deleteAgency(agencyId);
        return '';
      });

  /// Résumé d'une agence, pour l'espace agence (sans charger les autres agences).
  Future<AgencySummary?> agencySummary(int agencyId) => _repo.agencySummary(agencyId);

  /// Exécute une action, gère l'erreur puis recharge les données.
  Future<String?> _save(Future<String> Function() action) async {
    isSaving = true;
    errorMessage = null;
    errorField = null;
    notifyListeners();
    try {
      final result = await action();
      await load();
      return result;
    } on AdminException catch (e) {
      errorMessage = e.message;
      errorField = e.field;
      return null;
    } catch (e) {
      debugPrint('AgencyProvider: $e');
      errorMessage = 'Une erreur est survenue. Réessayez.';
      return null;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
