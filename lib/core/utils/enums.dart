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

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
        UserRole.admin => 'Administrateur',
        UserRole.agency => 'Agence',
        UserRole.agent => 'Agent',
        UserRole.client => 'Client',
        UserRole.owner => 'Propriétaire',
      };
}
