import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/module_authentification/screens/login_screen.dart';
import 'package:immora_mobile/core/widgets/primary_button.dart';
import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/module_authentification/providers/auth_provider.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/module_authentification/screens/agent_performance_screen.dart';
import 'package:immora_mobile/module_authentification/screens/user_list_screen.dart';

/// Profil de l'administrateur : identité, gestion des comptes,
/// performance des agents et déconnexion (BF1.6).
class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, 'Profil'),
      body: user == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                WhiteCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    InitialsAvatar(user.fullName, size: 52, round: true),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.fullName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16)),
                          Text(user.email,
                              style: const TextStyle(color: AppColors.textMuted)),
                          const SizedBox(height: 6),
                          StatusBadge(user.role.label, toneForRole(user.role)),
                        ],
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                WhiteCard(
                  child: NavTile(
                    icon: Icons.manage_accounts_outlined,
                    tone: toneBlue,
                    title: 'Tous les utilisateurs',
                    subtitle: 'Comptes, rôles et accès',
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const UserListScreen())),
                  ),
                ),
                const SizedBox(height: 12),
                WhiteCard(
                  child: NavTile(
                    icon: Icons.emoji_events_outlined,
                    tone: toneGold,
                    title: 'Performance des agents',
                    subtitle: 'Visites, affaires, commissions et classement',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const AgentPerformanceScreen())),
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryButton(label: 'Se déconnecter', onPressed: () => _logout(context)),
              ],
            ),
    );
  }
}
