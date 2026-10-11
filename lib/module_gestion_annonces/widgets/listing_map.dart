import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/module_gestion_annonces/models/listing_details.dart';

/// Centre de Tunis : vue par défaut quand aucun bien n'a de coordonnées.
const _tunis = LatLng(36.8065, 10.1815);

TileLayer _osmTiles() => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'tn.immora.mobile',
    );

LatLng? _point(ListingDetails d) => d.property.latitude == null || d.property.longitude == null
    ? null
    : LatLng(d.property.latitude!, d.property.longitude!);

/// « 485K » / « 1,8K/m » : prix court des étiquettes de la carte.
String shortPrice(ListingDetails d) {
  final p = d.listing.displayedPrice;
  final text = p >= 1000000
      ? '${formatNumber(p / 1000000, decimals: p % 1000000 == 0 ? 0 : 1)}M'
      : p >= 1000
          ? '${formatNumber(p / 1000, decimals: p % 1000 == 0 ? 0 : 1)}K'
          : formatNumber(p);
  return d.property.dealType == DealType.rent ? '$text/m' : text;
}

/// [mapSearch] — carte des résultats avec une étiquette de prix par bien
/// (flutter_map · OpenStreetMap). Toucher un prix sélectionne le bien.
class ListingsMap extends StatefulWidget {
  const ListingsMap({
    super.key,
    required this.listings,
    required this.selectedId,
    required this.onSelect,
  });

  final List<ListingDetails> listings;
  final int? selectedId;
  final ValueChanged<ListingDetails> onSelect;

  @override
  State<ListingsMap> createState() => _ListingsMapState();
}

class _ListingsMapState extends State<ListingsMap> {
  final _controller = MapController();

  List<LatLng> get _points => widget.listings.map(_point).whereType<LatLng>().toList();

  void _fit() {
    final points = _points;
    if (points.isEmpty) return;
    if (points.length == 1) {
      _controller.move(points.first, 14);
    } else {
      _controller.fitCamera(
          CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(48)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;
    return Stack(children: [
      FlutterMap(
        mapController: _controller,
        options: MapOptions(
          initialCenter: points.isEmpty ? _tunis : points.first,
          initialZoom: 12,
          initialCameraFit: points.length > 1
              ? CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(48))
              : null,
          backgroundColor: const Color(0xFFE6ECE3),
        ),
        children: [
          _osmTiles(),
          MarkerLayer(markers: [
            for (final d in widget.listings)
              if (_point(d) != null)
                Marker(
                  point: _point(d)!,
                  width: 74,
                  height: 30,
                  child: _PriceTag(
                    label: shortPrice(d),
                    selected: d.listing.id == widget.selectedId,
                    onTap: () => widget.onSelect(d),
                  ),
                ),
          ]),
          const RichAttributionWidget(attributions: [
            TextSourceAttribution('© OpenStreetMap'),
          ]),
        ],
      ),
      Positioned(
        right: 12,
        top: 12,
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 2,
          child: IconButton(
            tooltip: 'Recentrer sur les résultats',
            icon: const Icon(Icons.my_location, color: AppColors.primary),
            onPressed: _fit,
          ),
        ),
      ),
    ]);
  }
}

class _PriceTag extends StatelessWidget {
  const _PriceTag({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? AppColors.gold : AppColors.primary,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

/// Localisation du bien d'une visite (maquette « Visite ») : carte fixe avec
/// un repère or, à partir des seules coordonnées.
class VisitLocationMap extends StatelessWidget {
  const VisitLocationMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.label = '',
    this.height = 130,
  });

  final double? latitude;
  final double? longitude;
  final String label;
  final double height;

  @override
  Widget build(BuildContext context) {
    final point =
        latitude == null || longitude == null ? null : LatLng(latitude!, longitude!);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: height,
        child: Stack(children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: point ?? _tunis,
              initialZoom: point == null ? 11 : 14,
              backgroundColor: const Color(0xFFE6ECE3),
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
            ),
            children: [
              _osmTiles(),
              if (point != null)
                MarkerLayer(markers: [
                  Marker(
                    point: point,
                    width: 40,
                    height: 40,
                    alignment: Alignment.topCenter,
                    child: const Icon(Icons.location_on, color: AppColors.gold, size: 38),
                  ),
                ]),
            ],
          ),
          if (label.isNotEmpty)
            Positioned(
              left: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration:
                    BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                child: Text(label, style: const TextStyle(fontSize: 12)),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Localisation du bien sur la fiche [propPublic] (carte fixe, un repère).
class LocationMap extends StatelessWidget {
  const LocationMap({super.key, required this.details, this.height = 130});

  final ListingDetails details;
  final double height;

  @override
  Widget build(BuildContext context) {
    final point = _point(details);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: height,
        child: Stack(children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: point ?? _tunis,
              initialZoom: point == null ? 11 : 14,
              backgroundColor: const Color(0xFFE6ECE3),
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
            ),
            children: [
              _osmTiles(),
              if (point != null)
                MarkerLayer(markers: [
                  Marker(
                    point: point,
                    width: 40,
                    height: 40,
                    alignment: Alignment.topCenter,
                    child: const Icon(Icons.location_on, color: AppColors.gold, size: 38),
                  ),
                ]),
            ],
          ),
          Positioned(
            left: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration:
                  BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: Text(details.property.location, style: const TextStyle(fontSize: 12)),
            ),
          ),
        ]),
      ),
    );
  }
}
