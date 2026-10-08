import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/module_authentification/screens/agent_performance_screen.dart';
import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/module_gestion_agences/providers/agency_provider.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';

/// Statistiques de la plateforme (StatsDashboardPage, première version).
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AgencyProvider>();
    final stats = admin.stats;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, 'Statistiques'),
      body: stats == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: admin.load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  WhiteCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Revenus d’abonnement (TND)',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                          'Total 6 mois : ${formatNumber(stats.monthlyRevenue.fold<double>(0, (s, m) => s + m.amount))} TND',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        RevenueBarChart(months: stats.monthlyRevenue, height: 150),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SectionTitle('Agences par plan'),
                  const SizedBox(height: 8),
                  WhiteCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      for (final plan in SubscriptionPlan.values)
                        _BarRow(
                          label: plan.label,
                          value: admin.agencies
                              .where((a) => a.subscription?.plan == plan)
                              .length,
                          total: admin.agencies.length,
                          color: plan == SubscriptionPlan.premium
                              ? AppColors.gold
                              : AppColors.primary,
                        ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  const SectionTitle('Comptes par rôle'),
                  const SizedBox(height: 8),
                  WhiteCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      for (final role in UserRole.values)
                        _BarRow(
                          label: role.label,
                          value: stats.accountsByRole[role] ?? 0,
                          total: stats.accountsByRole.values.fold(0, (s, v) => s + v),
                          color: AppColors.secondary,
                        ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  WhiteCard(
                    child: NavTile(
                      icon: Icons.emoji_events_outlined,
                      tone: toneGold,
                      title: 'Performance des agents',
                      subtitle: 'Top agents, visites et commissions (Module 1)',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const AgentPerformanceScreen())),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  final String label;
  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 13))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : value / total,
              minHeight: 10,
              backgroundColor: AppColors.background,
              color: color,
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text('$value',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}
