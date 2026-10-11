import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/ai/description_generator.dart';
import 'package:immora_mobile/ai/price_estimator.dart';
import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/core/widgets/message_banner.dart';
import 'package:immora_mobile/module_gestion_biens/models/property.dart';
import 'package:immora_mobile/module_gestion_biens/models/property_details.dart';
import 'package:immora_mobile/module_gestion_biens/models/property_photo.dart';
import 'package:immora_mobile/module_gestion_biens/providers/property_provider.dart';
import 'package:immora_mobile/module_gestion_biens/screens/price_estimate_screen.dart';
import 'package:immora_mobile/module_gestion_biens/screens/property_form_screen.dart';
import 'package:immora_mobile/module_gestion_biens/screens/property_photos_screen.dart';
import 'package:immora_mobile/module_gestion_biens/screens/property_status_sheet.dart';
import 'package:immora_mobile/module_gestion_biens/widgets/property_card.dart';
import 'package:immora_mobile/module_gestion_biens/widgets/property_photo_view.dart';
import 'package:immora_mobile/module_gestion_ventes/screens/transaction_form_screen.dart';

/// Fiche d'un bien [propDetail] — BF3.3 (détail, statistiques), BF3.4 (changer
/// le statut), BF3.6–BF3.7 (carte « Prix estimé »), BF3.9 (propriétaire/agent).
class PropertyDetailScreen extends StatefulWidget {
  const PropertyDetailScreen({super.key, required this.propertyId});

  final int propertyId;

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  PropertyDetails? _details;
  List<PropertyPhoto> _photos = [];
  PriceEstimate? _estimate;
  bool _loading = true;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = context.read<PropertyProvider>();
    final details = await provider.details(widget.propertyId);
    final photos = await provider.photos(widget.propertyId);
    PriceEstimate? estimate;
    if (details != null) {
      try {
        estimate = await PriceEstimator().estimate(details.property);
      } catch (e) {
        debugPrint('PropertyDetailScreen estimate: $e');
      }
    }
    if (!mounted) return;
    setState(() {
      _details = details;
      _photos = photos;
      _estimate = estimate;
      _page = photos.isEmpty ? 0 : _page.clamp(0, photos.length - 1);
      _loading = false;
    });
  }

  void _snack(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: success ? AppColors.success : null,
      content: Text(message),
    ));
  }

  Future<void> _openForm() async {
    final d = _details;
    if (d == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PropertyFormScreen(
            agencyId: d.property.agencyId, property: d.property)));
    if (mounted) await _load();
  }

  Future<void> _openPhotos() async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PropertyPhotosScreen(propertyId: widget.propertyId)));
    if (mounted) await _load();
  }

  /// « Voir le détail → » : « Appliquer » propose de modifier le bien.
  Future<void> _openEstimate() async {
    final d = _details;
    if (d == null) return;
    final result = await Navigator.of(context).push<int>(MaterialPageRoute(
        builder: (_) => PriceEstimateScreen(
            property: d.property, currentPrice: d.property.price.round())));
    if (result == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Prix estimé : ${formatNumber(result)} TND'),
      action: SnackBarAction(label: 'Modifier', onPressed: _openForm),
    ));
  }

  /// « Transaction » : le formulaire M4 s'ouvre pré-rempli avec ce bien.
  Future<void> _openTransaction() async {
    final d = _details;
    if (d == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TransactionFormScreen(
              agencyId: d.property.agencyId,
              initialProperty: (d.property.id!, d.property.title, d.property.price),
              initialDealType: d.property.dealType,
            )));
  }

  Future<void> _changeStatus() async {
    final d = _details;
    if (d == null) return;
    final status = await showPropertyStatusSheet(context, current: d.property.status);
    if (status == null || status == d.property.status || !mounted) return;
    final provider = context.read<PropertyProvider>();
    final ok = await provider.setStatus(widget.propertyId, status);
    if (!mounted) return;
    if (!ok) {
      _snack(provider.errorMessage ?? 'Changement de statut impossible.');
      return;
    }
    _snack('Statut mis à jour', success: true);
    await _load();
  }

  Future<void> _delete() async {
    final d = _details;
    if (d == null) return;
    final confirmed = await confirmDialog(
      context,
      title: 'Supprimer le bien ?',
      message: 'Le bien « ${d.property.title} » et ses photos seront supprimés.',
      confirmLabel: 'Supprimer',
    );
    if (!confirmed || !mounted) return;
    final provider = context.read<PropertyProvider>();
    final ok = await provider.delete(widget.propertyId);
    if (!mounted) return;
    if (!ok) {
      _snack(provider.errorMessage ?? 'Suppression impossible.');
      return;
    }
    _snack('Bien supprimé');
    Navigator.of(context).pop(true);
  }

  Future<void> _copyPhone(String phone) async {
    await Clipboard.setData(ClipboardData(text: phone));
    _snack('Numéro copié');
  }

  @override
  Widget build(BuildContext context) {
    final d = _details;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : d == null
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: MessageBanner(
                      type: BannerType.error, message: 'Bien introuvable ou supprimé.'),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _header(d),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _titleRow(d.property),
                            const SizedBox(height: 8),
                            _locationRow(d.property),
                            const SizedBox(height: 12),
                            _price(d.property),
                            const SizedBox(height: 18),
                            _specTiles(d.property),
                            const SizedBox(height: 16),
                            _chips(d.property),
                            const SizedBox(height: 20),
                            const SectionTitle('Description'),
                            const SizedBox(height: 8),
                            Text(
                              d.property.description.isEmpty
                                  ? 'Non renseignée.'
                                  : d.property.description,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: d.property.description.isEmpty
                                    ? AppColors.textMuted
                                    : AppColors.textDark,
                              ),
                            ),
                            if (_estimate != null) ...[
                              const SizedBox(height: 20),
                              _estimateCard(_estimate!),
                            ],
                            const SizedBox(height: 20),
                            const SectionTitle('Localisation'),
                            const SizedBox(height: 8),
                            _miniMap(d.property),
                            const SizedBox(height: 20),
                            const SectionTitle('Propriétaire & agent'),
                            const SizedBox(height: 8),
                            _contactsCard(d),
                            const SizedBox(height: 20),
                            _statsRow(d),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar: d == null ? null : _bottomBar(),
    );
  }

  // ---------------------------------------------------------------- En-tête

  Widget _header(PropertyDetails d) {
    final p = d.property;
    return SizedBox(
      height: 230,
      child: Stack(children: [
        Positioned.fill(
          child: _photos.isEmpty
              ? PropertyPhotoView('', fit: BoxFit.cover)
              : PageView.builder(
                  itemCount: _photos.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) =>
                      PropertyPhotoView(_photos[i].path, fit: BoxFit.cover),
                ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 96,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.35), Colors.transparent],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Row(children: [
            IconButton(
              tooltip: 'Retour',
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Modifier',
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
              onPressed: _openForm,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) => value == 'photos' ? _openPhotos() : _delete(),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'photos',
                  child: Row(children: [
                    Icon(Icons.photo_camera_outlined, size: 20),
                    SizedBox(width: 10),
                    Text('Photos du bien'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                    SizedBox(width: 10),
                    Text('Supprimer', style: TextStyle(color: AppColors.error)),
                  ]),
                ),
              ],
            ),
          ]),
        ),
        Positioned(
          left: 16,
          bottom: 14,
          child: StatusBadge(p.status.label, toneForPropertyStatus(p.status)),
        ),
        if (_photos.length > 1)
          Positioned(
            right: 16,
            bottom: 16,
            child: Row(children: [
              for (var i = 0; i < _photos.length; i++)
                Container(
                  width: i == _page ? 14 : 6,
                  height: 6,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: i == _page ? Colors.white : Colors.white54,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ]),
          ),
      ]),
    );
  }

  Widget _titleRow(Property p) => Row(children: [
        Expanded(
          child: Text(p.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
              color: AppColors.infoBg, borderRadius: BorderRadius.circular(20)),
          child: Text(p.dealType.label,
              style: const TextStyle(
                  color: AppColors.primary, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ),
      ]);

  Widget _locationRow(Property p) => Row(children: [
        const Icon(Icons.place_outlined, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Expanded(
          child: Text(p.location,
              style: const TextStyle(fontSize: 13.5, color: AppColors.textMuted)),
        ),
      ]);

  Widget _price(Property p) => Text.rich(TextSpan(children: [
        TextSpan(
            text: '${formatNumber(p.price)} TND',
            style: const TextStyle(
                color: AppColors.gold, fontSize: 24, fontWeight: FontWeight.w800)),
        if (p.dealType == DealType.rent)
          const TextSpan(
              text: ' /mois',
              style: TextStyle(
                  color: AppColors.gold, fontSize: 14, fontWeight: FontWeight.w600)),
      ]));

  Widget _specTiles(Property p) {
    final tiles = <Widget>[
      if (p.rooms > 0)
        _SpecTile(icon: Icons.bed_outlined, value: '${p.rooms}', label: 'Chambres'),
      if (p.type != PropertyType.land && p.type != PropertyType.office)
        _SpecTile(icon: Icons.bathtub_outlined, value: '${p.bathrooms}', label: 'SdB'),
      _SpecTile(
          icon: Icons.square_foot,
          value: formatNumber(p.surface.round()),
          label: 'm²'),
    ];
    return Row(children: [
      for (var i = 0; i < tiles.length; i++) ...[
        if (i > 0) const SizedBox(width: 10),
        Expanded(child: tiles[i]),
      ],
    ]);
  }

  Widget _chips(Property p) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (p.floor != null)
            _InfoChip(p.floor == 0 ? 'Rez-de-chaussée' : 'Étage ${p.floor}'),
          for (final a in p.amenities) _InfoChip(DescriptionGenerator.amenityLabel(a)),
          _InfoChip(p.condition.label),
        ],
      );

  // ------------------------------------------------------------- Prix estimé

  Widget _estimateCard(PriceEstimate estimate) {
    final comparables = estimate.comparablesCount;
    return InkWell(
      onTap: _openEstimate,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.infoBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.auto_awesome, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Prix estimé : ${formatNumber(estimate.value)} TND',
                  style: const TextStyle(
                      color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            'Fourchette ${formatNumber(estimate.low)} – ${formatNumber(estimate.high)} TND · '
            '$comparables comparable${comparables > 1 ? 's' : ''}.',
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 6),
          const Text('Voir le détail →',
              style: TextStyle(
                  color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  // ------------------------------------------------------------ Localisation

  Widget _miniMap(Property p) {
    if (p.latitude == null || p.longitude == null) {
      return WhiteCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          const Icon(Icons.place_outlined, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Position non renseignée.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
          ),
        ]),
      );
    }
    final point = LatLng(p.latitude!, p.longitude!);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 150,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: point,
            initialZoom: 15,
            interactionOptions: InteractionOptions(flags: InteractiveFlag.none),
            backgroundColor: const Color(0xFFE6ECE3),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'tn.immora.mobile',
            ),
            MarkerLayer(markers: [
              Marker(
                point: point,
                width: 40,
                height: 40,
                child: const Icon(Icons.place, color: AppColors.gold, size: 38),
              ),
            ]),
            const RichAttributionWidget(
              attributions: [TextSourceAttribution('© OpenStreetMap')],
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------ Propriétaire & agent

  Widget _contactsCard(PropertyDetails d) {
    return WhiteCard(
      child: Column(children: [
        if (d.ownerName == null)
          const _EmptyContact('Aucun propriétaire associé.')
        else
          _contactRow(
            name: d.ownerName!,
            role: 'Propriétaire',
            phone: d.ownerPhone,
            tone: toneGold,
          ),
        const Divider(height: 1, indent: 14, endIndent: 14, color: AppColors.border),
        if (d.agentName == null)
          const _EmptyContact('Aucun agent responsable.')
        else
          _contactRow(
            name: d.agentName!,
            role: 'Agent responsable',
            phone: null,
            tone: toneAgent,
            commission: d.agentCommissionRate,
          ),
      ]),
    );
  }

  Widget _contactRow({
    required String name,
    required String role,
    required String? phone,
    required Tone tone,
    double? commission,
  }) {
    final subtitle = phone != null && phone.isNotEmpty
        ? '$role · $phone'
        : commission != null
            ? '$role · commission ${formatRate(commission / 100)} %'
            : role;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(children: [
        InitialsAvatar(name, tone: tone, size: 44, round: true),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          ]),
        ),
        if (phone != null && phone.isNotEmpty)
          IconButton(
            tooltip: 'Copier le numéro',
            icon: const Icon(Icons.call_outlined, color: AppColors.primary),
            onPressed: () => _copyPhone(phone),
          ),
      ]),
    );
  }

  // ------------------------------------------------------------ Statistiques

  Widget _statsRow(PropertyDetails d) => Row(children: [
        Expanded(
            child: _CountCard(
                value: '${d.views}', label: 'Vues', color: AppColors.primary)),
        const SizedBox(width: 10),
        Expanded(
            child: _CountCard(
                value: '${d.visitsCount}', label: 'Visites', color: AppColors.primary)),
        const SizedBox(width: 10),
        Expanded(
            child:
                _CountCard(value: '${d.favoritesCount}', label: 'Favoris', color: AppColors.gold)),
      ]);

  // --------------------------------------------------------------- Bas d'écran

  Widget _bottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _changeStatus,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                shape: const StadiumBorder(),
                side: const BorderSide(color: AppColors.border),
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Changer statut'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: _openTransaction,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: const StadiumBorder(),
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.swap_horiz, size: 20),
              label: const Text('Transaction'),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Tuile chiffrée du détail : icône, valeur, libellé (« 145 m² »).
class _SpecTile extends StatelessWidget {
  const _SpecTile({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
      ]),
    );
  }
}

/// Puce blanche bordée (« Étage 4 », « Parking », « Bon état »).
class _InfoChip extends StatelessWidget {
  const _InfoChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}

/// Compteur « 142 Vues » (vues, visites, favoris).
class _CountCard extends StatelessWidget {
  const _CountCard({required this.value, required this.label, required this.color});

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
      ]),
    );
  }
}

class _EmptyContact extends StatelessWidget {
  const _EmptyContact(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        const Icon(Icons.person_off_outlined, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Text(message,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
      ]),
    );
  }
}
