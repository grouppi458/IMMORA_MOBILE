import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/constants.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/core/widgets/message_banner.dart';
import 'package:immora_mobile/core/widgets/primary_button.dart';
import 'package:immora_mobile/module_gestion_annonces/models/visit.dart';
import 'package:immora_mobile/module_gestion_annonces/models/visit_details.dart';
import 'package:immora_mobile/module_gestion_annonces/providers/visit_provider.dart';
import 'package:immora_mobile/module_gestion_annonces/screens/listing_detail_screen.dart';
import 'package:immora_mobile/module_gestion_annonces/screens/visit_done_screen.dart';
import 'package:immora_mobile/module_gestion_annonces/widgets/listing_map.dart';
import 'package:immora_mobile/module_gestion_annonces/widgets/visit_hero.dart';

/// « Visite » côté client (M6 · maquette Figma) : suivi chronologique,
/// informations pratiques, carte et actions (annuler, noter, voir le bien).
class VisitDetailScreen extends StatefulWidget {
  const VisitDetailScreen({super.key, required this.details});

  final VisitDetails details;

  @override
  State<VisitDetailScreen> createState() => _VisitDetailScreenState();
}

class _VisitDetailScreenState extends State<VisitDetailScreen> {
  /// La visite relue depuis le provider pour rester à jour après une action.
  VisitDetails get _details {
    final id = widget.details.visit.id;
    final visits = context.watch<VisitProvider>().visits;
    if (id == null) return widget.details;
    return visits.firstWhere((v) => v.visit.id == id, orElse: () => widget.details);
  }

  Future<void> _cancel(VisitDetails d) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la visite ?'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Motif transmis à ${d.agencyName}.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Retour')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (!mounted || reason == null || reason.isEmpty) return;
    final error = await context.read<VisitProvider>().cancel(
          d.visit.id!,
          reason: reason,
          byClient: true,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: error == null ? AppColors.success : AppColors.error,
      content: Text(error ?? 'Visite annulée.'),
    ));
  }

  void _openListing(VisitDetails d) {
    final listingId = d.visit.listingId;
    if (listingId == null) return;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => ListingDetailScreen(listingId: listingId)));
  }

  Future<void> _openRate(VisitDetails d) async {
    final rated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => VisitDoneScreen(details: d)),
    );
    if (!mounted || rated != true) return;
    await context.read<VisitProvider>().reload();
  }

  @override
  Widget build(BuildContext context) {
    final d = _details;
    final v = d.visit;
    final status = v.status;
    final open = v.isOpen;
    final place = d.district.isEmpty ? d.city : d.district;
    final label = d.propertyType.shortLabel(d.rooms);
    final badgeTone = switch (status) {
      VisitStatus.requested => toneGold,
      VisitStatus.confirmed => toneBlue,
      VisitStatus.done => toneGreen,
      VisitStatus.absent => toneGrey,
      VisitStatus.cancelled => toneRed,
    };

    final reminderAt = DateTime.fromMillisecondsSinceEpoch(v.scheduledAt)
        .subtract(const Duration(hours: visitReminderHours));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, 'Visite'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // En-tête : bien, statut et date.
        VisitHero(
          title: place.isEmpty ? label : '$label · $place',
          statusLabel: status.label,
          statusTone: badgeTone,
          dateText: formatDateTimeShort(v.scheduledAt),
        ),
        const SizedBox(height: 14),
        // Suivi chronologique.
        WhiteCard(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Suivi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            for (final (index, step) in _steps(v).indexed)
              _TimelineRow(
                step: step,
                isLast: index == _steps(v).length - 1,
              ),
          ]),
        ),
        const SizedBox(height: 14),
        // Informations pratiques.
        WhiteCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            InfoRow('Adresse', d.location),
            const Divider(height: 1, color: AppColors.border),
            const InfoRow('Durée', '$visitDurationMinutes min'),
            const Divider(height: 1, color: AppColors.border),
            InfoRow('Agent', d.agentName ?? d.agencyName),
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                const Text('Statut',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                const Spacer(),
                StatusBadge(status.label, badgeTone),
              ]),
            ),
            if (v.isRated) ...[
              const Divider(height: 1, color: AppColors.border),
              InfoRow('Ma note', '${v.rating} / $visitRatingMax'),
            ],
            if (v.cancelReason != null && v.cancelReason!.isNotEmpty) ...[
              const Divider(height: 1, color: AppColors.border),
              InfoRow('Motif', v.cancelReason!),
            ],
          ]),
        ),
        const SizedBox(height: 14),
        VisitLocationMap(
          latitude: d.latitude,
          longitude: d.longitude,
          label: d.location,
        ),
        if (status == VisitStatus.confirmed && reminderAt.isAfter(DateTime.now())) ...[
          const SizedBox(height: 14),
          MessageBanner(
            type: BannerType.info,
            icon: Icons.notifications_none,
            message: 'Rappel programmé le '
                '${formatDateLong(reminderAt.millisecondsSinceEpoch)} à '
                '${formatTime(reminderAt.millisecondsSinceEpoch)}.',
          ),
        ],
        const SizedBox(height: 8),
      ]),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(children: [
              if (open) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _cancel(d),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: const StadiumBorder(),
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Text('Annuler',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              if (status == VisitStatus.done) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: v.listingId == null ? null : () => _openListing(d),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.border),
                      shape: const StadiumBorder(),
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Text('Voir le bien',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: status == VisitStatus.done
                    ? PrimaryButton(
                        label: v.isRated ? 'Modifier ma note' : 'Noter cette visite',
                        onPressed: () => _openRate(d),
                      )
                    : FilledButton(
                        onPressed: v.listingId == null ? null : () => _openListing(d),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.infoBg,
                          foregroundColor: AppColors.primary,
                          shape: const StadiumBorder(),
                          minimumSize: const Size.fromHeight(50),
                          textStyle:
                              const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        child: const Text('Voir le bien'),
                      ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  List<_Step> _steps(Visit visit) {
    String stamp(int millis) =>
        '${formatDayMonth(millis)} · ${formatTime(millis)}';
    final scheduledEnd = visit.scheduledAt + visitDurationMinutes * 60 * 1000;

    final steps = <_Step>[
      _Step('Demandée', stamp(visit.createdAt), StepState.done),
    ];
    switch (visit.status) {
      case VisitStatus.requested:
        steps.add(const _Step('Confirmée par l’agence', '—', StepState.pending));
        steps.add(_Step('Visite',
            '${formatDayMonth(visit.scheduledAt)} · '
                '${formatTime(visit.scheduledAt)} – ${formatTime(scheduledEnd)}',
            StepState.current));
        steps.add(const _Step('Effectuée', '—', StepState.pending));
      case VisitStatus.confirmed:
        steps.add(_Step('Confirmée par l’agence',
            stamp(visit.decidedAt ?? visit.updatedAt), StepState.done));
        steps.add(_Step('Visite',
            '${formatDayMonth(visit.scheduledAt)} · '
                '${formatTime(visit.scheduledAt)} – ${formatTime(scheduledEnd)}',
            StepState.current));
        steps.add(const _Step('Effectuée', '—', StepState.pending));
      case VisitStatus.done:
        steps.add(_Step('Confirmée par l’agence',
            stamp(visit.decidedAt ?? visit.updatedAt), StepState.done));
        steps.add(_Step('Visite',
            '${formatDayMonth(visit.scheduledAt)} · '
                '${formatTime(visit.scheduledAt)} – ${formatTime(scheduledEnd)}',
            StepState.done));
        steps.add(_Step('Effectuée', stamp(visit.doneAt ?? visit.updatedAt), StepState.done));
      case VisitStatus.absent:
        steps.add(_Step('Confirmée par l’agence',
            stamp(visit.decidedAt ?? visit.updatedAt), StepState.done));
        steps.add(_Step('Visite',
            '${formatDayMonth(visit.scheduledAt)} · '
                '${formatTime(visit.scheduledAt)} – ${formatTime(scheduledEnd)}',
            StepState.done));
        steps.add(_Step('Absent', stamp(visit.decidedAt ?? visit.updatedAt), StepState.red));
      case VisitStatus.cancelled:
        steps.add(_Step('Annulée', stamp(visit.decidedAt ?? visit.updatedAt), StepState.red));
    }
    return steps;
  }
}

enum StepState { done, current, pending, red }

class _Step {
  const _Step(this.title, this.subtitle, this.state);

  final String title;
  final String subtitle;
  final StepState state;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.step, required this.isLast});

  final _Step step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData? icon) = switch (step.state) {
      StepState.done => (AppColors.primary, Colors.white, Icons.check),
      StepState.current => (AppColors.primary, Colors.white, Icons.schedule),
      StepState.pending => (Colors.white, AppColors.textMuted, null),
      StepState.red => (AppColors.error, Colors.white, Icons.close),
    };
    final lineColor = switch (step.state) {
      StepState.pending => AppColors.border,
      StepState.red => AppColors.error,
      _ => AppColors.primary,
    };
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Column(children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(
                  color: step.state == StepState.pending ? AppColors.border : bg, width: 1.5),
            ),
            child: icon == null ? null : Icon(icon, size: 16, color: fg),
          ),
          if (!isLast)
            Expanded(child: Container(width: 2, color: lineColor)),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(step.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: switch (step.state) {
                    StepState.pending => AppColors.textMuted,
                    StepState.red => AppColors.error,
                    _ => AppColors.textDark,
                  },
                )),
            const SizedBox(height: 2),
            Text(step.subtitle,
                style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
            const SizedBox(height: 14),
          ]),
        ),
      ]),
    );
  }
}
