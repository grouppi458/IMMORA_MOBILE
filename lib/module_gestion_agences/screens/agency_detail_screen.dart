import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/module_gestion_agences/models/agency_views.dart';
import 'package:immora_mobile/module_gestion_agences/models/subscription.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/module_gestion_agences/providers/agency_provider.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/module_gestion_agences/screens/agency_form_screen.dart';
import 'package:immora_mobile/module_authentification/screens/agent_list_screen.dart';
import 'package:immora_mobile/module_gestion_agences/screens/subscription_screen.dart';
import 'package:immora_mobile/module_authentification/screens/user_list_screen.dart';

/// Fiche d'une agence (AgencyListPage → détail).
class AgencyDetailScreen extends StatelessWidget {
  const AgencyDetailScreen({super.key, required this.agencyId});

  final int agencyId;

  Future<void> _toggleActive(BuildContext context, AgencySummary s) async {
    final admin = context.read<AgencyProvider>();
    final suspend = s.agency.isActive;
    final ok = await confirmDialog(
      context,
      title: suspend ? 'Suspendre l’agence ?' : 'Réactiver l’agence ?',
      message: suspend
          ? 'L’accès de ${s.agency.name} sera bloqué jusqu’à réactivation. '
              'Ses agents ne pourront plus se connecter.'
          : '${s.agency.name} et ses agents pourront de nouveau se connecter.',
      confirmLabel: suspend ? 'Suspendre' : 'Réactiver',
      danger: suspend,
    );
    if (!ok) return;
    final result = await admin.setAgencyActive(agencyId, !suspend);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result == null
          ? admin.errorMessage ?? 'Erreur'
          : suspend
              ? 'Agence suspendue'
              : 'Agence réactivée'),
    ));
  }

  /// BF2.5 — suppression définitive de l'agence (après confirmation).
  Future<void> _delete(BuildContext context, AgencySummary s) async {
    final agencies = context.read<AgencyProvider>();
    final ok = await confirmDialog(
      context,
      title: 'Supprimer ${s.agency.name} ?',
      message: 'L’agence, son abonnement, ses comptes agence et agents et leur '
          'journal seront supprimés définitivement. Cette action est irréversible.',
      confirmLabel: 'Supprimer',
    );
    if (!ok || !context.mounted) return;
    final result = await agencies.deleteAgency(agencyId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: result == null ? AppColors.error : AppColors.success,
      content: Text(result == null ? agencies.errorMessage ?? 'Erreur' : 'Agence supprimée'),
    ));
    if (result != null) Navigator.of(context).pop();
  }

  void _edit(BuildContext context, AgencySummary s) => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AgencyFormScreen(agency: s.agency)));

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AgencyProvider>();
    final s = provider.agencyById(agencyId);
    if (s == null) {
      return Scaffold(
        appBar: adminAppBar(context, 'Agence'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final a = s.agency;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, a.name, actions: [
        IconButton(
          tooltip: 'Modifier',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => _edit(context, s),
        ),
      ]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeaderCard(summary: s),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _Figure('${s.activeAgents}', 'Agents', AppColors.primary)),
            const SizedBox(width: 10),
            Expanded(child: _Figure(formatNumber(s.properties), 'Biens', AppColors.textDark)),
            const SizedBox(width: 10),
            Expanded(child: _Figure('${s.activity.score}', 'Score', AppColors.gold)),
          ]),
          const SizedBox(height: 12),
          WhiteCard(
            child: Column(children: [
              InfoRow('Email', a.email),
              const Divider(height: 1, color: AppColors.background),
              InfoRow('Téléphone', a.phone),
              const Divider(height: 1, color: AppColors.background),
              InfoRow('Ville', a.city),
              const Divider(height: 1, color: AppColors.background),
              InfoRow('Créée le', formatDate(a.createdAt)),
            ]),
          ),
          const SizedBox(height: 12),
          WhiteCard(
            child: Column(children: [
              NavTile(
                icon: Icons.workspace_premium_outlined,
                tone: toneGold,
                title: 'Abonnement',
                subtitle: _subscriptionText(s.subscription),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SubscriptionScreen(agencyId: agencyId))),
              ),
              const Divider(height: 1, color: AppColors.background),
              NavTile(
                icon: Icons.badge_outlined,
                tone: toneBlue,
                title: 'Agents',
                subtitle: '${s.activeAgents} agent${s.activeAgents > 1 ? 's' : ''} actif${s.activeAgents > 1 ? 's' : ''}',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AgentListScreen(agencyId: agencyId))),
              ),
              const Divider(height: 1, color: AppColors.background),
              NavTile(
                icon: Icons.manage_accounts_outlined,
                tone: toneBlue,
                title: 'Utilisateurs',
                subtitle: 'Comptes & rôles',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => UserListScreen(agencyId: agencyId, agencyName: a.name))),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _edit(context, s),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                  side: const BorderSide(color: AppColors.border),
                  backgroundColor: Colors.white,
                ),
                child: const Text('Modifier', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => _toggleActive(context, s),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                  backgroundColor: a.isActive ? AppColors.error : AppColors.success,
                ),
                child: Text(a.isActive ? 'Suspendre' : 'Réactiver',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () => _delete(context, s),
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              label: const Text('Supprimer l’agence',
                  style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  static String _subscriptionText(Subscription? sub) {
    if (sub == null) return 'Aucun abonnement';
    final end = formatDate(sub.endDate);
    return switch (sub.status) {
      SubscriptionStatus.active => '${sub.plan.label} · actif jusqu’au $end',
      SubscriptionStatus.expired => '${sub.plan.label} · expiré le $end',
      SubscriptionStatus.suspended => '${sub.plan.label} · suspendu',
    };
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.summary});

  final AgencySummary summary;

  @override
  Widget build(BuildContext context) {
    final a = summary.agency;
    final logo = a.logoPath;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.primary, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          clipBehavior: Clip.antiAlias,
          alignment: Alignment.center,
          child: logo != null && File(logo).existsSync()
              ? Image.file(File(logo), fit: BoxFit.cover, width: 56, height: 56)
              : Text(initialsOf(a.name),
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 18)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.name,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('${a.city} · ${a.address}',
                  style: const TextStyle(color: Color(0xFFC9D6EA), fontSize: 12)),
              const SizedBox(height: 6),
              StatusBadge(summary.status.label, toneForAgencyStatus(summary.status)),
            ],
          ),
        ),
      ]),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.value, this.label, this.color);

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}
