import 'package:immora_mobile/core/utils/enums.dart';

// Base locale
const String dbName = 'immo_saas.db';
// v2 : users.cin, users.address, table clients supprimée
// v3 (M5) : tables listings, favorites (+ properties provisoire en attendant le M3)
// v4 (M5) : tables search_criteria, notifications (matching et alertes)
// v5 (M6) : table visits (demandes de visite)
// v6 (M6) : visits.rating, ratingComment (notation client) et agentNote
// v7 (M3) : colonnes du bien (état, étage, surface terrain, adresse,
//           description) et table property_photos
// v8 (M4) : tables transactions, payments et alerts (anomalies)
const int dbVersion = 8;

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
// Taux proposé par défaut au formulaire de transaction (« 3 % », maquette M4).
const double commissionDefaultPercent = 3;

// Annonces (M5) : durées de publication possibles (BF5.1) et limites du titre.
const List<int> listingDurations = [30, 60, 90];
const int listingTitleMinLength = 5;
const int listingTitleMaxLength = 80;

// Biens (M3) : limites du formulaire (BF3.1), photos (BF3.2) et paramètres
// de l'estimation du prix (BF3.6–BF3.8, `lib/module_gestion_biens/ai/price_estimator.dart`).
const int propertyTitleMinLength = 5;
const int propertyTitleMaxLength = 80;
const int propertyDescriptionMaxLength = 500;
const int propertyPhotoMaxCount = 10;
// Fourchette affichée autour de l'estimation (± 10 % sur la maquette).
const double estimateRangePercent = 0.10;
// En dessous de ce nombre de comparables, le prix moyen par défaut de la
// ville (defaultPricePerM2) sert de base.
const int estimateMinComparables = 3;
// Coefficients appliqués à la surface : +2 % par chambre au-delà de S+1
// (« Chambres (S+3) + 4 % ») et +2,5 % par équipement (« + 5 % » pour deux).
const double estimateRoomsBonusPerRoom = 0.02;
const double estimateAmenityBonus = 0.025;
// Coefficient selon l'état (« Coef. état (bon) × 1,00 » sur la maquette).
const Map<PropertyCondition, double> estimateConditionCoefficient = {
  PropertyCondition.asNew: 1.05,
  PropertyCondition.good: 1.00,
  PropertyCondition.toRenovate: 0.90,
};
const double fallbackPricePerM2 = 3000;
const Map<String, double> defaultPricePerM2 = {
  'Tunis': 3200,
  'Ariana': 2800,
  'La Marsa': 3800,
  'Carthage': 3500,
  'Sousse': 2500,
};

// Visites (M6) : créneaux de 30 minutes entre 09:00 et 18:00 (« Demander une
// visite »), pause déjeuner 12:00–14:00 (maquette Figma), durée d'une visite,
// notation et longueur max du message.
const int visitSlotStartMinutes = 9 * 60; // 09:00
const int visitSlotEndMinutes = 18 * 60; // 18:00
const int visitSlotStepMinutes = 30;
const int visitLunchStartMinutes = 12 * 60; // 12:00
const int visitLunchEndMinutes = 14 * 60; // 14:00
const int visitDurationMinutes = 30;
const int visitNoteMaxLength = 200;
const int visitRatingMin = 1;
const int visitRatingMax = 5;
// Délai du rappel local avant la visite (heures).
const int visitReminderHours = 24;

// Ventes (M4) : seuils du détecteur d'anomalies (`lib/module_gestion_ventes/ai/anomaly_detector.dart`),
// repris dans la bannière de l'écran « Alertes ».
const double anomalyZScoreThreshold = 2.5; // montant inhabituel (z-score)
const double anomalyPriceGapPercent = 30; // écart prix affiché / estimation
const int anomalyAgentActivityMax = 5; // transactions d'un agent en 24 h
const double anomalyPaymentGapPercent = 5; // écart échéance / montant reçu
const int anomalyMinHistory = 5; // historique minimal avant détection

String _slotLabel(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutes % 60).toString().padLeft(2, '0')}';

/// « 09:00 », « 09:30 » … « 18:00 » — créneaux proposés au client (la pause
/// déjeuner est exclue).
final List<String> visitTimeSlots = List<String>.unmodifiable([
  for (var m = visitSlotStartMinutes; m <= visitSlotEndMinutes; m += visitSlotStepMinutes)
    if (m < visitLunchStartMinutes || m >= visitLunchEndMinutes) _slotLabel(m),
]);

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
