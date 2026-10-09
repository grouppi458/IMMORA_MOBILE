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

enum PropertyType { apartment, house, villa, land, office }

/// Vente ou location (même valeurs que transactions.type du M4 : 'sale' | 'rent').
enum DealType { sale, rent }

enum PropertyStatus { available, reserved, sold, rented }

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

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
        UserRole.admin => 'Administrateur',
        UserRole.agency => 'Agence',
        UserRole.agent => 'Agent',
        UserRole.client => 'Client',
        UserRole.owner => 'Propriétaire',
      };
}
