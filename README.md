# IMMORA Mobile

Application mobile SaaS immobilière — Flutter (Dart), base locale SQLite (`sqflite`), fonctionne hors ligne.

## Lancer le projet

```bash
flutter pub get
flutter run
```

Choisir un émulateur Android (ou Chrome) comme appareil.

## Comptes de démonstration

Créés automatiquement au premier lancement (mot de passe : `immora123`) :

| Rôle | Email |
|---|---|
| Admin | admin@immora.tn |
| Agence | agence@immora.tn |
| Agent | agent@immora.tn |
| Client | client@immora.tn |
| Propriétaire | proprietaire@immora.tn |

## Structure

```
lib/
├── main.dart
├── authentification/     écrans et widgets d'authentification
├── core/theme/           couleurs et thème IMMORA
├── data/                 database_helper.dart, demo_data.dart, repositories/
├── models/               une classe par table (toMap / fromMap)
├── providers/            ChangeNotifier (AuthProvider…)
├── services/             session (shared_preferences), mot de passe (SHA-256 + sel)
└── utils/                enums, constantes, validators (contrôle de saisie)
```

Architecture : Page → Provider → Repository → DatabaseHelper.

## Modules

- **Ingénieur 1** — socle, authentification, comptes, agences, abonnements, statistiques
- **Ingénieur 2** — biens, propriétaires, transactions
- **Ingénieur 3** — clients, recherche, visites, matching

Chaque ingénieur ajoute ses `CREATE TABLE` dans `lib/data/database_helper.dart`.
