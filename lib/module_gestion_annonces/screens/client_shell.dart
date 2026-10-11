import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/module_authentification/providers/auth_provider.dart';
import 'package:immora_mobile/module_gestion_annonces/providers/client_listing_provider.dart';
import 'package:immora_mobile/module_gestion_annonces/screens/assistant_screen.dart';
import 'package:immora_mobile/module_gestion_annonces/screens/client_home_screen.dart';
import 'package:immora_mobile/module_gestion_visites/screens/client_visits_screen.dart';
import 'package:immora_mobile/module_gestion_annonces/screens/favorites_screen.dart';
import 'package:immora_mobile/module_gestion_annonces/screens/search_screen.dart';

/// Espace client (BF1.6) : barre de navigation « Navigation bar · client »
/// Accueil · Recherche · Favoris · Visites · Assistant.
class ClientShell extends StatefulWidget {
  const ClientShell({super.key});

  /// Ouvre un onglet depuis un écran profond (« Voir mes visites » après
  /// l'envoi d'une demande). Renseigné par la coquille à son initialisation.
  static void Function(int index)? openTab;

  static const int visitsTab = 3;

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    ClientShell.openTab = _go;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = context.read<AuthProvider>().currentUser?.id;
      if (id != null) context.read<ClientListingProvider>().load(id);
    });
  }

  @override
  void dispose() {
    if (ClientShell.openTab == _go) ClientShell.openTab = null;
    super.dispose();
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
        // Module 6 (Ing. 3) : visites et assistant.
        ClientVisitsScreen(onExplore: () => _go(1)),
        const AssistantScreen(),
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

