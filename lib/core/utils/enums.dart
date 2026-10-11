// Enums partagés. En base, ils sont stockés en TEXT via `enum.name`.

enum UserRole { admin, agency, agent, client, owner }

enum SubscriptionPlan { free, basic, premium }

enum SubscriptionStatus { active, expired, suspended }

enum ActivityType { login, propertyAdded, clientAdded, visitCreated, transactionCreated }

extension SubscriptionPlanLabel on SubscriptionPlan {
  String get label => switch (this) {
        SubscriptionPlan.free => 'Free',
        SubscriptionPlan.basic => 'Basic',
        SubscriptionPlan.premium => 'Premium',
      };
}

/// Spécialités possibles d'un agent (stockées en texte dans agents.speciality).
const Map<String, String> agentSpecialities = {
  'vente': 'Vente',
  'location': 'Location',
  'luxe': 'Luxe',
};

// ---------- Biens (M3) : utilisés par les annonces (M5) ----------

enum PropertyType { apartment, house, villa, land, office, shop }

/// Vente ou location (même valeurs que transactions.type du M4 : 'sale' | 'rent').
enum DealType { sale, rent }

enum PropertyStatus { available, reserved, sold, rented }

/// État du bien (formulaire « Créer / modifier un bien », maquette M3).
enum PropertyCondition { asNew, good, toRenovate }

// ---------- Annonces (M5) ----------

/// brouillon → publiée ⇄ suspendue → expirée (fin de durée) ;
/// retirée quand le bien est vendu ou loué (BF5.4).
enum ListingStatus { draft, published, suspended, expired, withdrawn }

extension PropertyTypeLabel on PropertyType {
  String get label => switch (this) {
        PropertyType.apartment => 'Appartement',
        PropertyType.house => 'Maison',
        PropertyType.villa => 'Villa',
        PropertyType.land => 'Terrain',
        PropertyType.office => 'Bureau',
        PropertyType.shop => 'Boutique',
      };

  /// « Appartement S+3 », « Villa »… — titre court des cartes de visite.
  String shortLabel(int rooms) => switch (this) {
        PropertyType.apartment => rooms > 0 ? 'Appartement S+$rooms' : 'Appartement',
        _ => label,
      };
}

extension DealTypeLabel on DealType {
  String get label => switch (this) {
        DealType.sale => 'Vente',
        DealType.rent => 'Location',
      };
}

extension PropertyStatusLabel on PropertyStatus {
  String get label => switch (this) {
        PropertyStatus.available => 'Disponible',
        PropertyStatus.reserved => 'Réservé',
        PropertyStatus.sold => 'Vendu',
        PropertyStatus.rented => 'Loué',
      };

  /// Légende du dialogue « Changer le statut du bien » (maquette M3).
  String get hint => switch (this) {
        PropertyStatus.available => 'Visible dans la recherche client',
        PropertyStatus.reserved => 'Masqué des recherches · en négociation',
        PropertyStatus.sold => 'Automatique à la signature d’une vente',
        PropertyStatus.rented => 'Automatique à la signature d’une location',
      };
}

extension PropertyConditionLabel on PropertyCondition {
  String get label => switch (this) {
        PropertyCondition.asNew => 'Neuf',
        PropertyCondition.good => 'Bon état',
        PropertyCondition.toRenovate => 'À rénover',
      };
}

extension ListingStatusLabel on ListingStatus {
  String get label => switch (this) {
        ListingStatus.draft => 'Brouillon',
        ListingStatus.published => 'Publiée',
        ListingStatus.suspended => 'Suspendue',
        ListingStatus.expired => 'Expirée',
        ListingStatus.withdrawn => 'Retirée',
      };
}

// ---------- Visites (M6) ----------

/// demandée → confirmée → effectuée ; « absente » quand le client ne s'est
/// pas présenté (no-show) ; annulable (client ou agence) à tout moment avant
/// d'être effectuée.
enum VisitStatus { requested, confirmed, done, absent, cancelled }

extension VisitStatusLabel on VisitStatus {
  String get label => switch (this) {
        VisitStatus.requested => 'Demandée',
        VisitStatus.confirmed => 'Confirmée',
        VisitStatus.done => 'Effectuée',
        VisitStatus.absent => 'Absent',
        VisitStatus.cancelled => 'Annulée',
      };
}

// ---------- Transactions (M4) ----------

/// brouillon → en cours → signée → terminée ; annulable avant la signature.
/// La signature passe le bien en « Vendu » (vente) ou « Loué » (location) et
/// la fin d'une location le repasse en « Disponible ».
enum TransactionStatus { draft, ongoing, signed, completed, cancelled }

enum PaymentMethod { cash, cheque, transfer, card }

/// Statut d'un paiement, déduit des dates : payé (date de paiement), en
/// retard (échéance dépassée) ou en attente.
enum PaymentStatus { pending, paid, late }

/// Gravité d'une anomalie (`lib/ai/anomaly_detector.dart`) — badges
/// « High »/« Medium »/« Low » de la maquette.
enum AlertSeverity { low, medium, high }

/// Type d'anomalie détectée, stocké en texte dans alerts.type.
enum AlertType { amountOutlier, priceGap, agentActivity, paymentMismatch, paymentLate }

extension TransactionStatusLabel on TransactionStatus {
  String get label => switch (this) {
        TransactionStatus.draft => 'Brouillon',
        TransactionStatus.ongoing => 'En cours',
        TransactionStatus.signed => 'Signée',
        TransactionStatus.completed => 'Terminée',
        TransactionStatus.cancelled => 'Annulée',
      };
}

extension PaymentMethodLabel on PaymentMethod {
  String get label => switch (this) {
        PaymentMethod.cash => 'Espèces',
        PaymentMethod.cheque => 'Chèque',
        PaymentMethod.transfer => 'Virement',
        PaymentMethod.card => 'Carte',
      };
}

extension PaymentStatusLabel on PaymentStatus {
  String get label => switch (this) {
        PaymentStatus.pending => 'En attente',
        PaymentStatus.paid => 'Payé',
        PaymentStatus.late => 'En retard',
      };
}

extension AlertSeverityLabel on AlertSeverity {
  String get label => switch (this) {
        AlertSeverity.low => 'Low',
        AlertSeverity.medium => 'Medium',
        AlertSeverity.high => 'High',
      };
}

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
        UserRole.admin => 'Administrateur',
        UserRole.agency => 'Agence',
        UserRole.agent => 'Agent',
        UserRole.client => 'Client',
        UserRole.owner => 'Propriétaire',
      };
}
