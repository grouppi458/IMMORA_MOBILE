import 'package:flutter/material.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/module_gestion_annonces/matching/matching_engine.dart';
import 'package:immora_mobile/module_gestion_annonces/models/listing_details.dart';
import 'package:immora_mobile/module_gestion_annonces/widgets/listing_card.dart';
import 'package:immora_mobile/module_gestion_annonces/widgets/match_widgets.dart';

/// Badge de la photo côté client : « À la une », sinon « À vendre » / « À louer ».
Widget listingBadge(ListingDetails d) {
  if (d.listing.status != ListingStatus.published) {
    return StatusBadge(d.listing.status.label, toneForListingStatus(d.listing.status));
  }
  if (d.listing.isFeatured) return const StatusBadge('À la une', toneGold);
  return StatusBadge(
      d.property.dealType == DealType.rent ? 'À louer' : 'À vendre', toneBlue);
}

/// Fond de photo (dégradé de la charte + icône du type de bien).
class ListingPhoto extends StatelessWidget {
  const ListingPhoto({super.key, required this.type, this.iconSize = 38, this.children = const []});

  final PropertyType type;
  final double iconSize;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.secondary, AppColors.primary],
        ),
      ),
      child: Stack(children: [
        Center(
          child: Icon(iconForPropertyType(type),
              size: iconSize, color: Colors.white.withValues(alpha: 0.55)),
        ),
        ...children,
      ]),
    );
  }
}

/// Bouton cœur rond blanc (« Favorite toggle »).
class FavoriteToggle extends StatelessWidget {
  const FavoriteToggle({super.key, required this.active, required this.onPressed});

  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(active ? Icons.favorite : Icons.favorite_border,
              size: 20, color: active ? AppColors.error : AppColors.textDark),
        ),
      ),
    );
  }
}

/// Lit · bain · surface (« 3  2  145 m² »).
class PropertySpecs extends StatelessWidget {
  const PropertySpecs({super.key, required this.details, this.showBaths = true});

  final ListingDetails details;
  final bool showBaths;

  @override
  Widget build(BuildContext context) {
    final p = details.property;
    final hasRooms = p.type != PropertyType.land && p.type != PropertyType.office;
    return Wrap(spacing: 12, children: [
      if (hasRooms) _Spec(Icons.bed_outlined, '${p.rooms}'),
      if (hasRooms && showBaths) _Spec(Icons.bathtub_outlined, '${p.bathrooms}'),
      _Spec(Icons.square_foot, '${p.surface.round()} m²'),
    ]);
  }
}

class _Spec extends StatelessWidget {
  const _Spec(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ]);
}

class _Location extends StatelessWidget {
  const _Location(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Row(children: [
        const Icon(Icons.place_outlined, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Expanded(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ),
      ]);
}

/// Grande carte de la vitrine [clientHome] : photo 150 px, badge, score de
/// compatibilité (BF5.7), cœur, titre, lieu, prix, caractéristiques et raisons.
class PublicListingCard extends StatelessWidget {
  const PublicListingCard({
    super.key,
    required this.details,
    required this.isFavorite,
    required this.onTap,
    required this.onFavorite,
    this.match,
  });

  final ListingDetails details;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final MatchResult? match;

  @override
  Widget build(BuildContext context) {
    final l = details.listing;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: 150,
            width: double.infinity,
            child: ListingPhoto(type: details.property.type, iconSize: 44, children: [
              Positioned(left: 8, top: 8, child: listingBadge(details)),
              if (match != null)
                Positioned(right: 50, top: 6, child: MatchScoreBadge(score: match!.score)),
              Positioned(
                right: 8,
                top: 8,
                child: FavoriteToggle(active: isFavorite, onPressed: onFavorite),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              _Location(details.property.location),
              const SizedBox(height: 4),
              ListingPrice(price: l.displayedPrice, deal: details.property.dealType),
              const SizedBox(height: 6),
              PropertySpecs(details: details),
              if (match != null && match!.reasons.isNotEmpty) ...[
                const SizedBox(height: 6),
                MatchReasons(reasons: match!.reasons),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Carte compacte (photo 112 px à gauche) : « Récemment consultés », favoris,
/// résultats de recherche et alertes. [favoriteOnPhoto] = cœur sur la photo
/// et caractéristiques au lieu du lieu ; [match] = score à côté du titre.
class CompactListingCard extends StatelessWidget {
  const CompactListingCard({
    super.key,
    required this.details,
    required this.onTap,
    this.onFavorite,
    this.favoriteOnPhoto = false,
    this.isFavorite = true,
    this.match,
  });

  final ListingDetails details;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;
  final bool favoriteOnPhoto;
  final bool isFavorite;
  final MatchResult? match;

  @override
  Widget build(BuildContext context) {
    final l = details.listing;
    final online = l.status == ListingStatus.published;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 112,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 88),
                child: ListingPhoto(type: details.property.type, children: [
                  if (!favoriteOnPhoto || !online)
                    Positioned(left: 8, top: 8, child: listingBadge(details)),
                  if (favoriteOnPhoto && onFavorite != null)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: FavoriteToggle(active: isFavorite, onPressed: onFavorite!),
                    ),
                ]),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Text(l.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                      if (match != null) ...[
                        const SizedBox(width: 6),
                        MatchScoreBadge(score: match!.score, size: 40),
                      ],
                    ]),
                    const SizedBox(height: 4),
                    if (!favoriteOnPhoto) ...[
                      _Location(details.property.location),
                      const SizedBox(height: 4),
                    ],
                    ListingPrice(price: l.displayedPrice, deal: details.property.dealType),
                    if (favoriteOnPhoto) ...[
                      const SizedBox(height: 6),
                      PropertySpecs(details: details, showBaths: false),
                    ],
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
