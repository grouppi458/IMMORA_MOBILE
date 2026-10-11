import 'package:flutter/foundation.dart';

import 'package:immora_mobile/core/errors/app_exception.dart';
import 'package:immora_mobile/module_gestion_visites/services/visit_reminders.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/module_gestion_visites/models/visit_details.dart';
import 'package:immora_mobile/module_gestion_visites/repositories/visit_repository.dart';

/// État du Module 6 : demandes de visite du client (« Mes visites ») et,
/// côté agence / agent, les visites à traiter (confirmer, reprogrammer,
/// effectuer, annuler).
class VisitProvider extends ChangeNotifier {
  VisitProvider({VisitRepository? repository}) : _repo = repository ?? VisitRepository();

  final VisitRepository _repo;

  int? clientId; // mode client
  int? agencyId; // mode pro
  int? agentId; // mode pro : restreint aux visites assignées
  int? ownerId; // mode propriétaire : visites des biens de l'owner
  bool isLoading = false;
  String? errorMessage;
  List<VisitDetails> visits = [];

  /// Demandes en attente de réponse (pastille côté pro).
  int get pendingCount => visits.where((v) => v.visit.status == VisitStatus.requested).length;

  Future<void> loadForClient(int clientId) async {
    this.clientId = clientId;
    agencyId = null;
    ownerId = null;
    await _load(() => _repo.clientVisits(clientId));
  }

  Future<void> loadForAgency(int agencyId, {int? agentId}) async {
    this.agencyId = agencyId;
    this.agentId = agentId;
    clientId = null;
    ownerId = null;
    await _load(() => _repo.agencyVisits(agencyId, agentId: agentId));
  }

  Future<void> loadForOwner(int ownerId) async {
    this.ownerId = ownerId;
    clientId = null;
    agencyId = null;
    await _load(() => _repo.ownerVisits(ownerId));
  }

  Future<void> _load(Future<List<VisitDetails>> Function() fetch) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      visits = await fetch();
    } catch (e) {
      debugPrint('VisitProvider.load: $e');
      errorMessage = 'Impossible de charger les visites.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reload() async {
    final c = clientId;
    final a = agencyId;
    final o = ownerId;
    if (c != null) {
      await _load(() => _repo.clientVisits(c));
    } else if (a != null) {
      await _load(() => _repo.agencyVisits(a, agentId: agentId));
    } else if (o != null) {
      await _load(() => _repo.ownerVisits(o));
    }
  }

  /// Créneaux (minutes depuis minuit) déjà pris par l'agent du bien ce
  /// jour-là — le formulaire de demande les désactive.
  Future<Set<int>> slotsTaken({required int listingId, required DateTime day}) =>
      _repo.slotsTaken(listingId: listingId, day: day);

  /// Le client demande la visite d'une annonce. Renvoie null si l'action a
  /// réussi, sinon le message à afficher.
  Future<String?> request({
    required int clientId,
    required int listingId,
    required DateTime scheduledAt,
    String? note,
  }) async {
    try {
      final id = await _repo.request(
          clientId: clientId, listingId: listingId, scheduledAt: scheduledAt, note: note);
      this.clientId = clientId;
      await reload();
      await _syncReminder(id);
      return null;
    } on AdminException catch (e) {
      return e.message;
    } catch (e) {
      debugPrint('VisitProvider.request: $e');
      return 'Une erreur est survenue. Réessayez.';
    }
  }

  /// Confirme (avec reprogrammation éventuelle) côté pro.
  Future<String?> confirm(int id, {DateTime? newSlot}) =>
      _decide(() => _repo.confirm(id, newSlot: newSlot), reminderFor: id);

  /// Reprogramme une visite confirmée côté pro.
  Future<String?> reschedule(int id, DateTime newSlot) =>
      _decide(() => _repo.reschedule(id, newSlot), reminderFor: id);

  /// Marque une visite effectuée côté pro.
  Future<String?> markDone(int id) => _decide(() => _repo.markDone(id), reminderFor: id);

  /// Marque le client absent (no-show) côté pro.
  Future<String?> markAbsent(int id) => _decide(() => _repo.markAbsent(id), reminderFor: id);

  /// Le client note une visite effectuée (1–5 étoiles + commentaire).
  Future<String?> rate(int id, {required int rating, String? comment}) =>
      _decide(() => _repo.rate(id, rating: rating, comment: comment));

  /// Enregistre le compte rendu interne de l'agent.
  Future<String?> saveAgentNote(int id, String? note) =>
      _decide(() => _repo.saveAgentNote(id, note));

  /// Annule une visite en cours. [byClient] true quand c'est le client
  /// (aucune notification à envoyer).
  Future<String?> cancel(int id, {required String reason, bool byClient = false}) =>
      _decide(() => _repo.cancel(id, reason: reason, notifyClient: !byClient), reminderFor: id);

  Future<String?> _decide(Future<void> Function() action, {int? reminderFor}) async {
    try {
      await action();
      await reload();
      if (reminderFor != null) await _syncReminder(reminderFor);
      return null;
    } on AdminException catch (e) {
      return e.message;
    } catch (e) {
      debugPrint('VisitProvider: $e');
      return 'Une erreur est survenue. Réessayez.';
    }
  }

  /// Aligne le rappel local « 24 h avant » sur l'état de la visite [id] :
  /// programmé tant qu'elle est ouverte (demandée / confirmée), retiré sinon.
  Future<void> _syncReminder(int id) async {
    final match = visits.where((v) => v.visit.id == id).firstOrNull;
    if (match == null) return;
    final isOpen = match.visit.status == VisitStatus.requested ||
        match.visit.status == VisitStatus.confirmed;
    await (isOpen
        ? VisitReminderService.instance.schedule(match)
        : VisitReminderService.instance.cancel(id));
  }
}
