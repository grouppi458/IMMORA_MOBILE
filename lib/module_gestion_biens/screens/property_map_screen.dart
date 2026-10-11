import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/widgets/message_banner.dart';

/// Adresse et coordonnées choisies sur la carte (rendues au formulaire).
typedef PropertyLocation = ({String address, double latitude, double longitude});

const _tunis = LatLng(36.8065, 10.1815);

String _formatCoord(double v) => v.toStringAsFixed(4);

/// « Choisir la localisation » [mapPicker] — BF3.2 : appuyez sur la carte ou
/// déplacez le repère ; l'adresse et les coordonnées alimentent la recherche
/// sur carte côté client.
class PropertyMapScreen extends StatefulWidget {
  const PropertyMapScreen({
    super.key,
    this.initialAddress = '',
    this.latitude,
    this.longitude,
  });

  final String initialAddress;
  final double? latitude;
  final double? longitude;

  @override
  State<PropertyMapScreen> createState() => _PropertyMapScreenState();
}

class _PropertyMapScreenState extends State<PropertyMapScreen> {
  final _controller = MapController();
  final _addressCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  late final LatLng _initial = widget.latitude != null && widget.longitude != null
      ? LatLng(widget.latitude!, widget.longitude!)
      : _tunis;

  @override
  void initState() {
    super.initState();
    _addressCtrl.text = widget.initialAddress;
    _latCtrl.text = _formatCoord(_initial.latitude);
    _lngCtrl.text = _formatCoord(_initial.longitude);
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Le repère fixe du centre suit la carte : les champs se mettent à jour.
  void _onMapMoved(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return;
    final c = camera.center;
    setState(() {
      _latCtrl.text = _formatCoord(c.latitude);
      _lngCtrl.text = _formatCoord(c.longitude);
    });
  }

  /// Saisie manuelle de coordonnées : le repère se déplace sur la position.
  void _moveToFields() {
    final lat = double.tryParse(_latCtrl.text.replaceAll(',', '.'));
    final lng = double.tryParse(_lngCtrl.text.replaceAll(',', '.'));
    if (lat == null || lng == null) return;
    _controller.move(LatLng(lat, lng), _controller.camera.zoom);
  }

  void _confirm() {
    final lat = double.tryParse(_latCtrl.text.replaceAll(',', '.'));
    final lng = double.tryParse(_lngCtrl.text.replaceAll(',', '.'));
    if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Coordonnées invalides.')));
      return;
    }
    Navigator.of(context).pop((
      address: _addressCtrl.text.trim(),
      latitude: lat,
      longitude: lng,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [
        Expanded(
          child: Stack(children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: _initial,
                initialZoom: 14,
                backgroundColor: const Color(0xFFE6ECE3),
                onPositionChanged: _onMapMoved,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'tn.immora.mobile',
                ),
                const RichAttributionWidget(attributions: [
                  TextSourceAttribution('© OpenStreetMap'),
                ]),
              ],
            ),
            // Repère fixe au centre de la carte (maquette « Choisir la localisation »).
            const Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 36),
                child: Icon(Icons.place, size: 46, color: AppColors.gold),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  _CircleButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Retour',
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onSubmitted: (v) => setState(() => _addressCtrl.text = v.trim()),
                      decoration: InputDecoration(
                        hintText: 'Rechercher une adresse…',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: _CircleButton(
                icon: Icons.my_location,
                tooltip: 'Recentrer la carte',
                onTap: () => _controller.move(_initial, 14),
                color: AppColors.primary,
              ),
            ),
          ]),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Adresse',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textDark)),
              const SizedBox(height: 6),
              TextField(
                controller: _addressCtrl,
                decoration: InputDecoration(
                  hintText: 'Rue, résidence, quartier…',
                  prefixIcon: const Icon(Icons.place_outlined, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _coordField('Latitude', _latCtrl)),
                const SizedBox(width: 12),
                Expanded(child: _coordField('Longitude', _lngCtrl)),
              ]),
              const SizedBox(height: 12),
              const MessageBanner(
                type: BannerType.info,
                message: 'Appuyez sur la carte ou déplacez le repère. Les coordonnées '
                    'alimentent la recherche sur carte côté client.',
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _confirm,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: const StadiumBorder(),
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Confirmer la position'),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _coordField(String label, TextEditingController controller) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textDark)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            onSubmitted: (_) => _moveToFields(),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ],
      );
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = AppColors.textDark,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(10), child: Icon(icon, color: color)),
        ),
      ),
    );
  }
}
