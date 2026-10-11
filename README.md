# IMMORA Mobile

**L'immobilier, simplifié.** Application mobile SaaS de gestion immobilière pour la Tunisie : agences, biens, annonces, visites et transactions, dans une seule app.

Flutter (Dart) · Material 3 · base locale SQLite (`sqflite`) · fonctionne entièrement hors ligne.

---

## Sommaire

- [Fonctionnalités](#fonctionnalités)
- [Prérequis](#prérequis)
- [Installation et lancement](#installation-et-lancement)
- [Comptes de démonstration](#comptes-de-démonstration)
- [Architecture](#architecture)
- [Structure du projet](#structure-du-projet)
- [Base de données](#base-de-données)
- [Tests](#tests)
- [Travailler à plusieurs](#travailler-à-plusieurs)
- [Dépannage](#dépannage)

---

## Fonctionnalités

L'application est découpée en **6 modules**, chacun dans son propre dossier sous `lib/`.

| # | Module | Dossier | Contenu |
|---|---|---|---|
| M1 | Authentification et utilisateurs | `module_authentification` | Connexion, inscription, session, mot de passe oublié, gestion des comptes et des agents, performance des agents |
| M2 | Agences et abonnements | `module_gestion_agences` | Espace admin, CRUD des agences, plans Free / Basic / Premium, score d'activité, statistiques |
| M3 | Biens | `module_gestion_biens` | Liste, fiche, formulaire, statut et photos des biens, carte, estimation de prix et description IA, espace propriétaire |
| M4 | Ventes et transactions | `module_gestion_ventes` | Transactions (vente, location), échéanciers, paiements, commissions, finances, détection d'anomalies |
| M5 | Annonces | `module_gestion_annonces` | Publication des annonces, recherche, filtres, favoris, matching client-bien, assistant de recherche |
| M6 | Visites | `module_gestion_visites` | Demandes et planification de visites, calendrier, compte rendu, rappels locaux 24 h avant |

Chaque rôle a son propre espace :

| Rôle | Ce qu'il voit |
|---|---|
| **Admin** | Tableau de bord de la plateforme, agences, statistiques, activité, utilisateurs |
| **Agence** | Biens, transactions, alertes, agents, annonces, visites |
| **Agent** | Annonces de son agence et calendrier de ses visites |
| **Client** | Recherche, recommandations, favoris, visites, assistant |
| **Propriétaire** | Ses biens et leurs visites, en lecture seule |

---

## Prérequis

| Outil | Version |
|---|---|
| Flutter | **3.38** ou plus récent |
| Dart | 3.10 (fourni avec Flutter) |
| Android Studio | avec un émulateur Android |

Pour vérifier l'installation :

```bash
flutter doctor
```

---

## Installation et lancement

```bash
git clone https://github.com/grouppi458/IMMORA_MOBILE.git
cd IMMORA_MOBILE
flutter pub get
flutter run
```

Choisissez un émulateur Android comme appareil. Chrome fonctionne aussi pour un aperçu rapide.

**Pour une démonstration**, utilisez le mode release, qui démarre beaucoup plus vite que le mode debug :

```bash
flutter run --release
```

**Pour générer un APK** à installer sur un téléphone :

```bash
flutter build apk --release
```

Le fichier se trouve dans `build/app/outputs/flutter-apk/app-release.apk`.

---

## Comptes de démonstration

Ils sont créés automatiquement au premier lancement, avec des agences, des biens, des annonces, des visites et des transactions de démo.

Mot de passe commun : **`immora123`**

| Rôle | Email |
|---|---|
| Admin | `admin@immora.tn` |
| Agence | `agence@immora.tn` |
| Agent | `agent@immora.tn` |
| Client | `client@immora.tn` |
| Propriétaire | `proprietaire@immora.tn` |

Les comptes créés depuis l'application reçoivent un **mot de passe temporaire**, affiché une seule fois à la création.

---

## Architecture

Chaque module suit le même chemin, toujours dans le même sens :

```
Écran (screens)  →  Provider (ChangeNotifier)  →  Repository  →  DatabaseHelper  →  SQLite
```

| Couche | Rôle |
|---|---|
| `screens/` | Affichage, formulaires et contrôle de saisie |
| `providers/` | État de l'écran (chargement, erreurs), appel du repository puis `notifyListeners()` |
| `repositories/` | Requêtes SQL et règles métier |
| `models/` | Une classe par table, avec `toMap()` / `fromMap()` |
| `services/` | Outils sans base : session, hachage des mots de passe, rappels |
| `ai/` | Algorithmes « intelligents » du module (estimation, anomalies, assistant) |

Les providers sont déclarés une seule fois dans `lib/main.dart` avec `MultiProvider`.

---

## Structure du projet

```
lib/
├── main.dart                       point d'entrée, providers, routage par rôle
├── core/                           partagé par tous les modules
│   ├── database/                   DatabaseHelper, migrations, données de démo
│   ├── errors/                     exceptions métier
│   ├── theme/                      couleurs (Design System Figma) et thème
│   ├── utils/                      constantes, enums, validateurs, formats
│   └── widgets/                    composants communs (boutons, champs, cartes)
├── module_authentification/        M1
├── module_gestion_agences/         M2
├── module_gestion_biens/           M3  (+ ai/ : prix, description)
├── module_gestion_ventes/          M4  (+ ai/ : détection d'anomalies)
├── module_gestion_annonces/        M5  (+ ai/ : assistant, matching/)
└── module_gestion_visites/         M6  (+ services/ : rappels de visite)

test/                               tests unitaires et de repositories
assets/images/                      logo IMMORA
```

---

## Base de données

Fichier SQLite local `immo_saas.db`, ouvert par `DatabaseHelper` (singleton) dans `lib/core/database/database_helper.dart`. Les clés étrangères sont activées (`PRAGMA foreign_keys = ON`).

Version actuelle : **8** (`dbVersion` dans `lib/core/utils/constants.dart`).

| Module | Tables |
|---|---|
| M1 | `users`, `agents`, `activity_logs` |
| M2 | `agencies`, `subscriptions` |
| M3 | `properties`, `property_photos` |
| M4 | `transactions`, `payments`, `alerts` |
| M5 | `listings`, `favorites`, `search_criteria`, `notifications` |
| M6 | `visits` |

**Modifier le schéma :**

1. Ajoutez le `CREATE TABLE` dans `DatabaseHelper`, dans la section de votre module.
2. Augmentez `dbVersion` dans `constants.dart`.
3. Ajoutez un bloc `if (oldVersion < N) { ... }` dans la méthode de migration, pour les téléphones qui ont déjà une ancienne base.

---

## Tests

```bash
flutter test
```

| Fichier | Ce qui est testé |
|---|---|
| `validators_test.dart` | Contrôle de saisie, hachage des mots de passe |
| `admin_logic_test.dart` | Score d'activité, formats, commissions |
| `properties_repository_test.dart` | CRUD des biens |
| `ai_biens_test.dart` | Estimation de prix, description automatique |
| `transactions_repository_test.dart` | Transactions, paiements, alertes |
| `annonces_repository_test.dart` | Annonces et favoris |
| `matching_engine_test.dart` | Score de compatibilité client-bien |
| `assistant_parser_test.dart` | Compréhension des questions de l'assistant |
| `visits_repository_test.dart` | Visites et créneaux |
| `widget_test.dart` | Démarrage de l'application |

Les tests de repositories utilisent une base SQLite en mémoire (`sqflite_common_ffi`), sans téléphone.

Avant chaque push, vérifiez aussi l'analyse statique :

```bash
flutter analyze
```

---

## Travailler à plusieurs

- Récupérez toujours la dernière version avant de commencer :

  ```bash
  git pull origin main
  ```

- Travaillez dans le dossier de **votre** module. Ce qui sert à plusieurs modules va dans `core/`.
- Utilisez les couleurs de `AppColors` (`lib/core/theme/app_colors.dart`), qui suivent le Design System Figma, plutôt que des couleurs écrites en dur.
- Avant de pousser, `flutter analyze` doit être sans erreur et `flutter test` entièrement vert.

---

## Dépannage

**Les écrans sont vides (« Aucun bien », « Aucune visite »)**
L'app a été installée avec une ancienne version de la base. Les données de démo ne sont créées qu'à la première création de la base : désinstallez l'application ou effacez ses données, puis relancez-la.

**`flutter pub get` échoue avec « requires SDK version »**
Votre Flutter est trop ancien. Mettez-le à jour :

```bash
flutter upgrade
```

**Android Studio affiche des dizaines d'erreurs « Target of URI doesn't exist »**
Les dépendances ne sont pas installées. Lancez `flutter pub get`, puis redémarrez l'analyse Dart.

**Démarrage très lent sur l'émulateur**
C'est le mode debug. Utilisez `flutter run --release` pour une démonstration.
