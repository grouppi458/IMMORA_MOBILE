import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/module_gestion_agences/score/activity_scorer.dart';
import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/module_gestion_agences/models/agency_views.dart';
import 'package:immora_mobile/module_gestion_agences/providers/agency_provider.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/module_gestion_agences/screens/agency_detail_screen.dart';

/// Score d'activité de chaque agence, du plus faible au plus fort
/// (ActivityDashboardPage).
class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AgencyProvider>();
    final list = [...admin.agencies]
      ..sort((a, b) => a.activity.score.compareTo(b.activity.score));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, 'Activité des agences'),
      body: RefreshIndicator(
        onRefresh: admin.load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Score sur 30 jours : connexions (30 %), biens ajoutés (30 %), '
              'clients ajoutés (20 %) et activité récente (20 %). '
              'Sous $lowActivityThreshold, l’agence est signalée.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 14),
            for (final s in list) ...[
              _ScoreCard(summary: s),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.summary});

  final AgencySummary summary;

  @override
  Widget build(BuildContext context) {
    final act = summary.activity;
    final tone = act.isLow
        ? toneRed
        : act.score < 70
            ? toneGold
            : toneGreen;
    final days = act.daysSinceLastActivity;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AgencyDetailScreen(agencyId: summary.agency.id!))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(summary.agency.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
                Text('${act.score}',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700, color: tone.$2)),
                const SizedBox(width: 8),
                StatusBadge(act.activityLevel, tone),
              ]),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: act.score / 100,
                  minHeight: 6,
                  backgroundColor: AppColors.background,
                  color: tone.$2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${act.loginsLast30Days} connexion${act.loginsLast30Days > 1 ? 's' : ''} · '
                '${act.propertiesAddedLast30Days} bien${act.propertiesAddedLast30Days > 1 ? 's' : ''} · '
                '${act.clientsAddedLast30Days} client${act.clientsAddedLast30Days > 1 ? 's' : ''} · '
                '${days == null ? 'aucune activité' : days == 0 ? 'actif aujourd’hui' : 'inactif depuis $days j'}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
