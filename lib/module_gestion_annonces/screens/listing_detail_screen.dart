import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/core/widgets/message_banner.dart';
import 'package:immora_mobile/module_gestion_annonces/models/listing_details.dart';
import 'package:immora_mobile/module_gestion_annonces/providers/client_listing_provider.dart';
import 'package:immora_mobile/module_gestion_annonces/providers/matching_provider.dart';
import 'package:immora_mobile/module_gestion_annonces/widgets/client_listing_cards.dart';
import 'package:immora_mobile/module_gestion_annonces/widgets/listing_card.dart';
import 'package:immora_mobile/module_gestion_annonces/widgets/listing_map.dart';
import 'package:immora_mobile/module_gestion_annonces/widgets/match_widgets.dart';

/// « Bien (vue publique + compatibilité) » [propPublic] — BF5.3 : fiche
/// détaillée d'une annonce pour le client (l'ouverture compte une vue) ;
/// BF5.7 : score de compatibilité et détail par composante.
class ListingDetailScreen extends StatefulWidget {
  const ListingDetailScreen({super.key, required this.listingId});

  final int listingId;

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  late final Future<ListingDetails?> _future =
      context.read<ClientListingProvider>().open(widget.listingId);

  Future<void> _toggleFavorite() async {
    final provider = context.read<ClientListingProvider>();
    final wasFavorite = provider.isFavorite(widget.listingId);
    final error = await provider.toggleFavorite(widget.listingId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: error == null ? null : AppColors.error,
      content: Text(error ?? (wasFavorite ? 'Retiré des favoris' : 'Ajouté aux favoris')),
    ));
  }

  void _requestVisit() {
    // Module 6 (visites) : le formulaire « Demander une visite » arrive avec le M6.
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('La demande de visite sera disponible avec le module Visites.')));
  }

  void _showContact(ListingDetails d) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(d.agencyName),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (d.agentName != null)
                Text('Agent : ${d.agentName}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 8),
              SelectableText(d.agencyPhone.isEmpty ? 'Téléphone non renseigné' : d.agencyPhone,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ]),
        actions: [
          if (d.agencyPhone.isNotEmpty)
            TextButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: d.agencyPhone)),
              child: const Text('Copier'),
            ),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fermer')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = context.watch<ClientListingProvider>().isFavorite(widget.listingId);

    return FutureBuilder<ListingDetails?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final d = snap.data;
        if (d == null) {
          return Scaffold(
            appBar: adminAppBar(context, 'Annonce'),
            body: const Padding(
              padding: EdgeInsets.all(16),
              child: MessageBanner(type: BannerType.error, message: 'Annonce introuvable.'),
            ),
          );
        }
        final online = d.listing.status == ListingStatus.published;
        final matching = context.watch<MatchingProvider>();
        final match = matching.matchFor(d);
        return Scaffold(
          backgroundColor: AppColors.background,
          bottomNavigationBar: _BottomBar(
            isFavorite: isFavorite,
            canFavorite: online || isFavorite,
            canVisit: online,
            onFavorite: _toggleFavorite,
            onVisit: _requestVisit,
          ),
          body: CustomScrollView(slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 240,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              actions: [
                IconButton(
                  tooltip: isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
                  icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                  onPressed: online || isFavorite ? _toggleFavorite : null,
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: ListingPhoto(type: d.property.type, iconSize: 72, children: [
                  Positioned(left: 12, bottom: 12, child: listingBadge(d)),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList.list(children: [
                if (!online) ...[
                  const MessageBanner(
                    type: BannerType.info,
                    message: 'Cette annonce n’est plus en ligne. Vous pouvez la retirer '
                        'de vos favoris.',
                  ),
                  const SizedBox(height: 14),
                ],
                if (match != null) ...[
                  CompatibilityCard(
                    match: match,
                    subject: '${d.property.type.label}${d.property.rooms > 0 ? ' S+${d.property.rooms}' : ''}',
                    source: matching.profileSource == ProfileSource.criteria
                        ? 'Selon vos critères'
                        : 'D’après vos favoris',
                  ),
                  const SizedBox(height: 16),
                ],
                Row(children: [
                  Expanded(
                    child: Text(d.listing.title,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(d.property.dealType.label, toneBlue),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.place_outlined, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(d.property.location,
                        style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
                  ),
                ]),
                const SizedBox(height: 10),
                ListingPrice(price: d.listing.displayedPrice, deal: d.property.dealType, fontSize: 24),
                const SizedBox(height: 14),
                _KeyFigures(details: d),
                if (d.property.amenities.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final a in d.property.amenities)
                      Chip(
                        label: Text(_amenityLabel(a)),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: AppColors.border),
                        labelStyle: const TextStyle(fontSize: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                  ]),
                ],
                const SizedBox(height: 18),
                const SectionTitle('Description'),
                const SizedBox(height: 6),
                Text(d.listing.text,
                    style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textDark)),
                const SizedBox(height: 18),
                const SectionTitle('Localisation'),
                const SizedBox(height: 8),
                LocationMap(details: d),
                const SizedBox(height: 14),
                WhiteCard(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: InitialsAvatar(d.agencyName, round: true),
                    title: Text(d.agencyName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                        d.agentName == null ? 'Agence' : 'Agence · ${d.agentName}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    trailing: IconButton(
                      tooltip: 'Contacter l’agence',
                      icon: const Icon(Icons.phone_outlined, color: AppColors.primary),
                      onPressed: () => _showContact(d),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

String _amenityLabel(String a) => switch (a) {
      'parking' => 'Parking',
      'piscine' => 'Piscine',
      'jardin' => 'Jardin',
      'ascenseur' => 'Ascenseur',
      _ => a.isEmpty ? a : a[0].toUpperCase() + a.substring(1),
    };

/// Trois cartes : chambres, salles de bain, surface.
class _KeyFigures extends StatelessWidget {
  const _KeyFigures({required this.details});

  final ListingDetails details;

  @override
  Widget build(BuildContext context) {
    final p = details.property;
    final hasRooms = p.type != PropertyType.land && p.type != PropertyType.office;
    return Row(children: [
      if (hasRooms) ...[
        Expanded(child: _Figure(Icons.bed_outlined, '${p.rooms}', 'Chambres')),
        const SizedBox(width: 10),
        Expanded(child: _Figure(Icons.bathtub_outlined, '${p.bathrooms}', 'SdB')),
        const SizedBox(width: 10),
      ],
      Expanded(child: _Figure(Icons.square_foot, '${p.surface.round()}', 'm²')),
      if (!hasRooms) ...[
        const SizedBox(width: 10),
        Expanded(child: _Figure(iconForPropertyType(p.type), p.type.label, 'Type')),
      ],
    ]);
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.icon, this.value, this.label);

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => WhiteCard(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(children: [
          Icon(icon, color: AppColors.secondary),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ]),
      );
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.isFavorite,
    required this.canFavorite,
    required this.canVisit,
    required this.onFavorite,
    required this.onVisit,
  });

  final bool isFavorite;
  final bool canFavorite;
  final bool canVisit;
  final VoidCallback onFavorite;
  final VoidCallback onVisit;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(
        top: false,
        child: Row(children: [
          OutlinedButton.icon(
            onPressed: canFavorite ? onFavorite : null,
            icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? AppColors.error : AppColors.primary, size: 18),
            label: const Text('Favori'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              minimumSize: const Size(112, 46),
              side: const BorderSide(color: AppColors.border),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: canVisit ? onVisit : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(46),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              child: const Text('Demander une visite'),
            ),
          ),
        ]),
      ),
    );
  }
}
