import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/core/widgets/message_banner.dart';
import 'package:immora_mobile/module_authentification/providers/auth_provider.dart';
import 'package:immora_mobile/module_gestion_visites/models/visit_details.dart';
import 'package:immora_mobile/module_gestion_visites/providers/visit_provider.dart';
import 'package:immora_mobile/module_gestion_visites/widgets/visit_list_row.dart';

/// « Visites » du propriétaire (M6 · maquette Figma) — onglet de l'espace
/// propriétaire : visites des biens de l'utilisateur, gérées par l'agence.
class OwnerVisitsScreen extends StatefulWidget {
  const OwnerVisitsScreen({super.key});

  @override
  State<OwnerVisitsScreen> createState() => _OwnerVisitsScreenState();
}

class _OwnerVisitsScreenState extends State<OwnerVisitsScreen> {
  int _tab = 0; // 0 = à venir, 1 = passées

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = context.read<AuthProvider>().currentUser?.id;
      if (id != null) context.read<VisitProvider>().loadForOwner(id);
    });
  }

  String _subtitleOf(VisitDetails details) {
    final v = details.visit;
    return switch (v.status) {
      VisitStatus.requested => formatDateTimeShort(v.scheduledAt),
      VisitStatus.confirmed => formatDateTimeShort(v.scheduledAt),
      VisitStatus.done => '${formatDayMonth(v.scheduledAt)} · effectuée',
      VisitStatus.absent => '${formatDayMonth(v.scheduledAt)} · client absent',
      VisitStatus.cancelled => '${formatDayMonth(v.scheduledAt)} · annulée',
    };
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
      appBar: adminAppBar(context, 'Visites'),
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
            Row(children: [
              _filterChip('À venir', 0),
              const SizedBox(width: 8),
              _filterChip('Passées', 1),
            ]),
            const SizedBox(height: 12),
            if (provider.isLoading && provider.visits.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (shown.isEmpty)
              WhiteCard(
                padding: const EdgeInsets.all(20),
                child: Text(
                  _tab == 0
                      ? 'Aucune visite à venir pour vos biens.'
                      : 'Aucune visite passée pour l’instant.',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              )
            else
              WhiteCard(
                child: Column(children: [
                  for (var i = 0; i < shown.length; i++) ...[
                    if (i > 0) const Divider(height: 1, thickness: 1, color: AppColors.border),
                    VisitListRow(details: shown[i], subtitle: _subtitleOf(shown[i])),
                  ],
                ]),
              ),
            const SizedBox(height: 16),
            const MessageBanner(
              type: BannerType.info,
              message: 'Les visites sont organisées par votre agence. '
                  'Vous êtes informé de chaque étape.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, int index) {
    final selected = _tab == index;
    return Material(
      color: selected ? AppColors.infoBg : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _tab = index),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? AppColors.infoBg : AppColors.border),
          ),
          child: Text(label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.textDark,
              )),
        ),
      ),
    );
  }
}
