import 'package:flutter/material.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/module_gestion_annonces/models/visit_details.dart';

/// Ligne d'une visite dans une liste (M6) : icône teintée selon le statut,
/// titre court, sous-titre libre et badge de statut.
class VisitListRow extends StatelessWidget {
  const VisitListRow({super.key, required this.details, required this.subtitle, this.onTap});

  final VisitDetails details;
  final String subtitle;
  final VoidCallback? onTap;

  (IconData, Tone) _visual(VisitStatus s) => switch (s) {
        VisitStatus.requested => (Icons.schedule, toneGold),
        VisitStatus.confirmed => (Icons.event_available_outlined, toneBlue),
        VisitStatus.done => (Icons.check, toneGreen),
        VisitStatus.absent => (Icons.person_outline, toneGrey),
        VisitStatus.cancelled => (Icons.cancel_outlined, toneRed),
      };

  Tone badgeTone(VisitStatus s) => switch (s) {
        VisitStatus.requested => toneGold,
        VisitStatus.confirmed => toneBlue,
        VisitStatus.done => toneGreen,
        VisitStatus.absent => toneGrey,
        VisitStatus.cancelled => toneRed,
      };

  @override
  Widget build(BuildContext context) {
    final (icon, tone) = _visual(details.visit.status);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(color: tone.$1, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: tone.$2, size: 24),
      ),
      title: Text(details.shortTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(subtitle,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.3)),
      ),
      trailing: StatusBadge(details.visit.status.label, badgeTone(details.visit.status)),
    );
  }
}
