import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'package:immora_mobile/core/notifications/visit_reminders.dart';
import 'package:immora_mobile/core/theme/app_theme.dart';
import 'package:immora_mobile/module_authentification/providers/auth_provider.dart';
import 'package:immora_mobile/module_authentification/providers/user_admin_provider.dart';
import 'package:immora_mobile/module_authentification/screens/splash_screen.dart';
import 'package:immora_mobile/module_gestion_agences/providers/agency_provider.dart';
import 'package:immora_mobile/module_gestion_annonces/providers/client_listing_provider.dart';
import 'package:immora_mobile/module_gestion_annonces/providers/listing_provider.dart';
import 'package:immora_mobile/module_gestion_annonces/providers/matching_provider.dart';
import 'package:immora_mobile/module_gestion_annonces/providers/visit_provider.dart';
import 'package:immora_mobile/module_gestion_biens/providers/property_provider.dart';
import 'package:immora_mobile/module_gestion_ventes/providers/alert_provider.dart';
import 'package:immora_mobile/module_gestion_ventes/providers/transaction_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Dans le navigateur, SQLite tourne en WebAssembly (fichier web/sqlite3.wasm)
  // et la base est gardée dans IndexedDB ; sur Android, sqflite utilise la base native.
  if (kIsWeb) databaseFactory = databaseFactoryFfiWebNoWebWorker;
  // Rappels locaux « 24 h avant visite » (no-op sur le web).
  await VisitReminderService.instance.init();
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
        // Module 5 — annonces (côté agence / agent)
        ChangeNotifierProvider(create: (_) => ListingProvider()),
        // Module 5 — vitrine et favoris (côté client)
        ChangeNotifierProvider(create: (_) => ClientListingProvider()),
        // Module 5 — recherche intelligente, matching et alertes (fonction avancée)
        ChangeNotifierProvider(
            create: (ctx) => MatchingProvider(ctx.read<ClientListingProvider>())),
        // Module 6 — visites (client : « Mes visites » · agence/agent : à traiter)
        ChangeNotifierProvider(create: (_) => VisitProvider()),
        // Module 3 — biens : liste, formulaire, photos, carte et IA
        ChangeNotifierProvider(create: (_) => PropertyProvider()),
        // Module 4 — transactions : cycle de vie, paiements et finances
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        // Module 4 — alertes d'anomalie de l'agence
        ChangeNotifierProvider(create: (_) => AlertProvider()),
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
