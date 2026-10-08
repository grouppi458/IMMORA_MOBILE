import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/widgets/primary_button.dart';
import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/constants.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/module_gestion_agences/providers/agency_provider.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';

/// Abonnement d'une agence : plan, période, limites, changement et renouvellement
/// (SubscriptionPage).
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key, required this.agencyId});

  final int agencyId;

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  SubscriptionPlan? _plan;

  Future<void> _run(Future<String?> Function() action, String success) async {
    final admin = context.read<AgencyProvider>();
    final result = await action();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: result == null ? AppColors.error : AppColors.success,
      content: Text(result == null ? admin.errorMessage ?? 'Erreur' : success),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AgencyProvider>();
    final s = admin.agencyById(widget.agencyId);
    final sub = s?.subscription;
    final plan = _plan ?? sub?.plan ?? SubscriptionPlan.free;
    final status = sub?.status;
    final tone = switch (status) {
      SubscriptionStatus.active => toneGreen,
      SubscriptionStatus.expired => toneRed,
      _ => toneGrey,
    };
    final statusLabel = switch (status) {
      SubscriptionStatus.active => 'Actif',
      SubscriptionStatus.expired => 'Expiré',
      SubscriptionStatus.suspended => 'Suspendu',
      null => 'Aucun',
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, 'Abonnement'),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                WhiteCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(s.agency.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                        StatusBadge(statusLabel, tone),
                      ]),
                      const SizedBox(height: 12),
                      Text(sub == null ? '—' : sub.plan.label,
                          style: const TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      if (sub != null)
                        Text('${formatNumber(sub.monthlyPrice)} TND / mois',
                            style: const TextStyle(
                                color: AppColors.gold, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 12),
                  WhiteCard(
                    child: Column(children: [
                      InfoRow('Début', formatDate(sub.startDate)),
                      const Divider(height: 1, color: AppColors.background),
                      InfoRow('Fin', formatDate(sub.endDate)),
                      const Divider(height: 1, color: AppColors.background),
                      InfoRow('Agents actifs', '${s.activeAgents} / ${sub.maxAgents}'),
                      const Divider(height: 1, color: AppColors.background),
                      InfoRow('Biens', '${s.properties} / ${sub.maxProperties}'),
                    ]),
                  ),
                ],
                const SizedBox(height: 20),
                ChoiceChipsField<SubscriptionPlan>(
                  label: 'Plan',
                  selected: plan,
                  onSelected: (p) => setState(() => _plan = p),
                  options: [
                    for (final p in SubscriptionPlan.values)
                      (p, '${p.label} · ${formatNumber(planDefaults[p]!.monthlyPrice)} TND'),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Limites : ${planDefaults[plan]!.maxAgents} agent(s), '
                  '${planDefaults[plan]!.maxProperties} biens.',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 20),
                if (sub != null && plan != sub.plan) ...[
                  OutlinedButton(
                    onPressed: admin.isSaving
                        ? null
                        : () => _run(() => admin.changePlan(widget.agencyId, plan),
                            'Plan changé : ${plan.label}'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: const StadiumBorder(),
                      backgroundColor: Colors.white,
                    ),
                    child: Text('Passer au plan ${plan.label}'),
                  ),
                  const SizedBox(height: 12),
                ],
                PrimaryButton(
                  label: 'Renouveler $subscriptionPeriodDays jours',
                  loading: admin.isSaving,
                  onPressed: () => _run(() => admin.renew(widget.agencyId, plan),
                      'Abonnement renouvelé ($subscriptionPeriodDays jours)'),
                ),
              ],
            ),
    );
  }
}
