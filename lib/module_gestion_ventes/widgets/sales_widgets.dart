import 'package:flutter/material.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';

/// Badges ambre « Medium » / « En retard » (texte ambre foncé).
const Tone toneAmber = (AppColors.warningBg, AppColors.warning);

Tone toneForTransactionStatus(TransactionStatus s) => switch (s) {
      TransactionStatus.draft => toneGrey,
      TransactionStatus.ongoing => toneGold,
      TransactionStatus.signed => toneBlue,
      TransactionStatus.completed => toneGreen,
      TransactionStatus.cancelled => toneRed,
    };

Tone toneForPaymentStatus(PaymentStatus s) => switch (s) {
      PaymentStatus.pending => toneGold,
      PaymentStatus.paid => toneGreen,
      PaymentStatus.late => toneRed,
    };

Tone toneForAlertSeverity(AlertSeverity s) => switch (s) {
      AlertSeverity.low => toneBlue,
      AlertSeverity.medium => toneAmber,
      AlertSeverity.high => toneRed,
    };

/// Couleur de l'accent (bord gauche de la carte, maquette « Alerte »).
Color colorForAlertSeverity(AlertSeverity s) => switch (s) {
      AlertSeverity.low => AppColors.primary,
      AlertSeverity.medium => AppColors.warning,
      AlertSeverity.high => AppColors.error,
    };

/// Étiquette du bien : étiquette de vente ou clé de location.
IconData iconForDealType(DealType d) =>
    d == DealType.sale ? Icons.sell_outlined : Icons.vpn_key_outlined;

IconData iconForPaymentStatus(PaymentStatus s) => switch (s) {
      PaymentStatus.paid => Icons.check,
      PaymentStatus.late => Icons.warning_amber_rounded,
      PaymentStatus.pending => Icons.schedule,
    };

/// Icône de la tuile d'une alerte selon son type (maquette « Alertes »).
IconData iconForAlertType(AlertType t) => switch (t) {
      AlertType.amountOutlier => Icons.warning_amber_rounded,
      AlertType.priceGap => Icons.change_history,
      AlertType.agentActivity => Icons.monitor_heart_outlined,
      AlertType.paymentMismatch => Icons.error_outline,
      AlertType.paymentLate => Icons.schedule,
    };

/// Sélecteur à segments « Toutes | Ventes | Locations » (généralisé à N
/// options) — pastille bleu marine sur fond blanc.
class SegmentToggle<T> extends StatelessWidget {
  const SegmentToggle({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        for (final (value, label) in options)
          Expanded(
            child: Material(
              color: value == selected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => onSelect(value),
                child: Container(
                  height: 40,
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: value == selected ? FontWeight.w700 : FontWeight.w500,
                      color: value == selected ? Colors.white : AppColors.textDark,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Tuile d'icône carrée arrondie des lignes de liste (transactions, alertes).
class IconTile extends StatelessWidget {
  const IconTile(this.icon, this.tone, {super.key, this.size = 44});

  final IconData icon;
  final Tone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: tone.$1, borderRadius: BorderRadius.circular(size / 4)),
      child: Icon(icon, color: tone.$2, size: size * 0.46),
    );
  }
}
