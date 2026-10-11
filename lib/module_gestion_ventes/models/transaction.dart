import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';

/// Transaction immobilière (table `transactions`, M4). Créée en brouillon ou
/// directement en cours depuis « Nouvelle transaction » ; la signature passe
/// le bien en « Vendu » (vente) ou « Loué » (location), la fin d'une location
/// le repasse en « Disponible ».
class Transaction {
  final int? id;
  final int agencyId;
  final int ref; // numéro affiché « #1042 », unique par agence
  final int propertyId;
  final int? clientId;
  final String clientName;
  final int? agentId; // agents.id
  final DealType dealType;
  final double amount;
  final double commissionRate; // 0,03
  final double commissionAmount;
  final TransactionStatus status;
  final int startDate;
  final int? signedAt;
  final int? endDate; // fin prévue (location)
  final String? cancelReason;
  final String? contractPath;
  final int createdAt;
  final int updatedAt;

  Transaction({
    this.id,
    required this.agencyId,
    required this.ref,
    required this.propertyId,
    this.clientId,
    required this.clientName,
    this.agentId,
    required this.dealType,
    required this.amount,
    required this.commissionRate,
    required this.commissionAmount,
    required this.status,
    required this.startDate,
    this.signedAt,
    this.endDate,
    this.cancelReason,
    this.contractPath,
    required this.createdAt,
    required this.updatedAt,
  });

  String get displayRef => '#$ref';

  /// Le bien est occupé : une transaction en brouillon, en cours ou signée
  /// empêche d'en créer une autre sur le même bien.
  bool get isActive =>
      status == TransactionStatus.draft ||
      status == TransactionStatus.ongoing ||
      status == TransactionStatus.signed;

  /// Terminée ou annulée : plus modifiable, plus de paiements.
  bool get isFinal =>
      status == TransactionStatus.completed || status == TransactionStatus.cancelled;

  /// « 1 250 000 TND », « 1 800 TND/mois » (maquette « Transactions »).
  String get amountLabel => dealType == DealType.rent
      ? '${formatNumber(amount)} TND/mois'
      : '${formatNumber(amount)} TND';

  /// « Y. Trabelsi », « W. Chaabane » — sous-titres des cartes.
  String get shortClient {
    final words = clientName.trim().split(RegExp(r'\s+'));
    if (words.length < 2) return clientName;
    return '${words.first[0]}. ${words.last}';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'agencyId': agencyId,
        'ref': ref,
        'propertyId': propertyId,
        'clientId': clientId,
        'clientName': clientName,
        'agentId': agentId,
        'dealType': dealType.name,
        'amount': amount,
        'commissionRate': commissionRate,
        'commissionAmount': commissionAmount,
        'status': status.name,
        'startDate': startDate,
        'signedAt': signedAt,
        'endDate': endDate,
        'cancelReason': cancelReason,
        'contractPath': contractPath,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory Transaction.fromMap(Map<String, dynamic> m) => Transaction(
        id: m['id'],
        agencyId: m['agencyId'],
        ref: m['ref'],
        propertyId: m['propertyId'],
        clientId: m['clientId'],
        clientName: m['clientName'],
        agentId: m['agentId'],
        dealType: DealType.values.byName(m['dealType']),
        amount: (m['amount'] as num).toDouble(),
        commissionRate: (m['commissionRate'] as num).toDouble(),
        commissionAmount: (m['commissionAmount'] as num).toDouble(),
        status: TransactionStatus.values.byName(m['status']),
        startDate: m['startDate'],
        signedAt: m['signedAt'],
        endDate: m['endDate'],
        cancelReason: m['cancelReason'],
        contractPath: m['contractPath'],
        createdAt: m['createdAt'],
        updatedAt: m['updatedAt'],
      );
}
