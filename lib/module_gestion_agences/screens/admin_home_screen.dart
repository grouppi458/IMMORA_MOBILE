import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/module_gestion_agences/models/agency_views.dart';
import 'package:immora_mobile/module_authentification/providers/auth_provider.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/module_gestion_agences/providers/agency_provider.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/module_gestion_agences/screens/agency_detail_screen.dart';

/// Tableau de bord de l'administrateur (AdminHomePage).
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key, required this.onOpenTab});

  /// Change d'onglet dans la barre du bas (1 = Agences, 2 = Stats, 3 = Activité).
  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AgencyProvider>();
    final user = context.watch<AuthProvider>().currentUser;
    final stats = admin.stats;
    final firstName = (user?.fullName ?? 'Admin').split(' ').first;

    return RefreshIndicator(
      onRefresh: admin.load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Header(
            firstName: firstName,
            activeAgencies: stats?.activeAgencies,
            onBell: () => onOpenTab(3),
            onAvatar: () => onOpenTab(4),
          ),
          if (stats == null)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatsGrid(stats: stats),
                  const SizedBox(height: 20),
                  SectionTitle('Activité faible',
                      action: 'Voir tout', onAction: () => onOpenTab(3)),
                  _LowActivityList(agencies: admin.lowActivityAgencies.take(3).toList()),
                  const SizedBox(height: 20),
                  _RevenueCard(months: stats.monthlyRevenue),
                  const SizedBox(height: 20),
                  const SectionTitle('Accès rapides'),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: _QuickAccess(
                        icon: Icons.apartment_outlined,
                        color: AppColors.primary,
                        title: 'Agences',
                        subtitle: 'Gérer & créer',
                        onTap: () => onOpenTab(1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickAccess(
                        icon: Icons.bar_chart,
                        color: AppColors.gold,
                        title: 'Statistiques',
                        subtitle: 'Ventes & revenus',
                        onTap: () => onOpenTab(2),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.firstName,
    required this.activeAgencies,
    required this.onBell,
    required this.onAvatar,
  });

  final String firstName;
  final int? activeAgencies;
  final VoidCallback onBell;
  final VoidCallback onAvatar;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Alertes d’activité',
                    onPressed: onBell,
                    icon: const Icon(Icons.notifications_none, color: Colors.white),
                  ),
                  GestureDetector(
                    onTap: onAvatar,
                    child: CircleAvatar(
                      radius: 17,
                      backgroundColor: Colors.white,
                      child: Text(firstName.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                              color: AppColors.primary, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text('Bonjour, $firstName',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                activeAgencies == null
                    ? 'Plateforme IMMORA'
                    : 'Plateforme IMMORA · $activeAgencies agences actives',
                style: const TextStyle(color: Color(0xFFC9D6EA), fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    String plus(int n) => n > 0 ? '+$n ce mois' : 'aucun ce mois';
    return Column(children: [
      Row(children: [
        Expanded(
          child: StatTile(
            icon: Icons.apartment_outlined,
            label: 'Agences',
            value: '${stats.totalAgencies}',
            caption: plus(stats.agenciesThisMonth),
            captionColor: stats.agenciesThisMonth > 0 ? AppColors.success : AppColors.textMuted,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatTile(
            icon: Icons.people_outline,
            label: 'Comptes',
            value: formatNumber(stats.accounts),
            caption: 'agents & clients',
            valueColor: AppColors.textDark,
          ),
        ),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: StatTile(
            icon: Icons.payments_outlined,
            label: 'MRR (TND)',
            value: formatNumber(stats.mrr),
            caption: 'par mois',
            valueColor: AppColors.gold,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatTile(
            icon: Icons.home_work_outlined,
            label: 'Biens',
            value: formatNumber(stats.properties),
            caption: plus(stats.propertiesThisMonth),
            valueColor: AppColors.textDark,
            captionColor:
                stats.propertiesThisMonth > 0 ? AppColors.success : AppColors.textMuted,
          ),
        ),
      ]),
    ]);
  }
}

class _LowActivityList extends StatelessWidget {
  const _LowActivityList({required this.agencies});

  final List<AgencySummary> agencies;

  @override
  Widget build(BuildContext context) {
    if (agencies.isEmpty) {
      return const WhiteCard(
        padding: EdgeInsets.all(16),
        child: Text('Aucune agence en faible activité.',
            style: TextStyle(color: AppColors.textMuted)),
      );
    }
    return WhiteCard(
      child: Column(
        children: [
          for (final a in agencies) ...[
            ListTile(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => AgencyDetailScreen(agencyId: a.agency.id!))),
              leading: InitialsAvatar(a.agency.name, tone: toneRed),
              title: Text(a.agency.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text(_reason(a),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              trailing: const StatusBadge('Faible', toneRed),
            ),
            if (a != agencies.last) const Divider(height: 1, color: AppColors.background),
          ],
        ],
      ),
    );
  }

  /// « Score 22 · 34 j sans activité » ou « Score 28 · abonnement expiré ».
  String _reason(AgencySummary a) {
    final score = 'Score ${a.activity.score}';
    if (a.status == AgencyStatus.expired) return '$score · abonnement expiré';
    if (a.status == AgencyStatus.suspended) return '$score · agence suspendue';
    final days = a.activity.daysSinceLastActivity;
    return days == null ? '$score · aucune activité' : '$score · $days j sans activité';
  }
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({required this.months});

  final List<MonthRevenue> months;

  @override
  Widget build(BuildContext context) {
    final current = months.last.amount;
    final previous = months[months.length - 2].amount;
    final change = previous == 0 ? null : ((current - previous) / previous * 100).round();
    final changeText = change == null ? '' : ' · ${change >= 0 ? '+' : ''}$change %';

    return WhiteCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(
              child: Text('Revenus d’abonnement',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: AppColors.infoBg, borderRadius: BorderRadius.circular(8)),
              child: const Text('6 mois',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 4),
          Text('${formatNumber(current)} TND ce mois$changeText',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 16),
          RevenueBarChart(months: months),
        ],
      ),
    );
  }
}

class _QuickAccess extends StatelessWidget {
  const _QuickAccess({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(subtitle,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
