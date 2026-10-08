import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_theme.dart';
import 'package:immora_mobile/module_authentification/providers/auth_provider.dart';
import 'package:immora_mobile/module_authentification/providers/user_admin_provider.dart';
import 'package:immora_mobile/module_authentification/screens/splash_screen.dart';
import 'package:immora_mobile/module_gestion_agences/providers/agency_provider.dart';

void main() {
  runApp(const ImmoraApp());
}

class ImmoraApp extends StatelessWidget {
  const ImmoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Module 1 — authentification et session
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // Module 2 — agences et abonnements
        ChangeNotifierProvider(create: (_) => AgencyProvider()),
        // Module 1 — gestion des utilisateurs. Après chaque modification, il
        // demande au Module 2 de recharger ses compteurs (si l'espace admin
        // les a déjà chargés).
        ChangeNotifierProvider(
          create: (ctx) {
            final agencies = ctx.read<AgencyProvider>();
            return UserAdminProvider(
              onDataChanged: () async {
                if (agencies.agencies.isNotEmpty) await agencies.load();
              },
            );
          },
        ),
      ],
      child: MaterialApp(
        title: 'IMMORA',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        // Interface Material en français (calendrier, boutons système…).
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const SplashScreen(),
      ),
    );
  }
}
