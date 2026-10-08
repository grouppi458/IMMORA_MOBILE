import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/module_gestion_agences/models/agency_views.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/module_gestion_agences/providers/agency_provider.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/module_gestion_agences/screens/agency_detail_screen.dart';
import 'package:immora_mobile/module_gestion_agences/screens/agency_form_screen.dart';

enum _Sort { name, score, newest }

/// Liste des agences avec recherche, filtres par statut et tri (AgencyListPage).
class AgencyListScreen extends StatefulWidget {
  const AgencyListScreen({super.key});

  @override
  State<AgencyListScreen> createState() => _AgencyListScreenState();
}

class _AgencyListScreenState extends State<AgencyListScreen> {
  final _searchCtrl = TextEditingController();
  AgencyStatus? _status; // null = toutes
  _Sort _sort = _Sort.name;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AgencySummary> _filter(List<AgencySummary> all) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final list = all.where((a) {
      if (_status != null && a.status != _status) return false;
      if (q.isEmpty) return true;
      return a.agency.name.toLowerCase().contains(q) ||
          a.agency.city.toLowerCase().contains(q) ||
          a.agency.email.toLowerCase().contains(q);
    }).toList();
    switch (_sort) {
      case _Sort.name:
        list.sort((a, b) => a.agency.name.compareTo(b.agency.name));
      case _Sort.score:
        list.sort((a, b) => b.activity.score.compareTo(a.activity.score));
      case _Sort.newest:
        list.sort((a, b) => b.agency.createdAt.compareTo(a.agency.createdAt));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AgencyProvider>();
    final all = admin.agencies;
    int count(AgencyStatus s) => all.where((a) => a.status == s).length;
    final list = _filter(all);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, 'Agences', actions: [
        PopupMenuButton<_Sort>(
          tooltip: 'Trier',
          icon: const Icon(Icons.filter_alt_outlined),
          initialValue: _sort,
          onSelected: (s) => setState(() => _sort = s),
          itemBuilder: (_) => const [
            PopupMenuItem(value: _Sort.name, child: Text('Trier par nom')),
            PopupMenuItem(value: _Sort.score, child: Text('Trier par score')),
            PopupMenuItem(value: _Sort.newest, child: Text('Plus récentes d’abord')),
          ],
        ),
      ]),
      floatingActionButton: GoldFab(
        label: 'Nouvelle agence',
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const AgencyFormScreen())),
      ),
      body: RefreshIndicator(
        onRefresh: admin.load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Rechercher une agence…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Effacer',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(_searchCtrl.clear),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            FilterChipsRow<AgencyStatus?>(
              selected: _status,
              onSelected: (s) => setState(() => _status = s),
              options: [
                (null, 'Toutes · ${all.length}'),
                (AgencyStatus.active, 'Actives · ${count(AgencyStatus.active)}'),
                (AgencyStatus.expired, 'Expirées · ${count(AgencyStatus.expired)}'),
                (AgencyStatus.suspended, 'Suspendues · ${count(AgencyStatus.suspended)}'),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: admin.isLoading && all.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : list.isEmpty
                      ? const WhiteCard(
                          padding: EdgeInsets.all(20),
                          child: Text('Aucune agence ne correspond.',
                              style: TextStyle(color: AppColors.textMuted)),
                        )
                      : WhiteCard(
                          child: Column(children: [
                            for (final a in list) ...[
                              _AgencyTile(summary: a),
                              if (a != list.last)
                                const Divider(height: 1, color: AppColors.background),
                            ],
                          ]),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgencyTile extends StatelessWidget {
  const _AgencyTile({required this.summary});

  final AgencySummary summary;

  @override
  Widget build(BuildContext context) {
    final a = summary.agency;
    final plan = summary.subscription?.plan;
    final tone = switch (summary.status) {
      AgencyStatus.suspended => toneGrey,
      AgencyStatus.expired => toneRed,
      AgencyStatus.active => plan == SubscriptionPlan.premium ? toneGold : toneBlue,
    };
    return ListTile(
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AgencyDetailScreen(agencyId: a.id!))),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: InitialsAvatar(a.name, tone: tone),
      title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(
        '${a.city} · ${summary.activeAgents} agents · ${plan?.label ?? 'sans plan'}'
        ' · score ${summary.activity.score}',
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      trailing: StatusBadge(summary.status.label, toneForAgencyStatus(summary.status)),
    );
  }
}
