import 'dart:convert';

import 'package:immora_mobile/core/utils/enums.dart';

/// Alerte d'anomalie (table `alerts`, M4), produite par
/// `lib/module_gestion_ventes/ai/anomaly_detector.dart` — maquettes « Alertes » et « Alerte ».
class Alert {
  final int? id;
  final int agencyId;
  final AlertType type;
  final AlertSeverity severity;
  final String title;
  final String? subtitle;
  final String description;
  final Map<String, String> details; // lignes du détail (JSON en base)
  final int? transactionId;
  final int? paymentId;
  final bool isRead;
  final int createdAt;

  Alert({
    this.id,
    required this.agencyId,
    required this.type,
    required this.severity,
    required this.title,
    this.subtitle,
    required this.description,
    this.details = const {},
    this.transactionId,
    this.paymentId,
    required this.isRead,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'agencyId': agencyId,
        'type': type.name,
        'severity': severity.name,
        'title': title,
        'subtitle': subtitle,
        'description': description,
        'details': jsonEncode(details),
        'transactionId': transactionId,
        'paymentId': paymentId,
        'isRead': isRead ? 1 : 0,
        'createdAt': createdAt,
      };

  factory Alert.fromMap(Map<String, dynamic> m) {
    final raw = m['details'] as String?;
    final decoded = raw == null || raw.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(raw) as Map<String, dynamic>;
    return Alert(
      id: m['id'],
      agencyId: m['agencyId'],
      type: AlertType.values.byName(m['type']),
      severity: AlertSeverity.values.byName(m['severity']),
      title: m['title'],
      subtitle: m['subtitle'],
      description: m['description'],
      details: decoded.map((key, value) => MapEntry(key, '$value')),
      transactionId: m['transactionId'],
      paymentId: m['paymentId'],
      isRead: m['isRead'] == 1,
      createdAt: m['createdAt'],
    );
  }
}
