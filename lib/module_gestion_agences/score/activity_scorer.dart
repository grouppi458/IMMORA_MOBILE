import 'package:immora_mobile/module_authentification/repositories/activity_log_repository.dart';
import 'package:immora_mobile/core/utils/enums.dart';

// Poids du score d'activité (cahier des charges, section 1.6).
const double wLogin = 0.3;
const double wProperty = 0.3;
const double wClient = 0.2;
const double wRecency = 0.2;
const int lowActivityThreshold = 30;

class ActivityScore {
  const ActivityScore({
    required this.score,
    required this.loginsLast30Days,
    required this.propertiesAddedLast30Days,
    required this.clientsAddedLast30Days,
    required this.daysSinceLastActivity,
  });

  final int score; // 0 à 100
  final int loginsLast30Days;
  final int propertiesAddedLast30Days;
  final int clientsAddedLast30Days;
  final int? daysSinceLastActivity; // null = aucune activité enregistrée

  /// « Faible » (< 30), « Moyenne » (30–69), « Forte » (≥ 70).
  String get activityLevel => score < lowActivityThreshold
      ? 'Faible'
      : score < 70
          ? 'Moyenne'
          : 'Forte';

  bool get isLow => score < lowActivityThreshold;
}

/// Score d'activité d'une agence sur les 30 derniers jours :
/// score = 100 × (0,3·min(1, logins/20) + 0,3·min(1, biens/10)
///               + 0,2·min(1, clients/10) + 0,2·max(0, 1 − joursInactif/30))
class ActivityScorer {
  final _logs = ActivityLogRepository();

  static int compute({
    required int logins,
    required int properties,
    required int clients,
    required int? daysInactive,
  }) {
    double cap(double v) => v > 1 ? 1 : v;
    final recency =
        daysInactive == null ? 0.0 : (1 - daysInactive / 30).clamp(0.0, 1.0);
    final raw = wLogin * cap(logins / 20) +
        wProperty * cap(properties / 10) +
        wClient * cap(clients / 10) +
        wRecency * recency;
    return (100 * raw).round().clamp(0, 100);
  }

  Future<ActivityScore> scoreAgency(int agencyId) async {
    final now = DateTime.now();
    final since = now.subtract(const Duration(days: 30));
    final logins = await _logs.countByType(agencyId, ActivityType.login, since);
    final properties = await _logs.countByType(agencyId, ActivityType.propertyAdded, since);
    final clients = await _logs.countByType(agencyId, ActivityType.clientAdded, since);
    final last = await _logs.lastActivityTimestamp(agencyId);
    final days = last == null
        ? null
        : now.difference(DateTime.fromMillisecondsSinceEpoch(last)).inDays;

    return ActivityScore(
      score: compute(
          logins: logins, properties: properties, clients: clients, daysInactive: days),
      loginsLast30Days: logins,
      propertiesAddedLast30Days: properties,
      clientsAddedLast30Days: clients,
      daysSinceLastActivity: days,
    );
  }
}
