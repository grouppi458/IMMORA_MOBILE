import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/constants.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/core/widgets/message_banner.dart';
import 'package:immora_mobile/core/widgets/primary_button.dart';
import 'package:immora_mobile/module_gestion_visites/models/visit_details.dart';
import 'package:immora_mobile/module_gestion_visites/providers/visit_provider.dart';
import 'package:immora_mobile/module_gestion_visites/widgets/visit_hero.dart';
import 'package:immora_mobile/module_gestion_visites/widgets/visit_slot_picker.dart';
import 'package:immora_mobile/module_gestion_ventes/screens/transaction_form_screen.dart';

/// « Visite #… » côté agent (M6 · maquette Figma) : coordonnées du client,
/// changement de statut (effectuée, absent, annulée…), compte rendu interne
/// et note laissée par le client.
class AgentVisitDetailScreen extends StatefulWidget {
  const AgentVisitDetailScreen({super.key, required this.details});

  final VisitDetails details;

  @override
  State<AgentVisitDetailScreen> createState() => _AgentVisitDetailScreenState();
}

class _AgentVisitDetailScreenState extends State<AgentVisitDetailScreen> {
  late final _noteCtrl = TextEditingController(text: widget.details.visit.agentNote ?? '');
  bool _savingNote = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  VisitDetails get _details {
    final id = widget.details.visit.id;
    final visits = context.watch<VisitProvider>().visits;
    if (id == null) return widget.details;
    return visits.firstWhere((v) => v.visit.id == id, orElse: () => widget.details);
  }

  bool get _noteDirty => _noteCtrl.text.trim() != (widget.details.visit.agentNote ?? '');

  /// « Créer une transaction » : le formulaire M4 s'ouvre pré-rempli avec le
  /// bien visité, le client et le type d'affaire de la visite.
  Future<void> _openTransaction() async {
    final d = _details;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TransactionFormScreen(
              agencyId: d.visit.agencyId,
              initialProperty: (d.visit.propertyId, d.propertyTitle, d.price),
              initialClientName: d.clientName,
              initialDealType: d.dealType,
            )));
  }

  Future<void> _setStatus(VisitStatus target) async {
    final d = _details;
    final provider = context.read<VisitProvider>();
    if (d.visit.status == target && target != VisitStatus.cancelled) return;
    final Future<String?> result = switch (target) {
      VisitStatus.confirmed => provider.confirm(d.visit.id!),
      VisitStatus.done => provider.markDone(d.visit.id!),
      VisitStatus.absent => provider.markAbsent(d.visit.id!),
      VisitStatus.cancelled => _cancel(d),
      VisitStatus.requested => Future.value(null),
    };
    final error = await result;
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.error, content: Text(error)),
      );
    } else if (target != VisitStatus.requested) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.success,
        content: Text('Statut : ${target.label.toLowerCase()}'
            '${target == VisitStatus.cancelled ? ', le client est notifié.' : '.'}'),
      ));
    }
  }

  Future<String?> _cancel(VisitDetails d) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Annuler la visite ?',
      message: '« ${d.displayTitle} » : ${d.clientName} sera notifié du motif.',
      confirmLabel: 'Annuler la visite',
    );
    if (!mounted || !confirmed) return null; // refusé par l'agent, pas une erreur
    return context
        .read<VisitProvider>()
        .cancel(d.visit.id!, reason: 'indisponibilité de l’agence');
  }

  Future<void> _reschedule(VisitDetails d) async {
    DateTime? slot;
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
          Text('Reprogrammer la visite de ${d.clientName}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          VisitSlotPicker(
            initial: DateTime.fromMillisecondsSinceEpoch(d.visit.scheduledAt),
            onChanged: (s) => slot = s,
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Valider ce créneau',
            onPressed: () {
              if (slot == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Choisissez une date et un horaire à venir.')));
                return;
              }
              Navigator.of(ctx).pop(slot);
            },
          ),
        ]),
      ),
    );
    if (!mounted || picked == null) return;
    final error =
        await context.read<VisitProvider>().reschedule(d.visit.id!, picked);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: error == null ? AppColors.success : AppColors.error,
      content: Text(error ?? 'Visite reprogrammée, le client est notifié.'),
    ));
  }

  Future<void> _saveNote() async {
    if (!_noteDirty || _savingNote) return;
    setState(() => _savingNote = true);
    final error =
        await context.read<VisitProvider>().saveAgentNote(widget.details.visit.id!, _noteCtrl.text);
    if (!mounted) return;
    setState(() => _savingNote = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: error == null ? AppColors.success : AppColors.error,
      content: Text(error ?? 'Compte rendu enregistré.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final d = _details;
    final v = d.visit;
    final badgeTone = switch (v.status) {
      VisitStatus.requested => toneGold,
      VisitStatus.confirmed => toneBlue,
      VisitStatus.done => toneGreen,
      VisitStatus.absent => toneGrey,
      VisitStatus.cancelled => toneRed,
    };
    final phone = d.clientPhone;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, 'Visite #${v.id}'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        VisitHero(
          title: d.shortTitle,
          statusLabel: v.status.label,
          statusTone: badgeTone,
          dateText: formatDateTimeShort(v.scheduledAt),
        ),
        const SizedBox(height: 14),
        WhiteCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            InfoRow('Client', d.clientName),
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(children: [
                const Text('Téléphone',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                const Spacer(),
                Text(phone == null || phone.isEmpty ? '—' : phone,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                if (phone != null && phone.isNotEmpty)
                  IconButton(
                    tooltip: 'Copier le téléphone',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.copy, size: 16, color: AppColors.primary),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: phone));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('$phone copié.')));
                      }
                    },
                  ),
              ]),
            ),
            const Divider(height: 1, color: AppColors.border),
            InfoRow('Agent', d.agentName ?? d.agencyName),
            const Divider(height: 1, color: AppColors.border),
            const InfoRow('Durée', '$visitDurationMinutes min'),
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                const Text('Statut',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                const Spacer(),
                StatusBadge(v.status.label, badgeTone),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        const Text('Changer le statut',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in const [
            VisitStatus.confirmed,
            VisitStatus.done,
            VisitStatus.absent,
            VisitStatus.cancelled,
          ])
            ChoiceChip(
              label: Text(switch (s) {
                VisitStatus.absent => 'Absent (no-show)',
                _ => s.label,
              }),
              selected: v.status == s,
              showCheckmark: false,
              onSelected: (_) => _setStatus(s),
              selectedColor: AppColors.infoBg,
              backgroundColor: Colors.white,
              side: BorderSide(color: v.status == s ? AppColors.infoBg : AppColors.border),
              labelStyle: TextStyle(
                fontSize: 13,
                color: AppColors.textDark,
                fontWeight: v.status == s ? FontWeight.w700 : FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
        ]),
        if (v.isOpen) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _reschedule(d),
            icon: const Icon(Icons.event_repeat, size: 18),
            label: const Text('Reprogrammer'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.border),
              shape: const StadiumBorder(),
              minimumSize: const Size.fromHeight(44),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(children: [
          const Expanded(
            child: Text('Note de l’agent',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: _noteDirty && !_savingNote ? _saveNote : null,
            child: Text(_savingNote ? 'Enregistrement…' : 'Enregistrer',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ]),
        TextField(
          controller: _noteCtrl,
          maxLines: 3,
          maxLength: visitNoteMaxLength,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Compte rendu interne : intérêt du client, points à suivre…',
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13.5),
            filled: true,
            fillColor: Colors.white,
            counterText: '',
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text('Note du client',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        WhiteCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              for (var i = 1; i <= visitRatingMax; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    i <= (v.rating ?? 0) ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 26,
                    color: i <= (v.rating ?? 0)
                        ? AppColors.gold
                        : AppColors.textMuted.withValues(alpha: 0.55),
                  ),
                ),
              const SizedBox(width: 8),
              Text(v.isRated ? '${v.rating} / $visitRatingMax' : 'pas encore notée',
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
            ]),
            if (v.ratingComment != null && v.ratingComment!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('« ${v.ratingComment} »',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
            ],
          ]),
        ),
        const SizedBox(height: 14),
        const MessageBanner(
          type: BannerType.info,
          message: 'Une visite « effectuée » peut démarrer une transaction.',
        ),
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
            child: PrimaryButton(
              color: AppColors.gold,
              icon: Icons.swap_horiz,
              label: 'Créer une transaction',
              onPressed: _openTransaction,
            ),
          ),
        ),
      ),
    );
  }
}
