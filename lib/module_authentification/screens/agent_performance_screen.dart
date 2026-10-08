import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/core/widgets/message_banner.dart';
import 'package:immora_mobile/module_authentification/models/agent_performance.dart';
import 'package:immora_mobile/module_authentification/providers/user_admin_provider.dart';

/// Fonction avancée du Module 1 : tableau de bord de performance des agents.
/// BF1.8 : visites, ventes / locations et commissions par agent sur une période.
/// BF1.9 : classement (top agents) et graphique des commissions.
class AgentPerformanceScreen extends StatefulWidget {
  const AgentPerformanceScreen({super.key, this.agencyId, this.agencyName});

  /// null = tous les agents de la plateforme (vue administrateur).
  final int? agencyId;
  final String? agencyName;

  @override
  State<AgentPerformanceScreen> createState() => _AgentPerformanceScreenState();
}

class _AgentPerformanceScreenState extends State<AgentPerformanceScreen> {
  PerformancePeriod _period = PerformancePeriod.days30;
  late Future<List<AgentPerformance>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future = context
      .read<UserAdminProvider>()
      .agentRanking(agencyId: widget.agencyId, period: _period);

  void _changePeriod(PerformancePeriod p) => setState(() {
        _period = p;
        _load();
      });

  @override
  Widget build(BuildContext context) {
    final title = widget.agencyName == null
        ? 'Performance des agents'
        : 'Performance · ${widget.agencyName!.split(' ').first}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, title),
      body: FutureBuilder<List<AgentPerformance>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: MessageBanner(
                  type: BannerType.error, message: 'Impossible de calculer les performances.'),
            );
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          final visits = list.fold<int>(0, (s, p) => s + p.visits);
          final deals = list.fold<int>(0, (s, p) => s + p.deals);
          final commissions = list.fold<double>(0, (s, p) => s + p.commissions);
          final noData = visits == 0 && deals == 0;

          return ListView(
            padding: const EdgeInsets.only(top: 16, bottom: 24),
            children: [
              FilterChipsRow<PerformancePeriod>(
                selected: _period,
                onSelected: _changePeriod,
                options: [for (final p in PerformancePeriod.values) (p, p.label)],
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(
                          child: StatTile(
                              icon: Icons.event_available_outlined,
                              label: 'Visites',
                              value: formatNumber(visits))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: StatTile(
                              icon: Icons.handshake_outlined,
                              label: 'Affaires',
                              value: formatNumber(deals))),
                    ]),
                    const SizedBox(height: 10),
                    StatTile(
                      icon: Icons.payments_outlined,
                      label: 'Commissions',
                      value: '${formatNumber(commissions)} TND',
                      valueColor: AppColors.gold,
                      caption: '${list.length} agent${list.length > 1 ? 's' : ''} · ${_period.label}',
                    ),
                    if (noData) ...[
                      const SizedBox(height: 12),
                      const MessageBanner(
                        type: BannerType.info,
                        message: 'Aucune visite ni transaction sur la période. Les chiffres '
                            'se rempliront avec les modules Visites (M6) et Transactions (M4).',
                      ),
                    ],
                    const SizedBox(height: 16),
                    const SectionTitle('Commissions par agent (TND)'),
                    const SizedBox(height: 8),
                    WhiteCard(
                      padding: const EdgeInsets.all(16),
                      child: _CommissionChart(items: list.take(6).toList()),
                    ),
                    const SizedBox(height: 16),
                    const SectionTitle('Top agents'),
                    const SizedBox(height: 8),
                    if (list.isEmpty)
                      const WhiteCard(
                        padding: EdgeInsets.all(20),
                        child: Text('Aucun agent pour le moment.',
                            style: TextStyle(color: AppColors.textMuted)),
                      )
                    else
                      WhiteCard(
                        child: Column(children: [
                          for (var i = 0; i < list.length; i++) ...[
                            _RankTile(rank: i + 1, perf: list[i]),
                            if (i < list.length - 1)
                              const Divider(height: 1, color: AppColors.background),
                          ],
                        ]),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Ligne du classement : rang, agent, visites / affaires, commissions.
class _RankTile extends StatelessWidget {
  const _RankTile({required this.rank, required this.perf});

  final int rank;
  final AgentPerformance perf;

  @override
  Widget build(BuildContext context) {
    final user = perf.agent.user;
    final medal = rank <= 3 ? AppColors.gold : AppColors.textMuted;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 22,
          child: Text('$rank',
              style: TextStyle(fontWeight: FontWeight.w700, color: medal, fontSize: 15)),
        ),
        InitialsAvatar(user.fullName,
            tone: user.isActive ? toneAgent : toneGrey, round: true, size: 36),
      ]),
      title: Text(user.fullName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(
        '${perf.visits} visites · ${perf.sales} ventes · ${perf.rentals} locations',
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      trailing: Text('${formatNumber(perf.commissions)} TND',
          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
    );
  }
}

/// Graphique en barres horizontales des commissions (6 meilleurs agents).
class _CommissionChart extends StatelessWidget {
  const _CommissionChart({required this.items});

  final List<AgentPerformance> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text('—', style: TextStyle(color: AppColors.textMuted));
    }
    final max = items.map((p) => p.commissions).fold<double>(0, (m, v) => v > m ? v : m);
    return Column(children: [
      for (final p in items)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            SizedBox(
              width: 96,
              child: Text(p.agent.user.fullName.split(' ').first,
                  overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: max == 0 ? 0 : p.commissions / max,
                  minHeight: 12,
                  backgroundColor: AppColors.background,
                  color: AppColors.primary,
                ),
              ),
            ),
            SizedBox(
              width: 64,
              child: Text(formatNumber(p.commissions),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ]),
        ),
    ]);
  }
}
