import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/module_authentification/models/user.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/module_authentification/providers/user_admin_provider.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/module_authentification/screens/user_form_screen.dart';

/// Tous les comptes, ou ceux d'une agence (UserListPage).
class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key, this.agencyId, this.agencyName});

  final int? agencyId;
  final String? agencyName;

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final _searchCtrl = TextEditingController();
  bool _searching = false;
  UserRole? _role; // null = tous
  late Future<List<User>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reload() =>
      _future = context.read<UserAdminProvider>().users(agencyId: widget.agencyId);

  Future<void> _openForm([User? user]) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => UserFormScreen(existing: user, agencyId: widget.agencyId)));
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.agencyName == null
        ? 'Utilisateurs'
        : 'Utilisateurs · ${widget.agencyName!.split(' ').first}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, title, actions: [
        IconButton(
          tooltip: _searching ? 'Fermer la recherche' : 'Rechercher',
          icon: Icon(_searching ? Icons.close : Icons.search),
          onPressed: () => setState(() {
            _searching = !_searching;
            if (!_searching) _searchCtrl.clear();
          }),
        ),
      ]),
      floatingActionButton: GoldFab(label: 'Ajouter', onPressed: _openForm),
      body: FutureBuilder<List<User>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final q = _searchCtrl.text.trim().toLowerCase();
          final list = snap.data!.where((u) {
            if (_role != null && u.role != _role) return false;
            return q.isEmpty ||
                u.fullName.toLowerCase().contains(q) ||
                u.email.toLowerCase().contains(q);
          }).toList();

          return ListView(
            padding: const EdgeInsets.only(top: 16, bottom: 96),
            children: [
              if (_searching)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Nom ou email…',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ),
              FilterChipsRow<UserRole?>(
                selected: _role,
                onSelected: (r) => setState(() => _role = r),
                options: [
                  (null, 'Tous'),
                  (UserRole.agency, 'Agence'),
                  (UserRole.agent, 'Agent'),
                  (UserRole.client, 'Client'),
                  (UserRole.owner, 'Propriétaire'),
                  if (widget.agencyId == null) (UserRole.admin, 'Admin'),
                ],
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: list.isEmpty
                    ? const WhiteCard(
                        padding: EdgeInsets.all(20),
                        child: Text('Aucun compte ne correspond.',
                            style: TextStyle(color: AppColors.textMuted)),
                      )
                    : WhiteCard(
                        child: Column(children: [
                          for (final u in list) ...[
                            ListTile(
                              onTap: () => _openForm(u),
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                              leading: InitialsAvatar(u.fullName,
                                  tone: u.isActive ? toneForRole(u.role) : toneGrey,
                                  round: true),
                              title: Text(u.fullName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600, fontSize: 14)),
                              subtitle: Text(
                                '${u.role.name} · ${u.isActive ? lastLoginLabel(u.lastLoginAt) : 'désactivé'}',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                              ),
                              trailing: StatusBadge(u.role.label, toneForRole(u.role)),
                            ),
                            if (u != list.last)
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
