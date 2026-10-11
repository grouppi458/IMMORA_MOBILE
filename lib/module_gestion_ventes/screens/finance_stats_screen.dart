import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/core/widgets/message_banner.dart';
import 'package:immora_mobile/module_gestion_ventes/models/finance_stats.dart';
import 'package:immora_mobile/module_gestion_ventes/providers/transaction_provider.dart';

/// « Finances » [financeStats] — M4 : ventes et locations de la période,
/// montant et commissions, revenus des 4 derniers mois, encaissements en
/// attente / en retard et classement des commissions par agent.
class FinanceStatsScreen extends StatefulWidget {
  const FinanceStatsScreen({super.key, required this.agencyId});

  final int agencyId;

  @override
  State<FinanceStatsScreen> createState() => _FinanceStatsScreenState();
}

class _FinanceStatsScreenState extends State<FinanceStatsScreen> {
  StatsPeriod _period = StatsPeriod.quarter;
  FinanceStats? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final stats = await context.read<TransactionProvider>().financeStats(
            widget.agencyId,
            from: _period.from,
            to: DateTime.now(),
          );
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Impossible de charger les statistiques.';
      });
    }
  }

  void _setPeriod(StatsPeriod period) {
    if (period == _period) return;
    setState(() => _period = period);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, 'Finances'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FilterChipsRow<StatsPeriod>(
              selected: _period,
              onSelected: _setPeriod,
              options: [for (final p in StatsPeriod.values) (p, p.label)],
            ),
            const SizedBox(height: 12),
            if (_loading && s == null)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && s == null)
              MessageBanner(type: BannerType.error, message: _error!)
            else if (s != null) ...[
              Row(children: [
                Expanded(
                  child: StatTile(
                    icon: Icons.sell_outlined,
                    label: 'Ventes',
                    value: '${s.salesCount}',
                    caption: _period.caption,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatTile(
                    icon: Icons.vpn_key_outlined,
                    label: 'Locations',
                    value: '${s.rentsCount}',
                    caption: _period.caption,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: StatTile(
                    icon: Icons.paid_outlined,
                    label: 'Montant total',
                    value: compactMoney(s.totalAmount),
                    caption: 'TND',
                    valueColor: AppColors.gold,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatTile(
                    icon: Icons.receipt_long_outlined,
                    label: 'Commissions',
                    value: compactMoney(s.commissions),
                    caption: 'TND',
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              WhiteCard(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Revenus (4 mois)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  RevenueBarChart(months: s.monthlyRevenue, showValues: true),
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: StatTile(
                    icon: Icons.schedule,
                    label: 'En attente',
                    value: '${s.pendingCount}',
                    caption: '${formatNumber(s.pendingAmount)} TND',
                    valueColor: AppColors.gold,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatTile(
                    icon: Icons.warning_amber_rounded,
                    label: 'En retard',
                    value: '${s.lateCount}',
                    caption: '${formatNumber(s.lateAmount)} TND',
                    valueColor: AppColors.error,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              WhiteCard(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Commissions par agent',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (s.agentCommissions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Aucune commission sur la période.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    )
                  else
                    for (var i = 0; i < s.agentCommissions.length; i++) ...[
                      _AgentCommission(
                        name: s.agentCommissions[i].$1,
                        amount: s.agentCommissions[i].$2,
                        best: s.agentCommissions.first.$2,
                      ),
                      if (i < s.agentCommissions.length - 1)
                        const Divider(height: 18, thickness: 1, color: AppColors.border),
                    ],
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ligne « SB · Sirine Ben Salah ……… 31,2K » avec barre de progression.
class _AgentCommission extends StatelessWidget {
  const _AgentCommission({required this.name, required this.amount, required this.best});

  final String name;
  final double amount;
  final double best;

  @override
  Widget build(BuildContext context) {
    final ratio = best <= 0 ? 0.0 : (amount / best).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(children: [
        Row(children: [
          InitialsAvatar(name, tone: toneBlue, size: 36, round: true),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Text(compactMoney(amount),
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.gold)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(children: [
            Container(height: 7, color: const Color(0xFFEFE1C0)),
            FractionallySizedBox(
              widthFactor: ratio,
              child: Container(height: 7, color: AppColors.gold),
            ),
          ]),
        ),
      ]),
    );
  }
}
