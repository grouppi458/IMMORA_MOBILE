import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';

/// Échéance de paiement d'une transaction (table `payments`, M4). Le statut
/// — payé / en retard / en attente — se déduit des dates.
class Payment {
  final int? id;
  final int transactionId;
  final String label;
  final double amount;
  final int dueDate;
  final int? paidDate;
  final PaymentMethod? method;
  final int createdAt;

  Payment({
    this.id,
    required this.transactionId,
    required this.label,
    required this.amount,
    required this.dueDate,
    this.paidDate,
    this.method,
    required this.createdAt,
  });

  PaymentStatus get status {
    if (paidDate != null) return PaymentStatus.paid;
    if (dueDate < DateTime.now().millisecondsSinceEpoch) return PaymentStatus.late;
    return PaymentStatus.pending;
  }

  /// Jours de retard (« 12 j de retard », maquette du détail).
  int get lateDays => status != PaymentStatus.late
      ? 0
      : DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(dueDate))
          .inDays;

  /// « Payé le 28 sept. · virement », « Échéance 1 oct. · 12 j de retard »,
  /// « Échéance 30 oct. 2026 » (maquette « Transaction »).
  String get subtitle {
    final paid = paidDate;
    return switch (status) {
      PaymentStatus.paid => 'Payé le ${formatDayMonth(paid!)}'
          '${method == null ? '' : ' · ${method!.label.toLowerCase()}'}',
      PaymentStatus.late =>
        'Échéance ${formatDayMonth(dueDate)} · $lateDays j de retard',
      PaymentStatus.pending => 'Échéance ${formatDate(dueDate)}',
    };
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'transactionId': transactionId,
        'label': label,
        'amount': amount,
        'dueDate': dueDate,
        'paidDate': paidDate,
        'method': method?.name,
        'createdAt': createdAt,
      };

  factory Payment.fromMap(Map<String, dynamic> m) => Payment(
        id: m['id'],
        transactionId: m['transactionId'],
        label: m['label'],
        amount: (m['amount'] as num).toDouble(),
        dueDate: m['dueDate'],
        paidDate: m['paidDate'],
        method: m['method'] == null ? null : PaymentMethod.values.byName(m['method']),
        createdAt: m['createdAt'],
      );
}
