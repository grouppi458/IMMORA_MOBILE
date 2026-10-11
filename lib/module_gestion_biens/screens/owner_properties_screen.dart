import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/core/widgets/message_banner.dart';
import 'package:immora_mobile/module_authentification/providers/auth_provider.dart';
import 'package:immora_mobile/module_gestion_biens/providers/property_provider.dart';
import 'package:immora_mobile/module_gestion_biens/screens/owner_property_detail_screen.dart';
import 'package:immora_mobile/module_gestion_biens/widgets/property_card.dart';

/// « Mes biens » de l'espace propriétaire [ownerProps] — M3 : les biens
/// confiés à l'agence, en lecture seule, filtrables par statut.
class OwnerPropertiesScreen extends StatefulWidget {
  const OwnerPropertiesScreen({super.key});

  @override
  State<OwnerPropertiesScreen> createState() => _OwnerPropertiesScreenState();
}

class _OwnerPropertiesScreenState extends State<OwnerPropertiesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = context.read<AuthProvider>().currentUser?.id;
      if (id != null) context.read<PropertyProvider>().loadForOwner(id);
    });
  }

  Future<void> _open(int propertyId) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OwnerPropertyDetailScreen(propertyId: propertyId)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PropertyProvider>();
    final ownerId = context.read<AuthProvider>().currentUser?.id;
    final list = provider.properties;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, 'Mes biens'),
      body: RefreshIndicator(
        onRefresh: () async {
          if (ownerId != null) await provider.loadForOwner(ownerId);
        },
        child: ListView(
          padding: const EdgeInsets.only(top: 16, bottom: 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            FilterChipsRow<PropertyStatus?>(
              selected: provider.statusFilter,
              onSelected: (s) => context.read<PropertyProvider>().setStatusFilter(s),
              options: [
                (null, 'Tous · ${provider.totalCount}'),
                (PropertyStatus.available, PropertyStatus.available.label),
                (PropertyStatus.rented, PropertyStatus.rented.label),
                (PropertyStatus.sold, PropertyStatus.sold.label),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: [
                if (provider.errorMessage != null) ...[
                  MessageBanner(type: BannerType.error, message: provider.errorMessage!),
                  const SizedBox(height: 10),
                ],
                if (provider.isLoading && list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (list.isEmpty)
                  WhiteCard(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      provider.statusFilter == null
                          ? 'Aucun bien ne vous est rattaché pour l’instant.'
                          : 'Aucun bien ne correspond à ce statut.',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  )
                else
                  for (var i = 0; i < list.length; i++) ...[
                    PropertyCard(
                      property: list[i],
                      showSpecs: false,
                      onTap: () => _open(list[i].id!),
                    ),
                    if (i < list.length - 1) const SizedBox(height: 10),
                  ],
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
