import 'package:immora_mobile/core/utils/enums.dart';

// Base locale
const String dbName = 'immo_saas.db';
// v2 : users.cin, users.address, table clients supprimée
// v3 (M5) : tables listings, favorites (+ properties provisoire en attendant le M3)
// v4 (M5) : tables search_criteria, notifications (matching et alertes)
const int dbVersion = 4;

// Mot de passe des comptes de démonstration (données de démo uniquement).
const String demoPassword = 'immora123';

// Limites de saisie
const int nameMinLength = 3;
const int nameMaxLength = 50;
const int passwordMinLength = 6;
const int passwordMaxLength = 64;

// Durée d'une période d'abonnement (essai gratuit compris).
const int freeTrialDays = 30;
const int subscriptionPeriodDays = 30;

// Taux de commission d'un agent (en %).
const double commissionMinPercent = 0.1;
const double commissionMaxPercent = 20;

// Annonces (M5) : durées de publication possibles (BF5.1) et limites du titre.
const List<int> listingDurations = [30, 60, 90];
const int listingTitleMinLength = 5;
const int listingTitleMaxLength = 80;

/// Valeurs par défaut de chaque plan d'abonnement.
class PlanDefaults {
  const PlanDefaults(this.monthlyPrice, this.maxProperties, this.maxAgents);

  final double monthlyPrice; // TND
  final int maxProperties;
  final int maxAgents;
}

const Map<SubscriptionPlan, PlanDefaults> planDefaults = {
  SubscriptionPlan.free: PlanDefaults(0, 5, 1),
  SubscriptionPlan.basic: PlanDefaults(90, 50, 5),
  SubscriptionPlan.premium: PlanDefaults(240, 500, 30),
};
