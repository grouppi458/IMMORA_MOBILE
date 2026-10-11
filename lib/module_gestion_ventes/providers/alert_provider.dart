import 'package:flutter/foundation.dart';

import 'package:immora_mobile/core/errors/app_exception.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/module_gestion_ventes/models/alert.dart';
import 'package:immora_mobile/module_gestion_ventes/repositories/alert_repository.dart';

/// État de l'onglet « Alertes » (maquettes M4) : la liste filtrée par gravité
/// ou non-lues, les compteurs des puces et les actions (lue, ignorer).
class AlertProvider extends ChangeNotifier {
  AlertProvider({AlertRepository? alerts}) : _alerts = alerts ?? AlertRepository();

  final AlertRepository _alerts;

  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;
  int? agencyId;
  AlertSeverity? severityFilter; // null = toutes gravités
  bool unreadOnly = false;
  List<Alert> alerts = [];
  ({int total, int unread, Map<AlertSeverity, int> bySeverity}) counts =
      (total: 0, unread: 0, bySeverity: <AlertSeverity, int>{});

  void clearError() {
    if (errorMessage == null) return;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> load(int agencyId) async {
    this.agencyId = agencyId;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _refresh();
    } catch (e) {
      debugPrint('AlertProvider.load: $e');
      errorMessage = 'Impossible de charger les alertes.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Puces « Toutes · 5 », « Non lues · 3 », « High », « Medium », « Low ».
  void setFilter({AlertSeverity? severity, required bool unread}) {
    severityFilter = severity;
    unreadOnly = unread;
    notifyListeners();
    _reloadList();
  }

  Future<void> _reloadList() async {
    if (agencyId == null) return;
    try {
      await _refresh();
    } catch (e) {
      debugPrint('AlertProvider: $e');
    }
    notifyListeners();
  }

  Future<void> _refresh() async {
    alerts = await _alerts.list(agencyId!,
        unreadOnly: unreadOnly, severity: severityFilter);
    counts = await _alerts.counts(agencyId!);
  }

  Future<bool> markRead(int id) => _run(() => _alerts.markRead(id));

  Future<bool> markAllRead() => _run(() => _alerts.markAllRead(agencyId!));

  Future<bool> ignore(int id) => _run(() => _alerts.ignore(id));

  Future<bool> _run(Future<void> Function() action) async {
    isSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      await _refresh();
      return true;
    } on AdminException catch (e) {
      errorMessage = e.message;
      return false;
    } catch (e) {
      debugPrint('AlertProvider: $e');
      errorMessage = 'Une erreur est survenue. Réessayez.';
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
