import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/core/widgets/message_banner.dart';
import 'package:immora_mobile/module_gestion_biens/models/property.dart';
import 'package:immora_mobile/module_gestion_biens/providers/property_provider.dart';
import 'package:immora_mobile/module_gestion_biens/screens/property_detail_screen.dart';
import 'package:immora_mobile/module_gestion_biens/screens/property_form_screen.dart';
import 'package:immora_mobile/module_gestion_biens/widgets/property_card.dart';

enum _Sort { recent, priceAsc, priceDesc }

/// « Biens (agence) » [propList] — BF3.1, BF3.3 : le catalogue de l'agence
/// par statut, avec recherche, tri et création. BF3.5 : suppression possible
/// depuis la fiche. Utilisé par l'agence et par ses agents.
class PropertyListScreen extends StatefulWidget {
  const PropertyListScreen({super.key, required this.agencyId});

  final int agencyId;

  @override
  State<PropertyListScreen> createState() => _PropertyListScreenState();
}

class _PropertyListScreenState extends State<PropertyListScreen> {
  final _searchCtrl = TextEditingController();
  bool _searching = false;
  _Sort _sort = _Sort.recent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<PropertyProvider>().load(widget.agencyId));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Property> _sorted(List<Property> all) {
    final list = [...all];
    switch (_sort) {
      case _Sort.recent:
        break; // déjà triés par date de création
      case _Sort.priceAsc:
        list.sort((a, b) => a.price.compareTo(b.price));
      case _Sort.priceDesc:
        list.sort((a, b) => b.price.compareTo(a.price));
    }
    return list;
  }

  Future<void> _openForm([Property? property]) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PropertyFormScreen(agencyId: widget.agencyId, property: property)));
    if (mounted) await context.read<PropertyProvider>().load(widget.agencyId);
  }

  Future<void> _openDetail(Property property) async {
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PropertyDetailScreen(propertyId: property.id!)));
    if (mounted) await context.read<PropertyProvider>().load(widget.agencyId);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PropertyProvider>();
    final all = provider.agencyId == widget.agencyId ? provider.properties : <Property>[];
    final list = _sorted(all);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, 'Biens', actions: [
        IconButton(
          tooltip: _searching ? 'Fermer la recherche' : 'Rechercher',
          icon: Icon(_searching ? Icons.close : Icons.search),
          onPressed: () => setState(() {
            _searching = !_searching;
            if (!_searching) {
              _searchCtrl.clear();
              context.read<PropertyProvider>().setQuery('');
            }
          }),
        ),
        PopupMenuButton<_Sort>(
          tooltip: 'Trier',
          icon: const Icon(Icons.tune),
          initialValue: _sort,
          onSelected: (s) => setState(() => _sort = s),
          itemBuilder: (_) => const [
            PopupMenuItem(value: _Sort.recent, child: Text('Plus récents')),
            PopupMenuItem(value: _Sort.priceAsc, child: Text('Prix croissant')),
            PopupMenuItem(value: _Sort.priceDesc, child: Text('Prix décroissant')),
          ],
        ),
      ]),
      floatingActionButton: GoldFab(label: 'Ajouter un bien', onPressed: _openForm),
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
                  onChanged: (v) => context.read<PropertyProvider>().setQuery(v),
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
            FilterChipsRow<PropertyStatus?>(
              selected: provider.statusFilter,
              onSelected: (s) => context.read<PropertyProvider>().setStatusFilter(s),
              options: [
                (null, 'Tous · ${provider.totalCount}'),
                (PropertyStatus.available, 'Disponible'),
                (PropertyStatus.reserved, 'Réservé'),
                (PropertyStatus.sold, 'Vendu'),
                (PropertyStatus.rented, 'Loué'),
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
                          ? 'Aucun bien pour l’instant. Ajoutez votre premier bien '
                              'avec « Ajouter un bien ».'
                          : 'Aucun bien ne correspond.',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  )
                else
                  for (final p in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: PropertyCard(property: p, onTap: () => _openDetail(p)),
                    ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
