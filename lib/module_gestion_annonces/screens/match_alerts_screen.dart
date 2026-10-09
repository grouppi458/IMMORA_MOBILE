import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/module_gestion_annonces/matching/matching_engine.dart';
import 'package:immora_mobile/module_gestion_annonces/providers/client_listing_provider.dart';
import 'package:immora_mobile/module_gestion_annonces/providers/matching_provider.dart';
import 'package:immora_mobile/module_gestion_annonces/screens/listing_detail_screen.dart';
import 'package:immora_mobile/module_gestion_annonces/widgets/client_listing_cards.dart';

/// « Nouveaux biens pour vous » [matchAlerts] — BF5.9 : les annonces publiées
/// qui ont atteint 80 % de compatibilité, groupées par date.
class MatchAlertsScreen extends StatefulWidget {
  const MatchAlertsScreen({super.key});

  @override
  State<MatchAlertsScreen> createState() => _MatchAlertsScreenState();
}

class _MatchAlertsScreenState extends State<MatchAlertsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<MatchingProvider>().refreshNotifications());
  }

  Future<void> _open(ListingAlert a) async {
    final matching = context.read<MatchingProvider>();
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ListingDetailScreen(listingId: a.details.listing.id!)));
    await matching.markRead(a.notification);
  }

  @override
  Widget build(BuildContext context) {
    final matching = context.watch<MatchingProvider>();
    final favorites = context.watch<ClientListingProvider>();
    final alerts = matching.listingAlerts;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final weekAgo = today - 6 * Duration.millisecondsPerDay;
    final groups = <String, List<ListingAlert>>{
      'Aujourd’hui': alerts.where((a) => a.notification.createdAt >= today).toList(),
      'Cette semaine': alerts
          .where((a) => a.notification.createdAt < today && a.notification.createdAt >= weekAgo)
          .toList(),
      'Plus tôt': alerts.where((a) => a.notification.createdAt < weekAgo).toList(),
    }..removeWhere((_, list) => list.isEmpty);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, 'Nouveaux biens pour vous'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        WhiteCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.auto_awesome, size: 18, color: AppColors.gold),
              SizedBox(width: 8),
              Text('Comment sont choisis ces biens ?',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 6),
            Text(
              'Score = 35 % budget + 25 % zone + 20 % chambres + 10 % type + 10 % surface. '
              'Vous êtes alerté dès qu’une nouvelle annonce atteint ${MatchingEngine.alertScore} %.',
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.4),
            ),
            if (matching.profile?.alertsEnabled == false) ...[
              const SizedBox(height: 6),
              const Text('Vos alertes sont désactivées dans « Mes critères ».',
                  style: TextStyle(fontSize: 12.5, color: AppColors.error)),
            ],
          ]),
        ),
        const SizedBox(height: 14),
        if (alerts.isEmpty)
          const WhiteCard(
            padding: EdgeInsets.all(20),
            child: Text(
              'Aucune nouvelle annonce ne vous correspond encore. Vous serez prévenu '
              'dès qu’un bien atteindra 80 % de compatibilité.',
              style: TextStyle(color: AppColors.textMuted, height: 1.4),
            ),
          ),
        for (final entry in groups.entries) ...[
          SectionTitle(entry.key),
          const SizedBox(height: 6),
          for (final (i, a) in entry.value.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: i == 0 && entry.key == groups.keys.first
                  ? PublicListingCard(
                      details: a.details,
                      match: a.match,
                      isFavorite: favorites.isFavorite(a.details.listing.id!),
                      onTap: () => _open(a),
                      onFavorite: () => favorites.toggleFavorite(a.details.listing.id!),
                    )
                  : CompactListingCard(details: a.details, match: a.match, onTap: () => _open(a)),
            ),
          const SizedBox(height: 6),
        ],
      ]),
    );
  }
}
