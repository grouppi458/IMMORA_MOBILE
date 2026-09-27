// Modèle de l'Ingénieur 3. Version minimale utilisée par l'inscription
// client (Ing. 1) : les critères de recherche restent vides à la création.
class Client {
  final int? id;
  final int userId;
  final int? agencyId;
  final int? agentId;
  final String fullName;
  final String phone;
  final String email;
  final int createdAt;

  Client({
    this.id,
    required this.userId,
    this.agencyId,
    this.agentId,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'agencyId': agencyId,
        'agentId': agentId,
        'fullName': fullName,
        'phone': phone,
        'email': email,
        'createdAt': createdAt,
      };

  factory Client.fromMap(Map<String, dynamic> m) => Client(
        id: m['id'],
        userId: m['userId'],
        agencyId: m['agencyId'],
        agentId: m['agentId'],
        fullName: m['fullName'],
        phone: m['phone'] ?? '',
        email: m['email'] ?? '',
        createdAt: m['createdAt'],
      );
}
