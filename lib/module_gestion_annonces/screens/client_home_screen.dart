import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/core/widgets/message_banner.dart';
import 'package:immora_mobile/module_authentification/providers/auth_provider.dart';
import 'package:immora_mobile/module_authentification/screens/login_screen.dart';
import 'package:immora_mobile/module_gestion_annonces/matching/matching_engine.dart';
import 'package:immora_mobile/module_gestion_annonces/models/listing_details.dart';
import 'package:immora_mobile/module_gestion_annonces/providers/client_listing_provider.dart';
import 'package:immora_mobile/module_gestion_annonces/providers/matching_provider.dart';
import 'package:immora_mobile/module_gestion_annonces/screens/client_notifications_screen.dart';
import 'package:immora_mobile/module_gestion_annonces/screens/listing_detail_screen.dart';
import 'package:immora_mobile/module_gestion_annonces/screens/match_alerts_screen.dart';
import 'package:immora_mobile/module_gestion_annonces/screens/search_criteria_screen.dart';
import 'package:immora_mobile/module_gestion_annonces/widgets/client_listing_cards.dart';

/// « Accueil client (recommandations) » [clientHome] — BF5.8 : bloc
/// « Pour vous » (10 meilleures annonces non visitées, d'après les critères
/// ou à défaut les favoris), alerte « Nouveau bien pour vous » (BF5.9),
/// recherche rapide par type et annonces récemment consultées.
class ClientHomeScreen extends StatelessWidget {
  const ClientHomeScreen({super.key, required this.onSearch});

  /// Ouvre l'onglet Recherche.
  final VoidCallback onSearch;

  void _open(BuildContext context, ListingDetails d) => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ListingDetailScreen(listingId: d.listing.id!)));

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  Future<void> _toggleFavorite(BuildContext context, ListingDetails d) async {
    final provider = context.read<ClientListingProvider>();
    final wasFavorite = provider.isFavorite(d.listing.id!);
    final error = await provider.toggleFavorite(d.listing.id!);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: error == null ? null : AppColors.error,
        content: Text(error ?? (wasFavorite ? 'Retiré des favoris' : 'Ajouté aux favoris')),
      ));
  }

  Future<void> _refresh(BuildContext context) async {
    final client = context.read<ClientListingProvider>();
    final matching = context.read<MatchingProvider>();
    await client.load(client.clientId!);
    await matching.load();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClientListingProvider>();
    final matching = context.watch<MatchingProvider>();
    final user = context.watch<AuthProvider>().currentUser;
    final alert = matching.latestUnreadAlert;
    final profile = matching.profile;
    final recommendations = matching.recommendations;
    final recent = provider.recentlyViewed;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () => _refresh(context),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Header(
              name: user?.fullName ?? '',
              unread: matching.unreadCount,
              onSearch: onSearch,
              onNotifications: () => _push(context, const ClientNotificationsScreen()),
              onCriteria: () => _push(context, const SearchCriteriaScreen()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (provider.errorMessage != null) ...[
                  MessageBanner(type: BannerType.error, message: provider.errorMessage!),
                  const SizedBox(height: 12),
                ],
                if (alert != null) ...[
                  _AlertCard(
                    alert: alert,
                    onTap: () => _push(context, const MatchAlertsScreen()),
                  ),
                  const SizedBox(height: 14),
                ],
              ]),
            ),
            // Recherche rapide par type (ouvre l'onglet Recherche).
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                for (final t in [null, ...PropertyType.values])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(t?.label ?? 'Tous'),
                      onPressed: () {
                        matching.searchType(t);
                        onSearch();
                      },
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.border),
                      labelStyle: const TextStyle(fontSize: 13, color: AppColors.textDark),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (provider.isLoading && provider.published.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (profile == null) ...[
                  _CriteriaPrompt(onTap: () => _push(context, const SearchCriteriaScreen())),
                  const SizedBox(height: 16),
                  SectionTitle('Dernières annonces', action: 'Tout voir', onAction: onSearch),
                  const SizedBox(height: 4),
                  for (final d in provider.published.take(MatchingEngine.recommendationsCount))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: PublicListingCard(
                        details: d,
                        isFavorite: provider.isFavorite(d.listing.id!),
                        onTap: () => _open(context, d),
                        onFavorite: () => _toggleFavorite(context, d),
                      ),
                    ),
                ] else ...[
                  SectionTitle('Pour vous', action: 'Tout voir', onAction: onSearch),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Text(
                        '${matching.profileSource == ProfileSource.criteria ? 'Selon vos critères' : 'D’après vos favoris'} : '
                        '${profile.summary}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.35),
                      ),
                    ),
                    InkWell(
                      onTap: () => _push(context, const SearchCriteriaScreen()),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Text('Modifier',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  if (recommendations.isEmpty)
                    const WhiteCard(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Aucune annonce ne vous correspond encore (score ≥ 50 %). '
                        'Élargissez vos critères ou revenez bientôt.',
                        style: TextStyle(color: AppColors.textMuted, height: 1.4),
                      ),
                    )
                  else
                    for (final s in recommendations)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: PublicListingCard(
                          details: s.details,
                          match: s.match,
                          isFavorite: provider.isFavorite(s.details.listing.id!),
                          onTap: () => _open(context, s.details),
                          onFavorite: () => _toggleFavorite(context, s.details),
                        ),
                      ),
                ],
                if (recent.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  const SectionTitle('Récemment consultés'),
                  const SizedBox(height: 8),
                  for (final d in recent)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CompactListingCard(details: d, onTap: () => _open(context, d)),
                    ),
                ],
                const SizedBox(height: 16),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// « ✦ Nouveau bien pour vous — Appart. S+3 · Lac · 94 % compatible »
class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.onTap});

  final ListingAlert alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = alert.details;
    final score = alert.match?.score ?? alert.notification.score ?? 0;
    return Material(
      color: const Color(0xFFF7E8C9),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Nouveau bien pour vous',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF4A3200))),
                const SizedBox(height: 2),
                Text(
                  '${d.listing.title} · $score % compatible',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF4A3200)),
                ),
              ]),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF4A3200)),
          ]),
        ),
      ),
    );
  }
}

/// Sans critères ni favoris : invitation à décrire sa recherche (BF5.8).
class _CriteriaPrompt extends StatelessWidget {
  const _CriteriaPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.auto_awesome, color: AppColors.gold, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text('Des recommandations rien que pour vous',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 6),
        const Text(
          'Indiquez votre budget, votre zone et le nombre de chambres : nous calculons '
          'un score de compatibilité pour chaque annonce. Vos favoris comptent aussi.',
          style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary, shape: const StadiumBorder()),
          child: const Text('Définir mes critères'),
        ),
      ]),
    );
  }
}

/// En-tête bleu marine : salutation, notifications (avec pastille), profil et recherche.
class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.unread,
    required this.onSearch,
    required this.onNotifications,
    required this.onCriteria,
  });

  final String name;
  final int unread;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final VoidCallback onCriteria;

  Future<void> _showProfile(BuildContext context) async {
    final user = context.read<AuthProvider>().currentUser;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: InitialsAvatar(user?.fullName ?? '?', tone: toneGold, round: true),
            title: Text(user?.fullName ?? '',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(user?.email ?? ''),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.tune, color: AppColors.primary),
            title: const Text('Mes critères de recherche'),
            onTap: () => Navigator.of(ctx).pop('criteria'),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text('Se déconnecter', style: TextStyle(color: AppColors.error)),
            onTap: () => Navigator.of(ctx).pop('logout'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!context.mounted) return;
    if (action == 'criteria') onCriteria();
    if (action != 'logout') return;
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        color: AppColors.primary,
        padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 20, 16, 18),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Bonjour', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              ]),
            ),
            IconButton(
              tooltip: 'Notifications',
              onPressed: onNotifications,
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                backgroundColor: AppColors.gold,
                child: const Icon(Icons.notifications_none, color: Colors.white),
              ),
            ),
            IconButton(
              tooltip: 'Profil',
              icon: const Icon(Icons.person_outline, color: Colors.white),
              onPressed: () => _showProfile(context),
            ),
          ]),
          const SizedBox(height: 14),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: onSearch,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  Icon(Icons.search, color: AppColors.textMuted),
                  SizedBox(width: 10),
                  Text('Ville, quartier, type de bien…',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
