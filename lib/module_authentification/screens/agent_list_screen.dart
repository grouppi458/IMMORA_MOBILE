import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/module_authentification/models/agent_with_user.dart';
import 'package:immora_mobile/module_authentification/providers/user_admin_provider.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/module_gestion_agences/providers/agency_provider.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/module_authentification/screens/agent_form_screen.dart';

/// Agents d'une agence, filtrables actifs / inactifs (AgentListPage).
class AgentListScreen extends StatefulWidget {
  const AgentListScreen({super.key, required this.agencyId, this.agencyName});

  final int agencyId;
  final String? agencyName; // affiché dans le titre (espace agence)

  @override
  State<AgentListScreen> createState() => _AgentListScreenState();
}

class _AgentListScreenState extends State<AgentListScreen> {
  bool? _active; // null = tous
  late Future<List<AgentWithUser>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() =>
      _future = context.read<UserAdminProvider>().agentsOfAgency(widget.agencyId);

  Future<void> _openForm([AgentWithUser? agent]) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AgentFormScreen(agencyId: widget.agencyId, existing: agent)));
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    final agency = context.watch<AgencyProvider>().agencyById(widget.agencyId)?.agency;
    final name = widget.agencyName ?? agency?.name ?? '';
    final shortName = name.split(' ').first;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, 'Agents · $shortName'),
      floatingActionButton: GoldFab(label: 'Ajouter un agent', onPressed: _openForm),
      body: FutureBuilder<List<AgentWithUser>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final all = snap.data!;
          final list = _active == null
              ? all
              : all.where((a) => a.user.isActive == _active).toList();
          return ListView(
            padding: const EdgeInsets.only(top: 16, bottom: 96),
            children: [
              FilterChipsRow<bool?>(
                selected: _active,
                onSelected: (v) => setState(() => _active = v),
                options: [
                  (null, 'Tous · ${all.length}'),
                  (true, 'Actifs · ${all.where((a) => a.user.isActive).length}'),
                  (false, 'Inactifs · ${all.where((a) => !a.user.isActive).length}'),
                ],
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: list.isEmpty
                    ? const WhiteCard(
                        padding: EdgeInsets.all(20),
                        child: Text('Aucun agent pour le moment.',
                            style: TextStyle(color: AppColors.textMuted)),
                      )
                    : WhiteCard(
                        child: Column(children: [
                          for (final a in list) ...[
                            ListTile(
                              onTap: () => _openForm(a),
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              leading: InitialsAvatar(a.user.fullName,
                                  tone: a.user.isActive ? toneAgent : toneGrey, round: true),
                              title: Text(a.user.fullName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600, fontSize: 14)),
                              subtitle: Text(
                                '${agentSpecialities[a.agent.speciality] ?? 'Généraliste'}'
                                ' · commission ${formatRate(a.agent.commissionRate)} %',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                              ),
                              trailing: a.user.isActive
                                  ? const StatusBadge('Actif', toneGreen)
                                  : const StatusBadge('Inactif', toneGrey),
                            ),
                            if (a != list.last)
                              const Divider(height: 1, color: AppColors.background),
                          ],
                        ]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
