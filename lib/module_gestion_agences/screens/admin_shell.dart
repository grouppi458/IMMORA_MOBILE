import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/module_gestion_agences/providers/agency_provider.dart';
import 'package:immora_mobile/module_gestion_agences/screens/activity_screen.dart';
import 'package:immora_mobile/module_gestion_agences/screens/admin_home_screen.dart';
import 'package:immora_mobile/module_authentification/screens/profile_screen.dart';
import 'package:immora_mobile/module_gestion_agences/screens/agency_list_screen.dart';
import 'package:immora_mobile/module_gestion_agences/screens/stats_screen.dart';

/// Espace administrateur : barre de navigation du bas à 5 onglets.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // Charge les données dès l'ouverture de l'espace admin.
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AgencyProvider>().load());
  }

  void _openTab(int index) => setState(() => _tab = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // IndexedStack garde chaque onglet en mémoire (filtres, défilement).
      body: IndexedStack(
        index: _tab,
        children: [
          AdminHomeScreen(onOpenTab: _openTab),
          const AgencyListScreen(),
          const StatsScreen(),
          const ActivityScreen(),
          const AdminProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _openTab,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.infoBg,
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard, color: AppColors.primary), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.apartment_outlined),
              selectedIcon: Icon(Icons.apartment, color: AppColors.primary), label: 'Agences'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart, color: AppColors.primary), label: 'Stats'),
          NavigationDestination(icon: Icon(Icons.monitor_heart_outlined),
              selectedIcon: Icon(Icons.monitor_heart, color: AppColors.primary), label: 'Activité'),
          NavigationDestination(icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: AppColors.primary), label: 'Profil'),
        ],
      ),
    );
  }
}
