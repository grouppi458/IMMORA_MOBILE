import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../utils/enums.dart';
import '../widgets/primary_button.dart';
import 'login_screen.dart';

/// Accueil provisoire après connexion : affiche le rôle de l'utilisateur.
/// Chaque rôle aura ensuite sa propre page (AdminHomePage, ClientHomePage…).
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
