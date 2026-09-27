import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../utils/enums.dart';
import '../widgets/message_banner.dart';
import 'register_form_screen.dart';

/// Profils qu'un utilisateur peut créer lui-même.
enum AccountRole {
  agence(UserRole.agency, 'Une agence immobilière', 'Gérer biens, agents & transactions',
      'Compte agence', Icons.groups_outlined, AppColors.infoBg, AppColors.primary),
  client(UserRole.client, 'Un client', 'Rechercher un bien à acheter / louer',
      'Compte client', Icons.person_outline, Color(0xFFF6ECD6), AppColors.gold),
  proprietaire(UserRole.owner, 'Un propriétaire', 'Suivre mes biens et leurs visites',
      'Compte propriétaire', Icons.vpn_key_outlined, AppColors.infoBg,
      AppColors.primary);

  const AccountRole(this.userRole, this.title, this.subtitle, this.formTitle,
      this.icon, this.iconBg, this.iconColor);

  final UserRole userRole;
  final String title;
  final String subtitle;
  final String formTitle;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
}

class RegisterChoiceScreen extends StatelessWidget {
  const RegisterChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Créer un compte')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Choisissez votre profil. L’espace agence et le compte sont créés automatiquement.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          const Text(
            'Je suis…',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                for (final role in AccountRole.values) ...[
                  _RoleTile(role: role),
                  if (role != AccountRole.values.last)
                    const Divider(height: 1, color: AppColors.background),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const MessageBanner(
            type: BannerType.info,
            message:
                'Les comptes Agent sont créés par l’agence ; les comptes Admin par IMMORA.',
          ),
        ],
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({required this.role});

  final AccountRole role;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: role.iconBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(role.icon, color: role.iconColor, size: 22),
      ),
      title: Text(
        role.title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        role.subtitle,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RegisterFormScreen(role: role)),
      ),
    );
  }
}
