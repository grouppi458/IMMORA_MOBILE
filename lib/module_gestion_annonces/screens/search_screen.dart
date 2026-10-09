import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/module_gestion_annonces/models/listing_details.dart';
import 'package:immora_mobile/module_gestion_annonces/providers/client_listing_provider.dart';
import 'package:immora_mobile/module_gestion_annonces/providers/matching_provider.dart';
import 'package:immora_mobile/module_gestion_annonces/screens/filters_sheet.dart';
import 'package:immora_mobile/module_gestion_annonces/screens/listing_detail_screen.dart';
import 'package:immora_mobile/module_gestion_annonces/widgets/client_listing_cards.dart';
import 'package:immora_mobile/module_gestion_annonces/widgets/listing_map.dart';

/// « Recherche » [search], [mapSearch], [searchLoading], [noResults] —
/// BF5.6 : recherche parmi les annonces publiées, filtres, tri par
/// compatibilité (BF5.7) et vue carte.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.onBack});

  /// Flèche retour : onglet Accueil.
  final VoidCallback onBack;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final _queryCtrl =
      TextEditingController(text: context.read<MatchingProvider>().query);
  int? _selectedOnMap;

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  void _open(ListingDetails d) => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ListingDetailScreen(listingId: d.listing.id!)));

  Future<void> _toggleFavorite(ListingDetails d) async {
    final error = await context.read<ClientListingProvider>().toggleFavorite(d.listing.id!);
    if (!mounted || error == null) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(backgroundColor: AppColors.error, content: Text(error)));
  }

  @override
  Widget build(BuildContext context) {
    final matching = context.watch<MatchingProvider>();
    final favorites = context.watch<ClientListingProvider>();
    final hits = matching.results;
    final scored = matching.filters.isEmpty ? matching.profile != null : true;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [
        _Header(
          controller: _queryCtrl,
          onBack: widget.onBack,
          onQuery: matching.setQuery,
          filterCount: matching.filters.activeCount,
          sort: matching.sort,
          onSort: matching.setSort,
          showMap: matching.showMap,
          onToggleMap: matching.toggleMap,
        ),
        Expanded(
          child: matching.isLoading && hits.isEmpty
              ? const _LoadingList()
              : hits.isEmpty
                  ? _NoResults(suggestion: matching.suggestion, label: matching.searchLabel)
                  : matching.showMap
                      ? _MapView(
                          hits: hits,
                          selectedId: _selectedOnMap,
                          onSelect: (d) => setState(() => _selectedOnMap = d.listing.id),
                          onOpen: _open,
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                          children: [
                            Text(
                              '${hits.length} bien${hits.length > 1 ? 's' : ''} · '
                              '${scored && matching.sort == SearchSort.compatibility ? 'triés par compatibilité' : 'tri : ${matching.sort.label.toLowerCase()}'}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                            if (matching.filters.isEmpty && matching.profile != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  matching.profileSource == ProfileSource.criteria
                                      ? 'Score calculé avec vos critères'
                                      : 'Score calculé d’après vos favoris',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                ),
                              ),
                            const SizedBox(height: 10),
                            for (final h in hits)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: CompactListingCard(
                                  details: h.details,
                                  match: h.match,
                                  favoriteOnPhoto: true,
                                  isFavorite: favorites.isFavorite(h.details.listing.id!),
                                  onFavorite: () => _toggleFavorite(h.details),
                                  onTap: () => _open(h.details),
                                ),
                              ),
                          ],
                        ),
        ),
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.onBack,
    required this.onQuery,
    required this.filterCount,
    required this.sort,
    required this.onSort,
    required this.showMap,
    required this.onToggleMap,
  });

  final TextEditingController controller;
  final VoidCallback onBack;
  final ValueChanged<String> onQuery;
  final int filterCount;
  final SearchSort sort;
  final ValueChanged<SearchSort> onSort;
  final bool showMap;
  final ValueChanged<bool> onToggleMap;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        color: AppColors.primary,
        padding: EdgeInsets.fromLTRB(8, MediaQuery.paddingOf(context).top + 8, 16, 14),
        child: Column(children: [
          Row(children: [
            IconButton(
              tooltip: 'Retour',
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: onBack,
            ),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onQuery,
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Ville, quartier, type de bien…',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                  suffixIcon: controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Effacer',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            controller.clear();
                            onQuery('');
                          },
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(children: [
              _HeaderChip(
                icon: Icons.tune,
                label: filterCount == 0 ? 'Filtres' : 'Filtres · $filterCount',
                highlighted: filterCount > 0,
                onTap: () => showFiltersSheet(context),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<SearchSort>(
                tooltip: 'Trier',
                initialValue: sort,
                onSelected: onSort,
                itemBuilder: (_) => [
                  for (final s in SearchSort.values) PopupMenuItem(value: s, child: Text(s.label)),
                ],
                child: _HeaderChip(icon: Icons.sort, label: sort.label, trailing: true),
              ),
              const Spacer(),
              _ListMapToggle(showMap: showMap, onChanged: onToggleMap),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.icon,
    required this.label,
    this.onTap,
    this.highlighted = false,
    this.trailing = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool highlighted;
  final bool trailing;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.gold : Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        if (trailing) const Icon(Icons.arrow_drop_down, size: 18, color: Colors.white),
      ]),
    );
    return onTap == null
        ? content
        : InkWell(borderRadius: BorderRadius.circular(10), onTap: onTap, child: content);
  }
}

/// Bascule liste / carte.
class _ListMapToggle extends StatelessWidget {
  const _ListMapToggle({required this.showMap, required this.onChanged});

  final bool showMap;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, bool selected, String tooltip, bool value) => Tooltip(
          message: tooltip,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onChanged(value),
            child: Container(
              width: 34,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? AppColors.infoBg : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        button(Icons.view_list, !showMap, 'Liste', false),
        const SizedBox(width: 2),
        button(Icons.map_outlined, showMap, 'Carte', true),
      ]),
    );
  }
}

class _MapView extends StatelessWidget {
  const _MapView({
    required this.hits,
    required this.selectedId,
    required this.onSelect,
    required this.onOpen,
  });

  final List<SearchHit> hits;
  final int? selectedId;
  final ValueChanged<ListingDetails> onSelect;
  final ValueChanged<ListingDetails> onOpen;

  @override
  Widget build(BuildContext context) {
    final selected =
        hits.where((h) => h.details.listing.id == selectedId).firstOrNull ?? hits.first;
    final located = hits.where((h) => h.details.property.latitude != null).length;
    return Column(children: [
      Expanded(
        child: ListingsMap(
          listings: hits.map((h) => h.details).toList(),
          selectedId: selected.details.listing.id,
          onSelect: onSelect,
        ),
      ),
      Container(
        color: AppColors.background,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            '$located bien${located > 1 ? 's' : ''} dans cette zone · touchez un prix',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          CompactListingCard(
            details: selected.details,
            match: selected.match,
            onTap: () => onOpen(selected.details),
          ),
        ]),
      ),
    ]);
  }
}

/// [searchLoading] — cartes « squelettes » pendant le chargement.
class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
              color: AppColors.background, borderRadius: BorderRadius.circular(6)),
        );
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        bar(140, 12),
        const SizedBox(height: 12),
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: WhiteCard(
              child: Row(children: [
                Container(width: 112, height: 100, color: const Color(0xFFE6E8EC)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    bar(150, 14),
                    const SizedBox(height: 10),
                    bar(90, 14),
                    const SizedBox(height: 10),
                    bar(110, 12),
                  ]),
                ),
              ]),
            ),
          ),
      ],
    );
  }
}

/// [noResults] — aucun bien : invitation à élargir la recherche + suggestion.
class _NoResults extends StatelessWidget {
  const _NoResults({required this.suggestion, required this.label});

  final String? suggestion;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      WhiteCard(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: AppColors.infoBg, shape: BoxShape.circle),
            child: const Icon(Icons.search, size: 34, color: AppColors.primary),
          ),
          const SizedBox(height: 14),
          const Text('Aucun bien trouvé',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            label.isEmpty
                ? 'Aucune annonce n’est en ligne pour l’instant.'
                : 'Aucun bien ne correspond à ces critères. Élargissez votre budget ou votre zone.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => showFiltersSheet(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              shape: const StadiumBorder(),
              side: const BorderSide(color: AppColors.border),
              minimumSize: const Size(162, 46),
            ),
            child: const Text('Modifier les filtres'),
          ),
        ]),
      ),
      if (suggestion != null) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF7E8C9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.auto_awesome, size: 18, color: Color(0xFF9C6A0B)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(suggestion!,
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF4A3200), height: 1.4)),
            ),
          ]),
        ),
      ],
    ]);
  }
}
