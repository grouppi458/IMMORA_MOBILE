import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/core/widgets/message_banner.dart';
import 'package:immora_mobile/module_authentification/providers/auth_provider.dart';
import 'package:immora_mobile/module_gestion_visites/models/visit_details.dart';
import 'package:immora_mobile/module_gestion_visites/providers/visit_provider.dart';
import 'package:immora_mobile/module_gestion_biens/models/property.dart';
import 'package:immora_mobile/module_gestion_biens/models/property_details.dart';
import 'package:immora_mobile/module_gestion_biens/models/property_photo.dart';
import 'package:immora_mobile/module_gestion_biens/providers/property_provider.dart';
import 'package:immora_mobile/module_gestion_biens/widgets/property_card.dart';
import 'package:immora_mobile/module_gestion_biens/widgets/property_photo_view.dart';

/// Fiche d'un bien côté propriétaire [ownerPropStatus] — M3, en lecture
/// seule : photos, statistiques, agence / agent / publication et visites
/// planifiées.
class OwnerPropertyDetailScreen extends StatefulWidget {
  const OwnerPropertyDetailScreen({super.key, required this.propertyId});

  final int propertyId;

  @override
  State<OwnerPropertyDetailScreen> createState() => _OwnerPropertyDetailScreenState();
}

class _OwnerPropertyDetailScreenState extends State<OwnerPropertyDetailScreen> {
  PropertyDetails? _details;
  List<PropertyPhoto> _photos = [];
  bool _loading = true;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    final ownerId = context.read<AuthProvider>().currentUser?.id;
    if (ownerId != null) context.read<VisitProvider>().loadForOwner(ownerId);
    _load();
  }

  Future<void> _load() async {
    final provider = context.read<PropertyProvider>();
    final details = await provider.details(widget.propertyId);
    final photos = await provider.photos(widget.propertyId);
    if (!mounted) return;
    setState(() {
      _details = details;
      _photos = photos;
      _page = photos.isEmpty ? 0 : _page.clamp(0, photos.length - 1);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = _details;
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: adminAppBar(context, 'Bien'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (d == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: adminAppBar(context, 'Bien'),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: MessageBanner(type: BannerType.error, message: 'Bien introuvable.'),
        ),
      );
    }

    final p = d.property;
    final visits = [
      for (final v in context.watch<VisitProvider>().visits)
        if (v.visit.propertyId == widget.propertyId && v.visit.isOpen) v,
    ]..sort((a, b) => a.visit.scheduledAt.compareTo(b.visit.scheduledAt));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, p.title),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _photoHeader(p),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text.rich(TextSpan(children: [
                TextSpan(
                    text: '${formatNumber(p.price)} TND',
                    style: const TextStyle(
                        color: AppColors.gold, fontWeight: FontWeight.w800, fontSize: 24)),
                if (p.dealType == DealType.rent)
                  const TextSpan(
                      text: ' /mois',
                      style: TextStyle(
                          color: AppColors.gold, fontSize: 14, fontWeight: FontWeight.w600)),
              ])),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _CountTile('${d.views}', 'Vues', AppColors.primary)),
                const SizedBox(width: 10),
                Expanded(child: _CountTile('${d.visitsCount}', 'Visites', AppColors.textDark)),
                const SizedBox(width: 10),
                Expanded(child: _CountTile('${d.favoritesCount}', 'Favoris', AppColors.gold)),
              ]),
              const SizedBox(height: 14),
              WhiteCard(
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(children: [
                      const Text('Statut',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                      const Spacer(),
                      StatusBadge(p.status.name, toneForPropertyStatus(p.status)),
                    ]),
                  ),
                  const Divider(height: 1, indent: 14, endIndent: 14, color: AppColors.border),
                  InfoRow('Agence', d.agencyName.isEmpty ? '—' : d.agencyName),
                  const Divider(height: 1, indent: 14, endIndent: 14, color: AppColors.border),
                  InfoRow('Agent', d.agentName ?? '—'),
                  const Divider(height: 1, indent: 14, endIndent: 14, color: AppColors.border),
                  InfoRow('Publié le',
                      d.publishedAt == null ? '—' : formatDate(d.publishedAt!)),
                ]),
              ),
              const SizedBox(height: 18),
              const SectionTitle('Visites planifiées'),
              const SizedBox(height: 8),
              if (visits.isEmpty)
                const WhiteCard(
                  padding: EdgeInsets.all(20),
                  child: Text('Aucune visite planifiée pour ce bien.',
                      style: TextStyle(color: AppColors.textMuted)),
                )
              else
                WhiteCard(
                  child: Column(children: [
                    for (var i = 0; i < visits.length; i++) ...[
                      _VisitRow(details: visits[i]),
                      if (i < visits.length - 1)
                        const Divider(
                            height: 1, indent: 14, endIndent: 14, color: AppColors.border),
                    ],
                  ]),
                ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _photoHeader(Property p) {
    return SizedBox(
      height: 220,
      child: Stack(children: [
        Positioned.fill(
          child: _photos.isEmpty
              ? Container(
                  decoration: BoxDecoration(gradient: gradientForPropertyType(p.type)),
                  child: Icon(iconForPropertyType(p.type),
                      color: Colors.white54, size: 56),
                )
              : PageView(
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [for (final photo in _photos) PropertyPhotoView(photo.path)],
                ),
        ),
        Positioned(
          left: 16,
          bottom: 12,
          child: StatusBadge(p.status.label, toneForPropertyStatus(p.status)),
        ),
        if (_photos.length > 1)
          Positioned(
            right: 16,
            bottom: 18,
            child: Row(children: [
              for (var i = 0; i < _photos.length; i++)
                Container(
                  width: i == _page ? 16 : 6,
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
}

/// Tuile chiffrée du détail propriétaire (« 142 Vues », maquette).
class _CountTile extends StatelessWidget {
  const _CountTile(this.value, this.label, this.color);

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(children: [
        Text(value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ]),
    );
  }
}

/// Ligne d'une visite planifiée (maquette « Visites planifiées »).
class _VisitRow extends StatelessWidget {
  const _VisitRow({required this.details});

  final VisitDetails details;

  @override
  Widget build(BuildContext context) {
    final v = details.visit;
    final tone = switch (v.status) {
      VisitStatus.requested => toneGold,
      VisitStatus.confirmed => toneBlue,
      VisitStatus.done => toneGreen,
      VisitStatus.absent => toneGrey,
      VisitStatus.cancelled => toneRed,
    };
    final subtitle = v.status == VisitStatus.confirmed
        ? 'Client intéressé'
        : 'En attente de confirmation';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: tone.$1, borderRadius: BorderRadius.circular(11)),
          child: Icon(
            v.status == VisitStatus.confirmed
                ? Icons.event_available_outlined
                : Icons.schedule,
            color: tone.$2,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(formatDateTimeShort(v.scheduledAt),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          ]),
        ),
        const SizedBox(width: 8),
        StatusBadge(v.status.label, tone),
      ]),
    );
  }
}
