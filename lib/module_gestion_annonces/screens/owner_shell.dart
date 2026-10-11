import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/core/widgets/primary_button.dart';
import 'package:immora_mobile/module_authentification/providers/auth_provider.dart';
import 'package:immora_mobile/module_authentification/screens/login_screen.dart';
import 'package:immora_mobile/module_gestion_annonces/screens/owner_visits_screen.dart';
import 'package:immora_mobile/module_gestion_biens/screens/owner_home_screen.dart';
import 'package:immora_mobile/module_gestion_biens/screens/owner_properties_screen.dart';

/// Espace propriétaire (M3–M6 · maquettes Figma) : Accueil (chiffres clés),
/// Mes biens et Visites de ses biens, en consultation ; Profil.
class OwnerShell extends StatefulWidget {
  const OwnerShell({super.key});

  @override
  State<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends State<OwnerShell> {
  int _index = 0; // la livraison M3–M6 arrive sur l’accueil propriétaire

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: [
        OwnerHomeScreen(onSeeAll: () => setState(() => _index = 1)),
        const OwnerPropertiesScreen(),
        const OwnerVisitsScreen(),
        const _OwnerProfileTab(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.infoBg,
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Accueil'),
          NavigationDestination(
              icon: Icon(Icons.description_outlined),
              selectedIcon: Icon(Icons.description),
              label: 'Mes biens'),
          NavigationDestination(
              icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: 'Visites'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}

class _OwnerProfileTab extends StatelessWidget {
  const _OwnerProfileTab();

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
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, 'Profil'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          WhiteCard(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.infoBg,
                child: Text(initialsOf(user.fullName),
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ),
              const SizedBox(height: 12),
              Text(user.fullName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              const SizedBox(height: 4),
              Text(user.email, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: AppColors.infoBg, borderRadius: BorderRadius.circular(20)),
                child: Text(user.role.label,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          WhiteCard(
            child: Column(children: [
              InfoRow('Téléphone', user.phone.isEmpty ? '—' : user.phone),
              const Divider(height: 1, thickness: 1, color: AppColors.border),
              InfoRow('CIN', user.cin ?? '—'),
              const Divider(height: 1, thickness: 1, color: AppColors.border),
              InfoRow('Adresse', user.address ?? '—'),
            ]),
          ),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Se déconnecter', onPressed: () => _logout(context)),
        ],
      ),
    );
  }
}
