import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/module_gestion_ventes/models/transaction.dart';

/// Transaction + bien joint (listes, détail, formulaire de paiement).
class TransactionDetails {
  final Transaction transaction;
  final String propertyTitle;
  final PropertyType propertyType;
  final double propertyPrice; // prix affiché (contrôle « Prix final »)
  final String? agentName;

  TransactionDetails({
    required this.transaction,
    required this.propertyTitle,
    required this.propertyType,
    required this.propertyPrice,
    this.agentName,
  });

  /// « #1042 · Villa avec piscine · Gammarth ».
  String get displayTitle => '${transaction.displayRef} · $propertyTitle';
}
