import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/constants.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/core/widgets/message_banner.dart';
import 'package:immora_mobile/module_gestion_visites/models/visit_details.dart';
import 'package:immora_mobile/module_gestion_visites/providers/visit_provider.dart';
import 'package:immora_mobile/module_gestion_visites/repositories/visit_repository.dart';
import 'package:immora_mobile/module_gestion_visites/screens/agent_visit_detail_screen.dart';
import 'package:immora_mobile/module_gestion_annonces/widgets/segmented_control.dart';

/// « Calendrier des visites » (M6 · maquette Figma) — côté agence et agent :
/// mois avec pastilles or, visites du jour et traitement des demandes
/// (confirmer, refuser, reprogrammer) sans quitter l'écran.
/// [agentUserId] non null = agent connecté : « Mes visites » / « Toute l'agence ».
class VisitCalendarScreen extends StatefulWidget {
  const VisitCalendarScreen({super.key, required this.agencyId, this.agentUserId});

  final int agencyId;
  final int? agentUserId;

  @override
  State<VisitCalendarScreen> createState() => _VisitCalendarScreenState();
}

class _VisitCalendarScreenState extends State<VisitCalendarScreen> {
  int _scope = 0; // agent : 0 = mes visites, 1 = toute l'agence
  int? _agentId; // agents.id du compte agent
  late DateTime _month; // premier jour du mois affiché
  late DateTime _selected; // jour sélectionné
  VisitStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final provider = context.read<VisitProvider>();
    final userId = widget.agentUserId;
    if (userId != null) _agentId ??= await VisitRepository().agentIdForUser(userId);
    final agentId = widget.agentUserId == null
        ? null
        : (_scope == 0 ? _agentId : null);
    await provider.loadForAgency(widget.agencyId, agentId: agentId);
  }

  void _switchScope(int scope) {
    if (_scope == scope) return;
    setState(() => _scope = scope);
    _load();
  }

  Future<void> _changeMonth(int delta) async {
    final month = DateTime(_month.year, _month.month + delta);
    setState(() {
      _month = month;
      if (_selected.year != month.year || _selected.month != month.month) {
        _selected = month;
      }
    });
  }

  // ---------------------------------------------------------------- Actions

  Future<void> _confirm(VisitDetails v) =>
      _run(() => context.read<VisitProvider>().confirm(v.visit.id!), 'Visite confirmée.');

  Future<void> _refuse(VisitDetails v) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Refuser la demande ?',
      message: '« ${v.displayTitle} » : ${v.clientName} sera notifié et pourra '
          'proposer un autre créneau.',
      confirmLabel: 'Refuser',
    );
    if (!mounted || !confirmed) return;
    await _run(
      () => context.read<VisitProvider>().cancel(v.visit.id!,
          reason: 'créneau refusé par l’agence'),
      'Demande refusée, le client est notifié.',
    );
  }

  Future<void> _run(Future<String?> Function() action, String done) async {
    final error = await action();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: error == null ? AppColors.success : AppColors.error,
      content: Text(error ?? done),
    ));
  }

  Future<void> _pickFilter() async {
    final choice = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            const Text('Filtrer par statut',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _filterChip(ctx, 'Toutes', _statusFilter == null, 'all'),
              for (final s in VisitStatus.values)
                _filterChip(ctx, s.label, _statusFilter == s, s),
            ]),
          ]),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    setState(() => _statusFilter = choice is VisitStatus ? choice : null);
  }

  Widget _filterChip(BuildContext ctx, String label, bool selected, Object value) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => Navigator.of(ctx).pop(value),
      selectedColor: AppColors.infoBg,
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? AppColors.infoBg : AppColors.border),
      labelStyle: TextStyle(
        fontSize: 13,
        color: AppColors.textDark,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  void _open(VisitDetails v) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AgentVisitDetailScreen(details: v)),
    );
  }

  // ---------------------------------------------------------------- Affichage

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VisitProvider>();
    final all = provider.agencyId == widget.agencyId ? provider.visits : <VisitDetails>[];
    final byDay = <DateTime, List<VisitDetails>>{};
    for (final v in all) {
      final d = DateTime.fromMillisecondsSinceEpoch(v.visit.scheduledAt);
      byDay.putIfAbsent(DateTime(d.year, d.month, d.day), () => []).add(v);
    }
    for (final list in byDay.values) {
      list.sort((a, b) => a.visit.scheduledAt.compareTo(b.visit.scheduledAt));
    }
    final dayVisits = (byDay[_selected] ?? const <VisitDetails>[])
        .where((v) => _statusFilter == null || v.visit.status == _statusFilter)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, 'Calendrier des visites', actions: [
        IconButton(
          tooltip: 'Filtrer par statut',
          icon: Icon(Icons.filter_alt_outlined,
              color: _statusFilter == null ? Colors.white : AppColors.sand),
          onPressed: _pickFilter,
        ),
      ]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (widget.agentUserId != null) ...[
              SegmentedControl(
                left: 'Mes visites',
                right: 'Toute l’agence',
                selected: _scope,
                onSelect: _switchScope,
              ),
              const SizedBox(height: 12),
            ],
            if (provider.errorMessage != null && !provider.isLoading) ...[
              MessageBanner(type: BannerType.error, message: provider.errorMessage!),
              const SizedBox(height: 12),
            ],
            WhiteCard(
              padding: const EdgeInsets.all(12),
              child: _MonthCalendar(
                month: _month,
                selected: _selected,
                daysWithVisits: {for (final d in byDay.keys) if (byDay[d]!.isNotEmpty) d},
                onPrev: () => _changeMonth(-1),
                onNext: () => _changeMonth(1),
                onSelect: (d) => setState(() => _selected = d),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: Text(dayTitle(_selected),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
              Text('${dayVisits.length} visite${dayVisits.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ]),
            const SizedBox(height: 10),
            if (provider.isLoading && all.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (dayVisits.isEmpty)
              const WhiteCard(
                padding: EdgeInsets.all(20),
                child: Text('Aucune visite ce jour.',
                    style: TextStyle(color: AppColors.textMuted)),
              )
            else
              for (final v in dayVisits) ...[
                if (v.visit.status == VisitStatus.requested)
                  _RequestCard(
                    details: v,
                    onConfirm: () => _confirm(v),
                    onRefuse: () => _refuse(v),
                  )
                else
                  _DayVisitCard(details: v, onTap: () => _open(v)),
                const SizedBox(height: 10),
              ],
            const SizedBox(height: 6),
            const MessageBanner(
              type: BannerType.info,
              icon: Icons.notifications_none,
              message: 'Un agent ne peut pas avoir deux visites au même créneau. '
                  'Un rappel local est envoyé 24 h avant chaque visite.',
            ),
          ],
        ),
      ),
    );
  }
}

/// Grille du mois : flèches, pastilles or et jour sélectionné.
class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.selected,
    required this.daysWithVisits,
    required this.onPrev,
    required this.onNext,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime selected;
  final Set<DateTime> daysWithVisits;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month);
    final leading = firstDay.weekday - 1; // lundi = 1
    final dayCount = DateTime(month.year, month.month + 1, 0).day;
    final today = DateTime.now();

    return Column(children: [
      Row(children: [
        IconButton(
          tooltip: 'Mois précédent',
          onPressed: onPrev,
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
        ),
        Expanded(
          child: Text(monthTitle(month),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ),
        IconButton(
          tooltip: 'Mois suivant',
          onPressed: onNext,
          icon: const Icon(Icons.arrow_forward, color: AppColors.textDark),
        ),
      ]),
      Row(
        children: [
          for (final label in const ['L', 'M', 'M', 'J', 'V', 'S', 'D'])
            Expanded(
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
            ),
        ],
      ),
      const SizedBox(height: 6),
      GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.15,
        children: [
          for (var i = 0; i < leading; i++) const SizedBox(),
          for (var day = 1; day <= dayCount; day++)
            _DayCell(
              date: DateTime(month.year, month.month, day),
              selected: _sameDay(selected, month, day),
              isToday: _sameDay(today, month, day),
              hasVisits: daysWithVisits.contains(DateTime(month.year, month.month, day)),
              onTap: onSelect,
            ),
        ],
      ),
    ]);
  }

  static bool _sameDay(DateTime d, DateTime month, int day) =>
      d.year == month.year && d.month == month.month && d.day == day;
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.selected,
    required this.isToday,
    required this.hasVisits,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool isToday;
  final bool hasVisits;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(date),
      behavior: HitTestBehavior.opaque,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : isToday
                      ? AppColors.gold
                      : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Text('${date.day}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textDark,
              )),
        ),
        const SizedBox(height: 3),
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasVisits ? AppColors.gold : Colors.transparent,
          ),
        ),
      ]),
    );
  }
}

/// Visite d'un jour (non demandée) : icône teintée, heure · bien, client.
class _DayVisitCard extends StatelessWidget {
  const _DayVisitCard({required this.details, required this.onTap});

  final VisitDetails details;
  final VoidCallback onTap;

  (IconData, Tone) _visual(VisitStatus s) => switch (s) {
        VisitStatus.requested => (Icons.schedule, toneGold),
        VisitStatus.confirmed => (Icons.event_available_outlined, toneBlue),
        VisitStatus.done => (Icons.check, toneGreen),
        VisitStatus.absent => (Icons.person_outline, toneGrey),
        VisitStatus.cancelled => (Icons.cancel_outlined, toneRed),
      };

  Tone _badgeTone(VisitStatus s) => switch (s) {
        VisitStatus.requested => toneGold,
        VisitStatus.confirmed => toneBlue,
        VisitStatus.done => toneGreen,
        VisitStatus.absent => toneGrey,
        VisitStatus.cancelled => toneRed,
      };

  @override
  Widget build(BuildContext context) {
    final (icon, tone) = _visual(details.visit.status);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: tone.$1, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: tone.$2, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  '${formatTime(details.visit.scheduledAt)} · ${details.shortTitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  '${details.clientName} · $visitDurationMinutes min',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            StatusBadge(details.visit.status.label, _badgeTone(details.visit.status)),
          ]),
        ),
      ),
    );
  }
}

/// Demande en attente : bordure or, note du client et actions immédiates.
class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.details, required this.onConfirm, required this.onRefuse});

  final VisitDetails details;
  final VoidCallback onConfirm;
  final VoidCallback onRefuse;

  @override
  Widget build(BuildContext context) {
    final v = details.visit;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 4, color: AppColors.gold),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      '${formatTime(v.scheduledAt)} · ${details.shortTitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const StatusBadge('Demandée', toneGold),
                ]),
                if (v.clientNote != null && v.clientNote!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('${details.clientName} : « ${v.clientNote} »',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.35)),
                ],
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onRefuse,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        shape: const StadiumBorder(),
                        minimumSize: const Size.fromHeight(44),
                      ),
                      child: const Text('Refuser',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: onConfirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: const StadiumBorder(),
                        minimumSize: const Size.fromHeight(44),
                        textStyle: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Confirmer'),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
