import 'package:flutter/material.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/module_gestion_biens/models/property.dart';

const Tone toneSold = (Color(0xFF1A1C1E), Colors.white);

Tone toneForPropertyStatus(PropertyStatus s) => switch (s) {
      PropertyStatus.available => toneGreen,
      PropertyStatus.reserved => toneBlue,
      PropertyStatus.sold => toneSold,
      PropertyStatus.rented => toneGrey,
    };

IconData iconForPropertyType(PropertyType t) => switch (t) {
      PropertyType.apartment => Icons.apartment_outlined,
      PropertyType.house || PropertyType.villa => Icons.home_outlined,
      PropertyType.office => Icons.business_outlined,
      PropertyType.land => Icons.landscape_outlined,
      PropertyType.shop => Icons.storefront_outlined,
    };

/// Dégradé du bandeau photo d'une carte (maquette « Biens »).
LinearGradient gradientForPropertyType(PropertyType t) => switch (t) {
      PropertyType.apartment || PropertyType.office => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2C4A73), Color(0xFF6B87AD)]),
      PropertyType.house || PropertyType.villa => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB8892B), Color(0xFF8A6410)]),
      PropertyType.land || PropertyType.shop => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A5B6E), Color(0xFF8296AB)]),
    };

/// Carte d'un bien : bandeau photo (icône du type + pastille de statut),
/// titre, localisation, prix en or et caractéristiques (maquette « Biens »).
/// [showSpecs] = false pour les cartes de l'espace propriétaire (maquette
/// « Mes biens » : titre, localisation et prix seulement).
class PropertyCard extends StatelessWidget {
  const PropertyCard(
      {super.key, required this.property, required this.onTap, this.showSpecs = true});

  final Property property;
  final VoidCallback onTap;
  final bool showSpecs;

  @override
  Widget build(BuildContext context) {
    final p = property;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: WhiteCard(
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 128,
                child: Stack(children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(gradient: gradientForPropertyType(p.type)),
                      child: Icon(iconForPropertyType(p.type),
                          color: Colors.white.withValues(alpha: 0.55), size: 44),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: StatusBadge(p.status.label, toneForPropertyStatus(p.status)),
                  ),
                ]),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(p.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.place_outlined, size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(p.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Text.rich(TextSpan(children: [
                        TextSpan(
                            text: '${formatNumber(p.price)} TND',
                            style: const TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w800,
                                fontSize: 15)),
                        if (p.dealType == DealType.rent)
                          const TextSpan(
                              text: ' /mois',
                              style: TextStyle(
                                  color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600)),
                      ])),
                      if (showSpecs) ...[
                        const SizedBox(height: 6),
                        Row(children: [
                          if (p.rooms > 0) ...[
                            _spec(Icons.bed_outlined, '${p.rooms}'),
                            const SizedBox(width: 12),
                          ],
                          if (p.type != PropertyType.land && p.type != PropertyType.office) ...[
                            _spec(Icons.bathtub_outlined, '${p.bathrooms}'),
                            const SizedBox(width: 12),
                          ],
                          _spec(Icons.square_foot, '${formatNumber(p.surface.round())} m²'),
                        ]),
                      ],
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

  Widget _spec(IconData icon, String value) => Row(children: [
        Icon(icon, size: 14, color: AppColors.textDark),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
      ]);
}
