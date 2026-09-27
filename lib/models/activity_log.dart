import '../utils/enums.dart';

class ActivityLog {
  final int? id;
  final int userId;
  final int? agencyId;
  final ActivityType type;
  final String? details;
  final int timestamp;

  ActivityLog({
    this.id,
    required this.userId,
    this.agencyId,
    required this.type,
    this.details,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'agencyId': agencyId,
        'type': type.name,
        'details': details,
        'timestamp': timestamp,
      };

  factory ActivityLog.fromMap(Map<String, dynamic> m) => ActivityLog(
        id: m['id'],
        userId: m['userId'],
        agencyId: m['agencyId'],
        type: ActivityType.values.byName(m['type']),
        details: m['details'],
        timestamp: m['timestamp'],
      );
}
