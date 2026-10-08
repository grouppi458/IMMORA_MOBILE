import 'package:immora_mobile/module_gestion_agences/score/activity_scorer.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/module_gestion_agences/models/agency.dart';
import 'package:immora_mobile/module_gestion_agences/models/subscription.dart';

/// État affiché d'une agence (badge de la liste).
enum AgencyStatus { active, expired, suspended }

extension AgencyStatusLabel on AgencyStatus {
  String get label => switch (this) {
        AgencyStatus.active => 'Active',
        AgencyStatus.expired => 'Expirée',
        AgencyStatus.suspended => 'Suspendue',
      };
}

/// Une agence avec son abonnement, ses compteurs et son score d'activité.
class AgencySummary {
  const AgencySummary({
    required this.agency,
    required this.subscription,
    required this.activeAgents,
    required this.properties,
    required this.activity,
  });

  final Agency agency;
  final Subscription? subscription;
  final int activeAgents;
  final int properties;
  final ActivityScore activity;

  AgencyStatus get status {
    if (!agency.isActive) return AgencyStatus.suspended;
    final sub = subscription;
    if (sub == null || sub.status != SubscriptionStatus.active) return AgencyStatus.expired;
    return AgencyStatus.active;
  }
}

/// Chiffres du tableau de bord admin.
class DashboardStats {
  const DashboardStats({
    required this.activeAgencies,
    required this.totalAgencies,
    required this.agenciesThisMonth,
    required this.accounts,
    required this.mrr,
    required this.properties,
    required this.propertiesThisMonth,
    required this.monthlyRevenue,
    required this.accountsByRole,
  });

  final int activeAgencies;
  final int totalAgencies;
  final int agenciesThisMonth;
  final int accounts; // tous les comptes sauf admin
  final double mrr; // revenu mensuel récurrent (TND)
  final int properties;
  final int propertiesThisMonth;
  final List<MonthRevenue> monthlyRevenue; // 6 derniers mois, du plus ancien au plus récent
  final Map<UserRole, int> accountsByRole;
}

class MonthRevenue {
  const MonthRevenue(this.month, this.amount);

  final DateTime month;
  final double amount; // TND
}
