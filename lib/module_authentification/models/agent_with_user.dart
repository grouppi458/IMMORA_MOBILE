import 'package:immora_mobile/module_authentification/models/agent.dart';
import 'package:immora_mobile/module_authentification/models/user.dart';

/// Un agent (table `agents`) avec son compte utilisateur (table `users`).
class AgentWithUser {
  const AgentWithUser({required this.agent, required this.user});

  final Agent agent;
  final User user;
}
