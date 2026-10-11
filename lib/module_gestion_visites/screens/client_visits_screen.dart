import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/core/widgets/message_banner.dart';
import 'package:immora_mobile/core/widgets/primary_button.dart';
import 'package:immora_mobile/module_authentification/providers/auth_provider.dart';
import 'package:immora_mobile/module_gestion_visites/models/visit_details.dart';
import 'package:immora_mobile/module_gestion_annonces/providers/matching_provider.dart';
import 'package:immora_mobile/module_gestion_visites/providers/visit_provider.dart';
import 'package:immora_mobile/module_gestion_visites/screens/visit_detail_screen.dart';
import 'package:immora_mobile/module_gestion_annonces/widgets/segmented_control.dart';
import 'package:immora_mobile/module_gestion_visites/widgets/visit_list_row.dart';

/// « Mes visites » (M6 · maquette Figma) — onglet du client : visites à venir
/// (demandées ou confirmées) et passées (effectuées, absentes, annulées).
class ClientVisitsScreen extends StatefulWidget {
  const ClientVisitsScreen({super.key, this.onExplore});

  /// Renvoie vers l'onglet Recherche quand le client n'a aucune visite.
  final VoidCallback? onExplore;

  @override
  State<ClientVisitsScreen> createState() => _ClientVisitsScreenState();
}

class _ClientVisitsScreenState extends State<ClientVisitsScreen> {
  int _tab = 0; // 0 = à venir, 1 = passées

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final id = context.read<AuthProvider>().currentUser?.id;
      if (id == null) return;
      final visitProvider = context.read<VisitProvider>();
      final matching = context.read<MatchingProvider>();
      await visitProvider.loadForClient(id);
      // Une visite effectuée hors de cette session exclut le bien de « Pour vous ».
      await matching.refreshVisited();
    });
  }

  void _open(VisitDetails v) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VisitDetailScreen(details: v)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VisitProvider>();
    final upcoming = [
      for (final v in provider.visits)
        if (v.visit.isOpen) v,
    ]..sort((a, b) => a.visit.scheduledAt.compareTo(b.visit.scheduledAt));
    final past = [
      for (final v in provider.visits)
        if (!v.visit.isOpen) v,
    ]..sort((a, b) => b.visit.scheduledAt.compareTo(a.visit.scheduledAt));

    final shown = _tab == 0 ? upcoming : past;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, 'Mes visites'),
      body: RefreshIndicator(
        onRefresh: provider.reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (provider.errorMessage != null) ...[
              MessageBanner(type: BannerType.error, message: provider.errorMessage!),
              const SizedBox(height: 12),
            ],
            SegmentedControl(
              left: 'À venir · ${upcoming.length}',
              right: 'Passées · ${past.length}',
              selected: _tab,
              onSelect: (i) => setState(() => _tab = i),
            ),            const SizedBox(height: 14),
            if (provider.isLoading && provider.visits.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (shown.isEmpty) ...[
              WhiteCard(
                padding: const EdgeInsets.all(20),
                child: Text(
                  _tab == 0
                      ? 'Aucune visite à venir. Ouvrez une annonce publiée et '
                          'demandez une visite à l’agence.'
                      : 'Aucune visite passée pour l’instant.',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ),
              if (_tab == 0) ...[
                const SizedBox(height: 16),
                PrimaryButton(label: 'Explorer les annonces', onPressed: widget.onExplore),
              ],
            ] else
              WhiteCard(
                child: Column(children: [
                  for (var i = 0; i < shown.length; i++) ...[
                    if (i > 0) const Divider(height: 1, thickness: 1, color: AppColors.border),
                    VisitListRow(
                      details: shown[i],
                      subtitle: _subtitleOf(shown[i]),
                      onTap: () => _open(shown[i]),
                    ),
                  ],
                ]),
              ),
            const SizedBox(height: 16),
            const MessageBanner(
              type: BannerType.info,
              icon: Icons.notifications_none,
              message: 'Rappel automatique 24 h avant chaque visite (notification locale).',
            ),
          ],
        ),
      ),
    );
  }
}

/// Sous-titre d'une visite côté client : date, puis indication d'état.
String _subtitleOf(VisitDetails details) {
  final v = details.visit;
  final when = formatDateTimeShort(v.scheduledAt);
  return switch (v.status) {
    VisitStatus.requested => '$when · en attente',
    VisitStatus.confirmed => when,
    VisitStatus.done =>
      '${formatDayMonth(v.scheduledAt)} · ${v.isRated ? 'notée' : 'à noter'}',
    VisitStatus.absent => '${formatDayMonth(v.scheduledAt)} · vous étiez absent',
    VisitStatus.cancelled => '${formatDayMonth(v.scheduledAt)} · annulée',
  };
}
