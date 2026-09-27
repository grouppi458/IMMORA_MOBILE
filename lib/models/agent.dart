class Agent {
  final int? id;
  final int userId;
  final int agencyId;
  final String? speciality; // vente, location, luxe...
  final double commissionRate; // 0.03 = 3 %
  final int hireDate;

  Agent({
    this.id,
    required this.userId,
    required this.agencyId,
    this.speciality,
    required this.commissionRate,
    required this.hireDate,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'agencyId': agencyId,
        'speciality': speciality,
        'commissionRate': commissionRate,
        'hireDate': hireDate,
      };

  factory Agent.fromMap(Map<String, dynamic> m) => Agent(
        id: m['id'],
        userId: m['userId'],
        agencyId: m['agencyId'],
        speciality: m['speciality'],
        commissionRate: (m['commissionRate'] as num).toDouble(),
        hireDate: m['hireDate'] ?? 0,
      );
}
