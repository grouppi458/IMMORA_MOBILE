// Enums partagés. En base, ils sont stockés en TEXT via `enum.name`.

enum UserRole { admin, agency, agent, client, owner }

enum SubscriptionPlan { free, basic, premium }

enum SubscriptionStatus { active, expired, suspended }

enum ActivityType { login, propertyAdded, clientAdded, visitCreated, transactionCreated }

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
        UserRole.admin => 'Administrateur',
        UserRole.agency => 'Agence',
        UserRole.agent => 'Agent',
        UserRole.client => 'Client',
        UserRole.owner => 'Propriétaire',
      };
}
