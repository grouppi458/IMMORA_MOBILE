import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/core/widgets/message_banner.dart';
import 'package:immora_mobile/module_authentification/providers/auth_provider.dart';
import 'package:immora_mobile/module_gestion_annonces/providers/visit_provider.dart';
import 'package:immora_mobile/module_gestion_biens/providers/property_provider.dart';
import 'package:immora_mobile/module_gestion_biens/screens/owner_property_detail_screen.dart';
import 'package:immora_mobile/module_gestion_biens/widgets/property_card.dart';

/// « Accueil » de l'espace propriétaire (M3, lecture seule) : chiffres clés de
/// ses biens (nombre, visites de la semaine, vues cumulées, loués), rappel du
/// rôle de consultation et accès direct à ses biens confiés à l'agence.
class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key, required this.onSeeAll});

  /// Ouvre l'onglet « Mes biens ».
  final VoidCallback onSeeAll;

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  ({int views, String? agencyName})? _stats;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = context.read<AuthProvider>().currentUser?.id;
      if (id == null) return;
      context.read<PropertyProvider>().loadForOwner(id);
      context.read<VisitProvider>().loadForOwner(id);
      _loadStats(id);
    });
  }

  Future<void> _loadStats(int ownerId) async {
    try {
      final stats = await context.read<PropertyProvider>().ownerHomeStats(ownerId);
      if (!mounted) return;
      setState(() => _stats = stats);
    } catch (e) {
      debugPrint('OwnerHomeScreen._loadStats: $e');
    }
  }

  Future<void> _refresh(int ownerId) async {
    final properties = context.read<PropertyProvider>();
    final visits = context.read<VisitProvider>();
    await Future.wait([
      properties.loadForOwner(ownerId),
      visits.loadForOwner(ownerId),
    ]);
    await _loadStats(ownerId);
  }

  Future<void> _open(int propertyId) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OwnerPropertyDetailScreen(propertyId: propertyId)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PropertyProvider>();
    final visitProvider = context.watch<VisitProvider>();
    final user = context.watch<AuthProvider>().currentUser;
    final ownerId = user?.id;
    final all = provider.ownerAll;

    final available = provider.counts[PropertyStatus.available] ?? 0;
    final rented = provider.counts[PropertyStatus.rented] ?? 0;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final weekEndMs = nowMs + const Duration(days: 7).inMilliseconds;
    final upcomingWeek = [
      for (final v in visitProvider.visits)
        if (v.visit.isOpen && v.visit.scheduledAt > nowMs && v.visit.scheduledAt < weekEndMs)
          v,
    ].length;

    final featured = all.isEmpty
        ? null
        : all.firstWhere((p) => p.status == PropertyStatus.available,
            orElse: () => all.first);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          if (ownerId != null) await _refresh(ownerId);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle.light,
              child: Container(
                color: AppColors.primary,
                padding:
                    EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 20, 16, 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Espace propriétaire',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text(user?.fullName ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    InitialsAvatar(user?.fullName ?? '?',
                        tone: (AppColors.sand, AppColors.primary), size: 42, round: true),
                  ]),
                  const SizedBox(height: 16),
                  const Text('Vos biens en un coup d’œil',
                      style: TextStyle(
                          color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Consultation · gérés par ${_stats?.agencyName ?? 'votre agence'}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: StatTile(
                      icon: Icons.home_work_outlined,
                      label: 'Mes biens',
                      value: '${provider.totalCount}',
                      caption:
                          available > 1 ? '$available disponibles' : '$available disponible',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatTile(
                      icon: Icons.event_available_outlined,
                      label: 'Visites à venir',
                      value: '$upcomingWeek',
                      caption: 'cette semaine',
                      valueColor: AppColors.textDark,
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: StatTile(
                      icon: Icons.visibility_outlined,
                      label: 'Vues',
                      value: formatNumber(_stats?.views ?? 0),
                      caption: 'sur vos annonces',
                      valueColor: AppColors.gold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatTile(
                      icon: Icons.key_outlined,
                      label: 'Loués',
                      value: '$rented',
                      caption: rented > 1 ? 'biens' : 'bien',
                      valueColor: AppColors.textDark,
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                if (provider.errorMessage != null) ...[
                  MessageBanner(type: BannerType.error, message: provider.errorMessage!),
                  const SizedBox(height: 14),
                ],
                const MessageBanner(
                  type: BannerType.info,
                  icon: Icons.lock_outline,
                  message: 'Votre espace est en lecture seule : l’agence gère vos biens, '
                      'vos annonces et les visites. Contactez-la pour toute modification.',
                ),
                const SizedBox(height: 6),
                SectionTitle('Mes biens', action: 'Tout voir', onAction: widget.onSeeAll),
                const SizedBox(height: 4),
                if (provider.isLoading && all.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (featured == null)
                  const WhiteCard(
                    padding: EdgeInsets.all(20),
                    child: Text('Aucun bien ne vous est rattaché pour l’instant.',
                        style: TextStyle(color: AppColors.textMuted)),
                  )
                else
                  PropertyCard(
                    property: featured,
                    showSpecs: false,
                    onTap: () => _open(featured.id!),
                  ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
