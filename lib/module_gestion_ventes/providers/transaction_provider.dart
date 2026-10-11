import 'package:flutter/foundation.dart';

import 'package:immora_mobile/core/errors/app_exception.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/module_gestion_ventes/models/finance_stats.dart';
import 'package:immora_mobile/module_gestion_ventes/models/payment.dart';
import 'package:immora_mobile/module_gestion_ventes/models/transaction_details.dart';
import 'package:immora_mobile/module_gestion_ventes/repositories/stats_repository.dart';
import 'package:immora_mobile/module_gestion_ventes/repositories/transaction_repository.dart';

/// État du Module 4 côté agence : la liste « Transactions » (filtres,
/// recherche), le cycle de vie (signer, terminer, annuler) et les paiements.
class TransactionProvider extends ChangeNotifier {
  TransactionProvider({TransactionRepository? transactions, StatsRepository? stats})
      : _transactions = transactions ?? TransactionRepository(),
        _stats = stats ?? StatsRepository();

  final TransactionRepository _transactions;
  final StatsRepository _stats;

  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;
  String? errorField;
  int? agencyId;
  DealType? dealFilter; // null = « Toutes »
  TransactionStatus? statusFilter; // null = « Tous statuts »
  String query = '';
  List<TransactionDetails> transactions = [];

  void clearError() {
    if (errorMessage == null) return;
    errorMessage = null;
    errorField = null;
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
      debugPrint('TransactionProvider.load: $e');
      errorMessage = 'Impossible de charger les transactions.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void setDealFilter(DealType? deal) {
    dealFilter = deal;
    notifyListeners();
    _reloadList();
  }

  void setStatusFilter(TransactionStatus? status) {
    statusFilter = status;
    notifyListeners();
    _reloadList();
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
      debugPrint('TransactionProvider: $e');
    }
    notifyListeners();
  }

  Future<void> _refresh() async {
    transactions = await _transactions.agencyTransactions(agencyId!,
        dealType: dealFilter, status: statusFilter, query: query);
  }

  // ---------------------------------------------------------------- Lecture

  Future<TransactionDetails> details(int id) => _transactions.details(id);

  Future<List<(int, String, double)>> propertyOptions(int agencyId,
          {int? currentTransactionId}) =>
      _transactions.propertyOptions(agencyId, currentTransactionId: currentTransactionId);

  Future<List<(int, String)>> agentOptions(int agencyId) =>
      _transactions.agentOptions(agencyId);

  Future<List<Payment>> payments(int transactionId) =>
      _transactions.payments(transactionId);

  Future<double> paidAmount(int transactionId) =>
      _transactions.paidAmount(transactionId);

  /// Chiffres de l'écran « Finances » (période trimestre / mois / année).
  Future<FinanceStats> financeStats(int agencyId,
          {required DateTime from, required DateTime to}) =>
      _stats.financeStats(agencyId, from: from, to: to);

  // ---------------------------------------------------------------- Écriture

  Future<int?> create({
    required int agencyId,
    required int propertyId,
    required String clientName,
    required DealType dealType,
    required double amount,
    required double commissionRate,
    required DateTime startDate,
    TransactionStatus status = TransactionStatus.draft,
    int? agentId,
    DateTime? endDate,
    String? contractPath,
  }) async {
    isSaving = true;
    errorMessage = null;
    errorField = null;
    notifyListeners();
    try {
      final id = await _transactions.create(
        agencyId: agencyId,
        propertyId: propertyId,
        clientName: clientName,
        dealType: dealType,
        amount: amount,
        commissionRate: commissionRate,
        startDate: startDate,
        status: status,
        agentId: agentId,
        endDate: endDate,
        contractPath: contractPath,
      );
      if (this.agencyId != null) await _refresh();
      return id;
    } on AdminException catch (e) {
      errorMessage = e.message;
      errorField = e.field;
      return null;
    } catch (e) {
      debugPrint('TransactionProvider.create: $e');
      errorMessage = 'Une erreur est survenue. Réessayez.';
      return null;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> update(
    int id, {
    required int propertyId,
    required String clientName,
    required DealType dealType,
    required double amount,
    required double commissionRate,
    required DateTime startDate,
    int? agentId,
    DateTime? endDate,
    String? contractPath,
  }) =>
      _run(() => _transactions.update(id,
          propertyId: propertyId,
          clientName: clientName,
          dealType: dealType,
          amount: amount,
          commissionRate: commissionRate,
          startDate: startDate,
          agentId: agentId,
          endDate: endDate,
          contractPath: contractPath));

  Future<bool> activate(int id) => _run(() => _transactions.activate(id));
  Future<bool> sign(int id) => _run(() => _transactions.sign(id));
  Future<bool> complete(int id) => _run(() => _transactions.complete(id));
  Future<bool> cancel(int id, {required String reason}) =>
      _run(() => _transactions.cancel(id, reason: reason));

  Future<bool> insertPayment(
    int transactionId, {
    required double amount,
    required DateTime dueDate,
    DateTime? paidDate,
    PaymentMethod? method,
  }) =>
      _run(() => _transactions.insertPayment(transactionId,
          amount: amount, dueDate: dueDate, paidDate: paidDate, method: method));

  Future<bool> updatePayment(
    int id, {
    required double amount,
    required DateTime dueDate,
    required bool paid,
    DateTime? paidDate,
    PaymentMethod? method,
  }) =>
      _run(() => _transactions.updatePayment(id,
          amount: amount,
          dueDate: dueDate,
          paid: paid,
          paidDate: paidDate,
          method: method));

  /// Exécute une action, recharge la liste, et garde l'erreur métier à afficher.
  Future<bool> _run(Future<void> Function() action) async {
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
      debugPrint('TransactionProvider: $e');
      errorMessage = 'Une erreur est survenue. Réessayez.';
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
