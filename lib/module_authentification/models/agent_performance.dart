import 'package:immora_mobile/module_authentification/models/agent_with_user.dart';

/// Résultats d'un agent sur une période (BF1.8).
class AgentPerformance {
  const AgentPerformance({
    required this.agent,
    required this.visits,
    required this.sales,
    required this.rentals,
    required this.commissions,
  });

  final AgentWithUser agent;
  final int visits; // visites réalisées (table visits, M6)
  final int sales; // ventes conclues (table transactions, M4)
  final int rentals; // locations conclues (table transactions, M4)
  final double commissions; // total des commissions en TND

  int get deals => sales + rentals;
}

/// Période d'analyse du tableau de bord.
enum PerformancePeriod { days30, days90, months12 }

extension PerformancePeriodX on PerformancePeriod {
  String get label => switch (this) {
        PerformancePeriod.days30 => '30 jours',
        PerformancePeriod.days90 => '90 jours',
        PerformancePeriod.months12 => '12 mois',
      };

  DateTime get since => DateTime.now().subtract(Duration(
      days: switch (this) {
        PerformancePeriod.days30 => 30,
        PerformancePeriod.days90 => 90,
        PerformancePeriod.months12 => 365,
      }));
}
