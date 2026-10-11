import 'package:flutter/material.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/module_gestion_annonces/models/listing_details.dart';

const Tone toneDark = (Color(0xFF1A1C1E), Colors.white);

Tone toneForListingStatus(ListingStatus s) => switch (s) {
      ListingStatus.draft => toneBlue,
      ListingStatus.published => toneGreen,
      ListingStatus.suspended => toneDark,
      ListingStatus.expired => toneRed,
      ListingStatus.withdrawn => toneGrey,
    };

IconData iconForPropertyType(PropertyType t) => switch (t) {
      PropertyType.apartment => Icons.apartment_outlined,
      PropertyType.house || PropertyType.villa => Icons.home_outlined,
      PropertyType.office => Icons.business_outlined,
      PropertyType.land => Icons.landscape_outlined,
      PropertyType.shop => Icons.storefront_outlined,
    };

/// « 485 000 TND » ou « 1 800 TND /mois » (prix en or, Price/15 du design system).
class ListingPrice extends StatelessWidget {
  const ListingPrice({super.key, required this.price, required this.deal, this.fontSize = 15});

  final double price;
  final DealType deal;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text.rich(TextSpan(children: [
      TextSpan(
        text: '${formatNumber(price)} TND',
        style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: fontSize),
      ),
      if (deal == DealType.rent)
        const TextSpan(
          text: ' /mois',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
    ]));
  }
}

/// Carte « Annonces (agence) » [listingList] : photo + statut à gauche,
/// titre, lieu, prix et compteurs (vues, favoris, jours restants) à droite.
class ListingCard extends StatelessWidget {
  const ListingCard({super.key, required this.details, this.onTap});

  final ListingDetails details;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = details.listing;
    final p = details.property;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Photo(details: details),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600, height: 1.35)),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.place_outlined, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(p.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      ListingPrice(price: l.displayedPrice, deal: p.dealType),
                      const SizedBox(height: 6),
                      _Counters(details: details),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.details});

  final ListingDetails details;

  @override
  Widget build(BuildContext context) {
    final l = details.listing;
    return Container(
      width: 112,
      constraints: const BoxConstraints(minHeight: 109),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.secondary, AppColors.primary],
        ),
      ),
      child: Stack(children: [
        Center(
          child: Icon(iconForPropertyType(details.property.type),
              size: 38, color: Colors.white.withValues(alpha: 0.55)),
        ),
        Positioned(
          left: 8,
          top: 8,
          child: StatusBadge(l.status.label, toneForListingStatus(l.status)),
        ),
        if (l.isFeatured)
          const Positioned(
            left: 8,
            bottom: 8,
            child: StatusBadge('À la une', toneGold),
          ),
      ]),
    );
  }
}

/// Vues · favoris · « J-21 » / « Expirée » / « — » (brouillon).
class _Counters extends StatelessWidget {
  const _Counters({required this.details});

  final ListingDetails details;

  @override
  Widget build(BuildContext context) {
    final l = details.listing;
    final remaining = switch (l.status) {
      ListingStatus.draft => '—',
      ListingStatus.expired => 'Expirée',
      ListingStatus.withdrawn => 'Retirée',
      _ => 'J-${l.daysLeft ?? 0}',
    };
    return Wrap(spacing: 12, runSpacing: 4, children: [
      if (l.status != ListingStatus.draft || l.viewsCount > 0)
        _Counter(Icons.visibility_outlined, formatNumber(l.viewsCount)),
      if (details.favoritesCount > 0)
        _Counter(Icons.favorite_border, formatNumber(details.favoritesCount)),
      _Counter(Icons.schedule, remaining),
    ]);
  }
}

class _Counter extends StatelessWidget {
  const _Counter(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 15, color: AppColors.textMuted),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
    ]);
  }
}
