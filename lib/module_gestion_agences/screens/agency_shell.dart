import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/core/widgets/primary_button.dart';
import 'package:immora_mobile/module_authentification/providers/auth_provider.dart';
import 'package:immora_mobile/module_authentification/screens/login_screen.dart';
import 'package:immora_mobile/module_gestion_agences/screens/agency_space_screen.dart';
import 'package:immora_mobile/module_gestion_biens/screens/property_list_screen.dart';
import 'package:immora_mobile/module_gestion_ventes/providers/alert_provider.dart';
import 'package:immora_mobile/module_gestion_ventes/screens/alert_list_screen.dart';
import 'package:immora_mobile/module_gestion_ventes/screens/transaction_list_screen.dart';

/// Espace pro « agence » — barre à 5 onglets des maquettes M4 :
/// Accueil · Biens · Ventes · Alertes · Profil.
class AgencyShell extends StatefulWidget {
  const AgencyShell({super.key});

  @override
  State<AgencyShell> createState() => _AgencyShellState();
}

class _AgencyShellState extends State<AgencyShell> {
  int _index = 1; // la livraison M3 arrive sur l'onglet Biens (maquettes M3–M4)

  @override
  Widget build(BuildContext context) {
    final agencyId = context.watch<AuthProvider>().currentUser?.agencyId;
    final unreadAlerts = context.watch<AlertProvider>().counts.unread;

    return Scaffold(
      body: IndexedStack(index: _index, children: [
        const AgencySpaceScreen(),
        agencyId == null
            ? const _PlaceholderTab(
                title: 'Biens',
                icon: Icons.description_outlined,
                message: 'Agence introuvable pour ce compte.')
            : PropertyListScreen(agencyId: agencyId),
        agencyId == null
            ? const _PlaceholderTab(
                title: 'Ventes',
                icon: Icons.swap_horiz,
                message: 'Agence introuvable pour ce compte.')
            : TransactionListScreen(agencyId: agencyId),
        agencyId == null
            ? const _PlaceholderTab(
                title: 'Alertes',
                icon: Icons.notifications_none,
                message: 'Agence introuvable pour ce compte.')
            : AlertListScreen(agencyId: agencyId),
        const _AgencyProfileTab(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.infoBg,
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view),
              label: 'Accueil'),
          const NavigationDestination(
              icon: Icon(Icons.description_outlined),
              selectedIcon: Icon(Icons.description),
              label: 'Biens'),
          const NavigationDestination(icon: Icon(Icons.swap_horiz), label: 'Ventes'),
          NavigationDestination(
              icon: _AlertsIcon(Icons.notifications_none, unreadAlerts),
              selectedIcon: _AlertsIcon(Icons.notifications, unreadAlerts),
              label: 'Alertes'),
          const NavigationDestination(
              icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}

/// Icône « Alertes » avec la pastille du nombre de non-lues.
class _AlertsIcon extends StatelessWidget {
  const _AlertsIcon(this.icon, this.unread);

  final IconData icon;
  final int unread;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: unread > 0,
      label: Text('$unread'),
      child: Icon(icon),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.title, required this.icon, required this.message});

  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, title),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72,
              height: 72,
              decoration:
                  BoxDecoration(color: AppColors.infoBg, borderRadius: BorderRadius.circular(20)),
              child: Icon(icon, size: 34, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.5)),
          ]),
        ),
      ),
    );
  }
}

class _AgencyProfileTab extends StatelessWidget {
  const _AgencyProfileTab();

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
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              const SizedBox(height: 4),
              Text(user.email, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration:
                    BoxDecoration(color: AppColors.infoBg, borderRadius: BorderRadius.circular(20)),
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
