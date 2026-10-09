import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/module_authentification/providers/auth_provider.dart';
import 'package:immora_mobile/module_gestion_annonces/providers/client_listing_provider.dart';
import 'package:immora_mobile/module_gestion_annonces/screens/client_home_screen.dart';
import 'package:immora_mobile/module_gestion_annonces/screens/favorites_screen.dart';
import 'package:immora_mobile/module_gestion_annonces/screens/search_screen.dart';

/// Espace client (BF1.6) : barre de navigation « Navigation bar · client »
/// Accueil · Recherche · Favoris · Visites · Assistant.
class ClientShell extends StatefulWidget {
  const ClientShell({super.key});

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = context.read<AuthProvider>().currentUser?.id;
      if (id != null) context.read<ClientListingProvider>().load(id);
    });
  }

  void _go(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: [
        ClientHomeScreen(onSearch: () => _go(1)),
        // Fonction avancée du M5 : recherche intelligente et matching (BF5.6, BF5.7).
        SearchScreen(onBack: () => _go(0)),
        FavoritesScreen(onExplore: () => _go(0)),
        // Module 6 (visites et assistant).
        const _ComingSoon(
          title: 'Mes visites',
          icon: Icons.event_outlined,
          message: 'Vos demandes de visite apparaîtront ici avec le module Visites.',
        ),
        const _ComingSoon(
          title: 'Assistant',
          icon: Icons.chat_bubble_outline,
          message: 'L’assistant immobilier arrive avec le module Visites.',
        ),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.infoBg,
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Recherche'),
          NavigationDestination(
              icon: Icon(Icons.favorite_border),
              selectedIcon: Icon(Icons.favorite),
              label: 'Favoris'),
          NavigationDestination(
              icon: Icon(Icons.event_outlined),
              selectedIcon: Icon(Icons.event),
              label: 'Visites'),
          NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'Assistant'),
        ],
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.title, required this.icon, required this.message});

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
            Icon(icon, size: 44, color: AppColors.secondary),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted, height: 1.4)),
          ]),
        ),
      ),
    );
  }
}
