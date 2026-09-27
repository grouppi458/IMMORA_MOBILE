import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../widgets/immora_logo.dart';
import '../widgets/primary_button.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  /// Va directement à l'accueil si « Se souvenir » était coché.
  Future<void> _start(BuildContext context) async {
    final loggedIn = await context.read<AuthProvider>().restoreSession();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => loggedIn ? const HomeScreen() : const LoginScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            children: [
              const Spacer(),
              const ImmoraLogo(height: 80),
              const SizedBox(height: 28),
              const Text(
                'L’immobilier, simplifié',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'SaaS immobilier · Tunisie',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),
              const _Dots(),
              const Spacer(),
              PrimaryButton(
                label: 'Commencer',
                color: AppColors.gold,
                onPressed: () => _start(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots();

  @override
  Widget build(BuildContext context) {
    Widget dot(double width) => Container(
          width: width,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
          ),
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [dot(18), dot(6), dot(6)],
    );
  }
}
