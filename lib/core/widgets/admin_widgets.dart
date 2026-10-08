import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/module_gestion_agences/models/agency_views.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';

/// Barre du haut bleu marine des écrans admin.
/// [close] = true affiche une croix (formulaires) au lieu de la flèche retour.
PreferredSizeWidget adminAppBar(
  BuildContext context,
  String title, {
  List<Widget>? actions,
  bool close = false,
}) {
  return AppBar(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    systemOverlayStyle: SystemUiOverlayStyle.light,
    // Collé à la flèche / croix quand il y en a une, sinon marge normale (onglets).
    titleSpacing: close || Navigator.of(context).canPop() ? 0 : 16,
    leading: close
        ? IconButton(
            tooltip: 'Fermer',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).maybePop(),
          )
        : null,
    title: Text(
      title,
      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
    ),
    actions: actions,
  );
}

/// Couleurs (fond, texte) d'un badge ou d'un avatar.
typedef Tone = (Color bg, Color fg);

const Tone toneBlue = (AppColors.infoBg, AppColors.primary);
const Tone toneGreen = (AppColors.successBg, AppColors.success);
const Tone toneRed = (AppColors.errorBg, AppColors.error);
const Tone toneGold = (Color(0xFFF6ECD6), AppColors.gold);
const Tone toneGrey = (Color(0xFFE6E8EC), Color(0xFF4B5563));
const Tone toneAgent = (Color(0xFFE3ECFB), Color(0xFF2F5FB3));

Tone toneForAgencyStatus(AgencyStatus s) => switch (s) {
      AgencyStatus.active => toneGreen,
      AgencyStatus.expired => toneRed,
      AgencyStatus.suspended => toneGrey,
    };

Tone toneForRole(UserRole r) => switch (r) {
      UserRole.admin => toneBlue,
      UserRole.agency => toneBlue,
      UserRole.agent => toneAgent,
      UserRole.client => toneGold,
      UserRole.owner => toneGrey,
    };

/// Pastille « • Active », « • Faible »…
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, this.tone, {super.key});

  final String label;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: tone.$1, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: tone.$2, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(color: tone.$2, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Carré arrondi avec les initiales (« CI » pour Carthage Immobilier).
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(this.name, {super.key, this.tone = toneBlue, this.size = 40, this.round = false});

  final String name;
  final Tone tone;
  final double size;
  final bool round;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tone.$1,
        borderRadius: round ? null : BorderRadius.circular(size / 4),
        shape: round ? BoxShape.circle : BoxShape.rectangle,
      ),
      child: Text(
        initialsOf(name),
        style: TextStyle(color: tone.$2, fontWeight: FontWeight.w700, fontSize: size * 0.32),
      ),
    );
  }
}

/// Carte blanche arrondie (fond des listes et des blocs).
class WhiteCard extends StatelessWidget {
  const WhiteCard({super.key, required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Bloc chiffré du tableau de bord : icône + libellé, valeur, légende.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
    this.valueColor = AppColors.primary,
    this.captionColor = AppColors.textMuted,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? caption;
  final Color valueColor;
  final Color captionColor;

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 15, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: valueColor)),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(caption!, style: TextStyle(fontSize: 12, color: captionColor)),
          ],
        ],
      ),
    );
  }
}

/// Rangée de filtres (puces) défilant horizontalement.
class FilterChipsRow<T> extends StatelessWidget {
  const FilterChipsRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final (value, label) in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: value == selected,
                showCheckmark: false,
                onSelected: (_) => onSelected(value),
                selectedColor: AppColors.infoBg,
                backgroundColor: Colors.white,
                side: BorderSide(
                    color: value == selected ? AppColors.infoBg : AppColors.border),
                labelStyle: TextStyle(
                  fontSize: 13,
                  color: AppColors.textDark,
                  fontWeight: value == selected ? FontWeight.w700 : FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Puces de choix unique dans un formulaire (plan, spécialité, rôle).
class ChoiceChipsField<T> extends StatelessWidget {
  const ChoiceChipsField({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<(T, String)> options;
  final T? selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textDark)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (value, text) in options)
              ChoiceChip(
                label: Text(text),
                selected: value == selected,
                showCheckmark: false,
                onSelected: (_) => onSelected(value),
                selectedColor: AppColors.infoBg,
                backgroundColor: Colors.white,
                side: BorderSide(
                    color: value == selected ? AppColors.infoBg : AppColors.border),
                labelStyle: TextStyle(
                  fontSize: 13,
                  color: AppColors.textDark,
                  fontWeight: value == selected ? FontWeight.w700 : FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
          ],
        ),
      ],
    );
  }
}

/// Bouton flottant or « + Nouvelle agence ».
class GoldFab extends StatelessWidget {
  const GoldFab({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: AppColors.gold,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: const StadiumBorder(),
      icon: const Icon(Icons.add),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

/// Histogramme des revenus des 6 derniers mois (dernier mois en or).
class RevenueBarChart extends StatelessWidget {
  const RevenueBarChart({super.key, required this.months, this.height = 120});

  final List<MonthRevenue> months;
  final double height;

  @override
  Widget build(BuildContext context) {
    final max = months.fold<double>(0, (m, e) => e.amount > m ? e.amount : m);
    return Column(
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < months.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Tooltip(
                      message: '${formatNumber(months[i].amount)} TND',
                      child: Container(
                        height: max == 0 ? 2 : (months[i].amount / max) * height + 2,
                        decoration: BoxDecoration(
                          color: i == months.length - 1 ? AppColors.gold : AppColors.primary,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final m in months)
              Expanded(
                child: Text(monthLabel(m.month),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ),
          ],
        ),
      ],
    );
  }
}

/// Boîte de confirmation (icône d'alerte, texte, Annuler / action).
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: danger ? AppColors.errorBg : AppColors.infoBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(danger ? Icons.warning_amber_rounded : Icons.info_outline,
                  color: danger ? AppColors.error : AppColors.primary),
            ),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4)),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  style: OutlinedButton.styleFrom(
                    shape: const StadiumBorder(),
                    side: const BorderSide(color: AppColors.border),
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: danger ? AppColors.error : AppColors.primary,
                    shape: const StadiumBorder(),
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: Text(confirmLabel),
                ),
              ),
            ]),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

/// Affiche les identifiants d'un compte qui vient d'être créé.
Future<void> showTemporaryPasswordDialog(
  BuildContext context, {
  required String email,
  required String password,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Compte créé'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Transmettez ces identifiants à l’utilisateur. Le mot de passe '
            'temporaire ne sera plus affiché.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          const Text('Email', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          SelectableText(email, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          const Text('Mot de passe temporaire',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          SelectableText(password,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: 1)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Clipboard.setData(ClipboardData(text: password)),
          child: const Text('Copier'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Terminé'),
        ),
      ],
    ),
  );
}

/// Ligne « libellé ……… valeur » d'une fiche.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// Ligne cliquable avec icône colorée, titre, sous-titre et chevron.
class NavTile extends StatelessWidget {
  const NavTile({
    super.key,
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Tone tone;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: tone.$1, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: tone.$2, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
    );
  }
}

/// Titre de section (« Activité faible », « Accès rapides »…).
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            child: Text(action!,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}
