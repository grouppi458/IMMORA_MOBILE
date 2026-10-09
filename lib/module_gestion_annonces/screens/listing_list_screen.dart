import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/constants.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/core/widgets/message_banner.dart';
import 'package:immora_mobile/module_gestion_annonces/models/listing_details.dart';
import 'package:immora_mobile/module_gestion_annonces/providers/listing_provider.dart';
import 'package:immora_mobile/module_gestion_annonces/screens/listing_form_screen.dart';
import 'package:immora_mobile/module_gestion_annonces/widgets/listing_card.dart';

enum _Sort { recent, views, favorites, expiring }

/// « Annonces (agence) » [listingList] — BF5.3 : les annonces de l'agence par
/// statut, avec vues et favoris ; BF5.4 / BF5.5 : actions sur chaque annonce.
/// Utilisé par l'agence et par ses agents.
class ListingListScreen extends StatefulWidget {
  const ListingListScreen({super.key, required this.agencyId});

  final int agencyId;

  @override
  State<ListingListScreen> createState() => _ListingListScreenState();
}

class _ListingListScreenState extends State<ListingListScreen> {
  final _searchCtrl = TextEditingController();
  bool _searching = false;
  ListingStatus? _status; // null = toutes
  _Sort _sort = _Sort.recent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<ListingProvider>().load(widget.agencyId));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ListingDetails> _filter(List<ListingDetails> all) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final list = all.where((d) {
      if (_status != null && d.listing.status != _status) return false;
      if (q.isEmpty) return true;
      return d.listing.title.toLowerCase().contains(q) ||
          d.property.location.toLowerCase().contains(q);
    }).toList();
    switch (_sort) {
      case _Sort.recent:
        break; // déjà triées par date de modification
      case _Sort.views:
        list.sort((a, b) => b.listing.viewsCount.compareTo(a.listing.viewsCount));
      case _Sort.favorites:
        list.sort((a, b) => b.favoritesCount.compareTo(a.favoritesCount));
      case _Sort.expiring:
        list.sort((a, b) => (a.listing.expiresAt ?? 1 << 62)
            .compareTo(b.listing.expiresAt ?? 1 << 62));
    }
    return list;
  }

  Future<void> _openForm([ListingDetails? details]) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ListingFormScreen(agencyId: widget.agencyId, details: details)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ListingProvider>();
    final all = provider.agencyId == widget.agencyId ? provider.listings : <ListingDetails>[];
    final list = _filter(all);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, 'Annonces', actions: [
        IconButton(
          tooltip: _searching ? 'Fermer la recherche' : 'Rechercher',
          icon: Icon(_searching ? Icons.close : Icons.search),
          onPressed: () => setState(() {
            _searching = !_searching;
            if (!_searching) _searchCtrl.clear();
          }),
        ),
        PopupMenuButton<_Sort>(
          tooltip: 'Trier',
          icon: const Icon(Icons.tune),
          initialValue: _sort,
          onSelected: (s) => setState(() => _sort = s),
          itemBuilder: (_) => const [
            PopupMenuItem(value: _Sort.recent, child: Text('Plus récentes')),
            PopupMenuItem(value: _Sort.views, child: Text('Plus vues')),
            PopupMenuItem(value: _Sort.favorites, child: Text('Plus de favoris')),
            PopupMenuItem(value: _Sort.expiring, child: Text('Expirent bientôt')),
          ],
        ),
      ]),
      floatingActionButton: GoldFab(label: 'Nouvelle annonce', onPressed: _openForm),
      body: RefreshIndicator(
        onRefresh: () => provider.load(widget.agencyId),
        child: ListView(
          padding: const EdgeInsets.only(top: 16, bottom: 96),
          children: [
            if (_searching)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Titre, quartier, ville…',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            FilterChipsRow<ListingStatus?>(
              selected: _status,
              onSelected: (s) => setState(() => _status = s),
              options: [
                (null, 'Toutes · ${all.length}'),
                (ListingStatus.published, 'Publiées · ${provider.count(ListingStatus.published)}'),
                (ListingStatus.draft, 'Brouillons · ${provider.count(ListingStatus.draft)}'),
                (ListingStatus.suspended,
                    'Suspendues · ${provider.count(ListingStatus.suspended)}'),
                (ListingStatus.expired, 'Expirées · ${provider.count(ListingStatus.expired)}'),
                (ListingStatus.withdrawn, 'Retirées · ${provider.count(ListingStatus.withdrawn)}'),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: [
                if (provider.errorMessage != null && !provider.isSaving) ...[
                  MessageBanner(type: BannerType.error, message: provider.errorMessage!),
                  const SizedBox(height: 10),
                ],
                if (provider.isLoading && all.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (list.isEmpty)
                  WhiteCard(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      all.isEmpty
                          ? 'Aucune annonce pour l’instant. Publiez un bien disponible '
                              'avec « Nouvelle annonce ».'
                          : 'Aucune annonce ne correspond.',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  )
                else
                  for (final d in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ListingCard(details: d, onTap: () => _showActions(d)),
                    ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Actions

  /// BF5.4 / BF5.5 — actions possibles selon le statut de l'annonce.
  Future<void> _showActions(ListingDetails d) async {
    final l = d.listing;
    final s = l.status;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(l.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            if (s != ListingStatus.withdrawn)
              _ActionTile(Icons.edit_outlined, 'Modifier', 'edit'),
            if (s == ListingStatus.draft)
              _ActionTile(Icons.public, 'Publier', 'publish'),
            if (s == ListingStatus.suspended)
              _ActionTile(Icons.play_circle_outline, 'Remettre en ligne', 'publish'),
            if (s == ListingStatus.published)
              _ActionTile(Icons.pause_circle_outline, 'Suspendre', 'suspend'),
            if (const [ListingStatus.published, ListingStatus.suspended, ListingStatus.expired]
                .contains(s))
              _ActionTile(Icons.update, s == ListingStatus.expired ? 'Republier (prolonger)' : 'Prolonger',
                  'extend'),
            if (s != ListingStatus.withdrawn)
              _ActionTile(l.isFeatured ? Icons.star : Icons.star_border,
                  l.isFeatured ? 'Retirer de la une' : 'Mettre en avant', 'feature'),
            if (const [ListingStatus.draft, ListingStatus.expired, ListingStatus.withdrawn]
                .contains(s))
              _ActionTile(Icons.delete_outline, 'Supprimer', 'delete', danger: true),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;

    final provider = context.read<ListingProvider>();
    final id = l.id!;
    bool ok;
    String done;
    switch (action) {
      case 'edit':
        await _openForm(d);
        return;
      case 'publish':
        ok = await provider.publish(id);
        done = 'Annonce publiée';
      case 'suspend':
        ok = await provider.suspend(id);
        done = 'Annonce suspendue';
      case 'extend':
        final days = await _pickDuration();
        if (days == null) return;
        ok = await provider.extend(id, days);
        done = 'Annonce prolongée de $days jours';
      case 'feature':
        ok = await provider.setFeatured(id, !l.isFeatured);
        done = l.isFeatured ? 'Annonce retirée de la une' : 'Annonce mise en avant';
      case 'delete':
        if (!await confirmDialog(context,
            title: 'Supprimer l’annonce ?',
            message: '« ${l.title} » sera supprimée, ainsi que ses favoris. '
                'Le bien reste dans votre catalogue.',
            confirmLabel: 'Supprimer')) {
          return;
        }
        ok = await provider.delete(id);
        done = 'Annonce supprimée';
      default:
        return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: ok ? AppColors.success : AppColors.error,
      content: Text(ok ? done : provider.errorMessage ?? 'Action impossible.'),
    ));
    if (!ok) provider.clearError();
  }

  Future<int?> _pickDuration() => showDialog<int>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Prolonger de…'),
          children: [
            for (final days in listingDurations)
              SimpleDialogOption(
                onPressed: () => Navigator.of(ctx).pop(days),
                child: Text('$days jours'),
              ),
          ],
        ),
      );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile(this.icon, this.label, this.value, {this.danger = false});

  final IconData icon;
  final String label;
  final String value;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.error : AppColors.textDark;
    return ListTile(
      leading: Icon(icon, color: danger ? AppColors.error : AppColors.primary),
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      onTap: () => Navigator.of(context).pop(value),
    );
  }
}
