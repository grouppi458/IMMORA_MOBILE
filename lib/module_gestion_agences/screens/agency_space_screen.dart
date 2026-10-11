import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/core/widgets/message_banner.dart';
import 'package:immora_mobile/core/widgets/primary_button.dart';
import 'package:immora_mobile/module_authentification/providers/auth_provider.dart';
import 'package:immora_mobile/module_authentification/screens/agent_list_screen.dart';
import 'package:immora_mobile/module_authentification/screens/agent_performance_screen.dart';
import 'package:immora_mobile/module_authentification/screens/login_screen.dart';
import 'package:immora_mobile/module_gestion_agences/models/agency_views.dart';
import 'package:immora_mobile/module_gestion_agences/providers/agency_provider.dart';
import 'package:immora_mobile/module_gestion_annonces/screens/listing_list_screen.dart';
import 'package:immora_mobile/module_gestion_annonces/screens/visit_calendar_screen.dart';
import 'package:immora_mobile/module_gestion_ventes/screens/finance_stats_screen.dart';

/// Accueil du rôle « agence » (BF1.6) : son abonnement et ses limites (BF2.8),
/// son score d'activité (BF2.6), ses agents et leur performance.
/// L'agence ne voit que ses propres données et ne peut pas changer son plan.
class AgencySpaceScreen extends StatefulWidget {
  const AgencySpaceScreen({super.key});

  @override
  State<AgencySpaceScreen> createState() => _AgencySpaceScreenState();
}

class _AgencySpaceScreenState extends State<AgencySpaceScreen> {
  Future<AgencySummary?>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final agencyId = context.read<AuthProvider>().currentUser?.agencyId;
    _future = agencyId == null
        ? Future.value(null)
        : context.read<AgencyProvider>().agencySummary(agencyId);
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(_reload); // les agents ont pu changer
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, 'Mon agence'),
      body: FutureBuilder<AgencySummary?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final s = snap.data;
          if (s == null) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: MessageBanner(
                  type: BannerType.error, message: 'Agence introuvable pour ce compte.'),
            );
          }
          final sub = s.subscription;
          final daysLeft = sub == null
              ? 0
              : DateTime.fromMillisecondsSinceEpoch(sub.endDate)
                  .difference(DateTime.now())
                  .inDays;

          return RefreshIndicator(
            onRefresh: () async {
              setState(_reload);
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Bonjour ${user?.fullName ?? ''}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('${s.agency.name} · ${s.agency.city}',
                    style: const TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 16),
                if (sub != null && sub.status == SubscriptionStatus.active && daysLeft <= 7) ...[
                  MessageBanner(
                    type: BannerType.info,
                    message: 'Votre abonnement expire dans $daysLeft jour(s). '
                        'Contactez IMMORA pour le renouveler.',
                  ),
                  const SizedBox(height: 12),
                ],
                WhiteCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Expanded(
                          child: Text('Abonnement',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                        StatusBadge(s.status.label, toneForAgencyStatus(s.status)),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        sub == null
                            ? 'Aucun abonnement'
                            : '${sub.plan.label} · ${formatNumber(sub.monthlyPrice)} TND / mois · '
                                'jusqu’au ${formatDate(sub.endDate)}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                      if (sub != null) ...[
                        const SizedBox(height: 14),
                        _QuotaBar(label: 'Agents actifs', used: s.activeAgents, max: sub.maxAgents),
                        _QuotaBar(label: 'Biens', used: s.properties, max: sub.maxProperties),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                StatTile(
                  icon: Icons.monitor_heart_outlined,
                  label: 'Score d’activité (30 j)',
                  value: '${s.activity.score} / 100',
                  caption: s.activity.activityLevel,
                  valueColor: AppColors.gold,
                ),
                const SizedBox(height: 12),
                WhiteCard(
                  child: Column(children: [
                    NavTile(
                      icon: Icons.badge_outlined,
                      tone: toneBlue,
                      title: 'Mes agents',
                      subtitle: '${s.activeAgents} actif(s) · ajouter, modifier, désactiver',
                      onTap: () => _open(AgentListScreen(
                          agencyId: s.agency.id!, agencyName: s.agency.name)),
                    ),
                    const Divider(height: 1, color: AppColors.background),
                    // Module 5 (Ing. 3) — annonces de l'agence
                    NavTile(
                      icon: Icons.campaign_outlined,
                      tone: toneGreen,
                      title: 'Mes annonces',
                      subtitle: 'Publier, suspendre, prolonger · vues et favoris',
                      onTap: () => _open(ListingListScreen(agencyId: s.agency.id!)),
                    ),
                    const Divider(height: 1, color: AppColors.background),
                    // Module 6 (Ing. 3) — demandes de visite de l'agence.
                    NavTile(
                      icon: Icons.event_outlined,
                      tone: toneAgent,
                      title: 'Visites',
                      subtitle: 'Demandes à traiter : confirmer, reprogrammer',
                      onTap: () => _open(VisitCalendarScreen(agencyId: s.agency.id!)),
                    ),
                    const Divider(height: 1, color: AppColors.background),
                    // Module 4 (Ing. 2) — chiffres des ventes et locations.
                    NavTile(
                      icon: Icons.account_balance_wallet_outlined,
                      tone: toneGold,
                      title: 'Finances',
                      subtitle: 'Ventes, encaissements et commissions par agent',
                      onTap: () => _open(FinanceStatsScreen(agencyId: s.agency.id!)),
                    ),
                    const Divider(height: 1, color: AppColors.background),
                    NavTile(
                      icon: Icons.emoji_events_outlined,
                      tone: toneGold,
                      title: 'Performance des agents',
                      subtitle: 'Classement, visites et commissions',
                      onTap: () => _open(AgentPerformanceScreen(
                          agencyId: s.agency.id!, agencyName: s.agency.name)),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),
                PrimaryButton(label: 'Se déconnecter', onPressed: _logout),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Jauge « utilisé / maximum » d'une limite du plan.
class _QuotaBar extends StatelessWidget {
  const _QuotaBar({required this.label, required this.used, required this.max});

  final String label;
  final int used;
  final int max;

  @override
  Widget build(BuildContext context) {
    final ratio = max == 0 ? 1.0 : (used / max).clamp(0.0, 1.0);
    final full = used >= max;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
            Text('$used / $max',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: full ? AppColors.error : AppColors.textDark)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: AppColors.background,
              color: full ? AppColors.error : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
