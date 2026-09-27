import '../utils/enums.dart';

class Subscription {
  final int? id;
  final int agencyId;
  final SubscriptionPlan plan;
  final double monthlyPrice; // TND
  final int maxProperties;
  final int maxAgents;
  final int startDate;
  final int endDate;
  final SubscriptionStatus status;

  Subscription({
    this.id,
    required this.agencyId,
    required this.plan,
    required this.monthlyPrice,
    required this.maxProperties,
    required this.maxAgents,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  bool get isExpired => DateTime.now().millisecondsSinceEpoch > endDate;

  Map<String, dynamic> toMap() => {
        'id': id,
        'agencyId': agencyId,
        'plan': plan.name,
        'monthlyPrice': monthlyPrice,
        'maxProperties': maxProperties,
        'maxAgents': maxAgents,
        'startDate': startDate,
        'endDate': endDate,
        'status': status.name,
      };

  factory Subscription.fromMap(Map<String, dynamic> m) => Subscription(
        id: m['id'],
        agencyId: m['agencyId'],
        plan: SubscriptionPlan.values.byName(m['plan']),
        monthlyPrice: (m['monthlyPrice'] as num).toDouble(),
        maxProperties: m['maxProperties'] ?? 0,
        maxAgents: m['maxAgents'] ?? 0,
        startDate: m['startDate'],
        endDate: m['endDate'],
        status: SubscriptionStatus.values.byName(m['status']),
      );
}
