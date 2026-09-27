import 'enums.dart';

// Base locale
const String dbName = 'immo_saas.db';
const int dbVersion = 1;

// Mot de passe des comptes de démonstration (données de démo uniquement).
const String demoPassword = 'immora123';

// Limites de saisie
const int nameMinLength = 3;
const int nameMaxLength = 50;
const int passwordMinLength = 6;
const int passwordMaxLength = 64;

// Durée de l'essai gratuit créé avec chaque nouvelle agence.
const int freeTrialDays = 30;

/// Valeurs par défaut de chaque plan d'abonnement.
class PlanDefaults {
  const PlanDefaults(this.monthlyPrice, this.maxProperties, this.maxAgents);

  final double monthlyPrice; // TND
  final int maxProperties;
  final int maxAgents;
}

const Map<SubscriptionPlan, PlanDefaults> planDefaults = {
  SubscriptionPlan.free: PlanDefaults(0, 5, 1),
  SubscriptionPlan.basic: PlanDefaults(49, 50, 5),
  SubscriptionPlan.premium: PlanDefaults(149, 500, 30),
};
