import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/module_gestion_agences/screens/admin_shell.dart';
import 'package:immora_mobile/module_gestion_agences/screens/agency_shell.dart';
import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/module_authentification/models/user.dart';
import 'package:immora_mobile/module_authentification/providers/auth_provider.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/core/widgets/primary_button.dart';
import 'package:immora_mobile/module_gestion_annonces/screens/client_shell.dart';
import 'package:immora_mobile/module_gestion_annonces/screens/listing_list_screen.dart';
import 'package:immora_mobile/module_gestion_annonces/screens/owner_shell.dart';
import 'package:immora_mobile/module_gestion_annonces/screens/visit_calendar_screen.dart';
import 'package:immora_mobile/module_authentification/screens/login_screen.dart';

/// BF1.6 — redirection vers l'accueil propre au rôle après connexion.
/// Les menus non autorisés n'existent tout simplement pas dans les autres espaces.
Widget homeForUser(User user) => switch (user.role) {
      UserRole.admin => const AdminShell(), // Module 2 : espace administrateur
      UserRole.agency => const AgencyShell(), // Modules 3–4 : espace pro (biens, ventes)
      UserRole.client => const ClientShell(), // Module 5 : vitrine, favoris
      UserRole.owner => const OwnerShell(), // Module 6 : visites de mes biens
      _ => const HomeScreen(), // agent : accueil provisoire (M3)
    };

/// Accueil provisoire des rôles agent, client et propriétaire : les modules
/// 3 à 6 (Ingénieurs 2 et 3) remplaceront cette page par leur propre accueil.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('IMMORA', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'Déconnexion',
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: user == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bonjour ${user.fullName}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(user.role.label),
                    backgroundColor: AppColors.sand,
                    side: BorderSide.none,
                  ),
                  const SizedBox(height: 8),
                  Text(user.email, style: const TextStyle(color: AppColors.textMuted)),
                  const SizedBox(height: 24),
                  // Module 5 (Ing. 3) — l'agent gère les annonces de son agence.
                  if (user.role == UserRole.agent && user.agencyId != null) ...[
                    WhiteCard(
                      child: NavTile(
                        icon: Icons.campaign_outlined,
                        tone: toneGreen,
                        title: 'Annonces de l’agence',
                        subtitle: 'Publier, suspendre, prolonger · vues et favoris',
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ListingListScreen(agencyId: user.agencyId!))),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Module 6 (Ing. 3) — visites assignées à l'agent.
                    WhiteCard(
                      child: NavTile(
                        icon: Icons.event_outlined,
                        tone: toneAgent,
                        title: 'Mes visites',
                        subtitle: 'Confirmer, reprogrammer, effectuer',
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => VisitCalendarScreen(
                                agencyId: user.agencyId!, agentUserId: user.id))),
                      ),
                    ),
                  ] else
                    const Text(
                      'Votre espace est en cours de construction.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  const Spacer(),
                  PrimaryButton(label: 'Se déconnecter', onPressed: () => _logout(context)),
                ],
              ),
            ),
    );
  }
}
