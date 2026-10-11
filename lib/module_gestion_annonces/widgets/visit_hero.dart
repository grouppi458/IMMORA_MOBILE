import 'package:flutter/material.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';

/// En-tête bleu marine d'une visite (maquettes « Visite », « Visite
/// effectuée », « Visite #… ») : bien, badge de statut et date en grand.
class VisitHero extends StatelessWidget {
  const VisitHero({
    super.key,
    required this.title,
    required this.statusLabel,
    required this.statusTone,
    required this.dateText,
  });

  final String title;
  final String statusLabel;
  final Tone statusTone;
  final String dateText;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 15),
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge(statusLabel, statusTone),
        ]),
        const SizedBox(height: 10),
        Text(dateText,
            style: const TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
