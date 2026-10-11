import 'package:immora_mobile/module_gestion_agences/models/agency_views.dart';

/// Périodes du sélecteur « Ce trimestre | Ce mois | Année » (maquette
/// « Finances »).
enum StatsPeriod { quarter, month, year }

extension StatsPeriodLabel on StatsPeriod {
  String get label => switch (this) {
        StatsPeriod.quarter => 'Ce trimestre',
        StatsPeriod.month => 'Ce mois',
        StatsPeriod.year => 'Année',
      };

  /// Légende sous les compteurs (« ce trimestre »).
  String get caption => switch (this) {
        StatsPeriod.quarter => 'ce trimestre',
        StatsPeriod.month => 'ce mois',
        StatsPeriod.year => 'cette année',
      };

  /// Début de la période (le mois en cours comprend son 1er jour).
  DateTime get from {
    final now = DateTime.now();
    return switch (this) {
      StatsPeriod.quarter => DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1),
      StatsPeriod.month => DateTime(now.year, now.month),
      StatsPeriod.year => DateTime(now.year),
    };
  }
}

/// Chiffres de l'écran « Finances » : compteurs de la période, commissions
/// mensuelles (« Revenus (4 mois) »), encaissements en attente / en retard —
/// l'état courant, indépendant de la période — et classement des agents.
class FinanceStats {
  const FinanceStats({
    required this.salesCount,
    required this.rentsCount,
    required this.totalAmount,
    required this.commissions,
    required this.monthlyRevenue,
    required this.pendingCount,
    required this.pendingAmount,
    required this.lateCount,
    required this.lateAmount,
    required this.agentCommissions,
  });

  final int salesCount;
  final int rentsCount;
  final double totalAmount; // somme des montants de la période
  final double commissions; // somme des commissions de la période
  final List<MonthRevenue> monthlyRevenue; // 4 derniers mois, mois courant inclus
  final int pendingCount;
  final double pendingAmount;
  final int lateCount;
  final double lateAmount;
  final List<(String, double)> agentCommissions; // (nom, commissions) triés
}
