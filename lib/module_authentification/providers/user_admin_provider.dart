import 'package:flutter/foundation.dart';

import 'package:immora_mobile/core/errors/app_exception.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/module_authentification/models/agent_performance.dart';
import 'package:immora_mobile/module_authentification/models/agent_with_user.dart';
import 'package:immora_mobile/module_authentification/models/user.dart';
import 'package:immora_mobile/module_authentification/repositories/agent_performance_repository.dart';
import 'package:immora_mobile/module_authentification/repositories/user_admin_repository.dart';

/// État de la gestion des utilisateurs (Module 1) : comptes, agents,
/// suppression et tableau de performance des agents.
class UserAdminProvider extends ChangeNotifier {
  UserAdminProvider({
    UserAdminRepository? repository,
    AgentPerformanceRepository? performanceRepository,
    this.onDataChanged,
  })  : _repo = repository ?? UserAdminRepository(),
        _performance = performanceRepository ?? AgentPerformanceRepository();

  final UserAdminRepository _repo;
  final AgentPerformanceRepository _performance;

  /// Appelé après chaque modification réussie : le Module 2 recharge ses
  /// compteurs (agents actifs, comptes par rôle…).
  final Future<void> Function()? onDataChanged;

  bool isSaving = false;
  String? errorMessage;
  String? errorField;

  void clearError() {
    if (errorMessage == null) return;
    errorMessage = null;
    errorField = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------- Lecture

  Future<List<User>> users({UserRole? role, int? agencyId}) =>
      _repo.users(role: role, agencyId: agencyId);

  Future<List<AgentWithUser>> agentsOfAgency(int agencyId) => _repo.agentsOfAgency(agencyId);

  Future<List<AgentPerformance>> agentRanking({int? agencyId, required PerformancePeriod period}) =>
      _performance.ranking(agencyId: agencyId, since: period.since);

  // ---------------------------------------------------------------- Actions
  // Les actions renvoient le mot de passe temporaire (création), '' (succès
  // sans mot de passe) ou null (échec : voir errorMessage / errorField).

  Future<String?> saveUser({
    User? existing,
    required String fullName,
    required String email,
    required String phone,
    required UserRole role,
    int? agencyId,
    String? cin,
    String? address,
    required bool isActive,
  }) =>
      _save(() async =>
          await _repo.saveUser(
            existing: existing, fullName: fullName, email: email, phone: phone,
            role: role, agencyId: agencyId, cin: cin, address: address,
            isActive: isActive,
          ) ??
          '');

  Future<String?> saveAgent({
    AgentWithUser? existing,
    required int agencyId,
    required String fullName,
    required String email,
    required String phone,
    required String speciality,
    required String commissionPercent,
    required DateTime hireDate,
    required bool isActive,
  }) =>
      _save(() async =>
          await _repo.saveAgent(
            existing: existing, agencyId: agencyId, fullName: fullName,
            email: email, phone: phone, speciality: speciality,
            commissionPercent: commissionPercent, hireDate: hireDate,
            isActive: isActive,
          ) ??
          '');

  /// BF1.5 — renvoie 'deleted', 'deactivated' ou null (échec).
  Future<String?> deleteUser(User user, {required int currentUserId}) =>
      _save(() async => (await _repo.deleteUser(user, currentUserId: currentUserId)).name);

  /// Exécute une action, gère l'erreur puis prévient le Module 2.
  Future<String?> _save(Future<String> Function() action) async {
    isSaving = true;
    errorMessage = null;
    errorField = null;
    notifyListeners();
    try {
      final result = await action();
      await onDataChanged?.call();
      return result;
    } on AdminException catch (e) {
      errorMessage = e.message;
      errorField = e.field;
      return null;
    } catch (e) {
      debugPrint('UserAdminProvider: $e');
      errorMessage = 'Une erreur est survenue. Réessayez.';
      return null;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
