import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/module_gestion_annonces/models/listing_details.dart';
import 'package:immora_mobile/module_gestion_annonces/providers/client_listing_provider.dart';
import 'package:immora_mobile/module_gestion_annonces/screens/listing_detail_screen.dart';
import 'package:immora_mobile/module_gestion_annonces/widgets/client_listing_cards.dart';

/// « Favoris » [favorites] et son état vide [favoritesEmpty] — BF5.2, BF5.5.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key, required this.onExplore});

  /// « Explorer les biens » : retour à l'onglet Accueil.
  final VoidCallback onExplore;

  Future<void> _remove(BuildContext context, ListingDetails d) async {
    final provider = context.read<ClientListingProvider>();
    final error = await provider.toggleFavorite(d.listing.id!);
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      backgroundColor: error == null ? null : AppColors.error,
      content: Text(error ?? 'Retiré des favoris'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClientListingProvider>();
    final favorites = provider.favorites;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, 'Mes favoris'),
      body: provider.isLoading && favorites.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : favorites.isEmpty
              ? _EmptyState(onExplore: onExplore)
              : RefreshIndicator(
                  onRefresh: () => provider.load(provider.clientId!),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        favorites.length == 1
                            ? '1 bien enregistré'
                            : '${favorites.length} biens enregistrés',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 10),
                      for (final d in favorites)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: CompactListingCard(
                            details: d,
                            favoriteOnPhoto: true,
                            onFavorite: () => _remove(context, d),
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => ListingDetailScreen(listingId: d.listing.id!))),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.infoBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Vos favoris affinent vos recommandations quand vous '
                                'n’avez pas encore de critères.',
                                style: TextStyle(
                                    fontSize: 12.5, height: 1.4, color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.favorite_border, size: 40, color: AppColors.secondary),
          ),
          const SizedBox(height: 16),
          const Text('Aucun favori pour l’instant',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'Touchez le cœur sur un bien pour le retrouver ici.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
          ),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: onExplore,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.border),
              shape: const StadiumBorder(),
              minimumSize: const Size(159, 46),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            child: const Text('Explorer les biens'),
          ),
        ]),
      ),
    );
  }
}
