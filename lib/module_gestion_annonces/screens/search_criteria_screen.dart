import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/core/widgets/message_banner.dart';
import 'package:immora_mobile/core/widgets/primary_button.dart';
import 'package:immora_mobile/module_gestion_annonces/models/search_criteria.dart';
import 'package:immora_mobile/module_gestion_annonces/providers/matching_provider.dart';
import 'package:immora_mobile/module_gestion_annonces/screens/filters_sheet.dart';

/// « Mes critères » [searchCriteria] — BF5.6 : le client mémorise ses
/// critères ; ils alimentent « Pour vous » (BF5.8) et les alertes (BF5.9).
class SearchCriteriaScreen extends StatefulWidget {
  const SearchCriteriaScreen({super.key});

  @override
  State<SearchCriteriaScreen> createState() => _SearchCriteriaScreenState();
}

class _SearchCriteriaScreenState extends State<SearchCriteriaScreen> {
  late final MatchingProvider _matching = context.read<MatchingProvider>();
  late final SearchCriteria _initial = _matching.savedCriteria ?? SearchCriteria.empty;
  late DealType? _deal = _initial.dealType;
  late Set<PropertyType> _types = _initial.types;
  late int? _rooms = _initial.minRooms;
  late bool _parking = _initial.needsParking;
  late bool _alerts = _initial.alertsEnabled;
  late final _budgetMin = TextEditingController(text: _num(_initial.budgetMin));
  late final _budgetMax = TextEditingController(text: _num(_initial.budgetMax));
  late final _city = TextEditingController(text: _initial.city);
  late final _district = TextEditingController(text: _initial.district);
  late final _surface = TextEditingController(text: _num(_initial.minSurface));
  String? _error;

  static String _num(double? v) => v == null ? '' : v.round().toString();
  static double? _parse(TextEditingController c) =>
      c.text.trim().isEmpty ? null : double.tryParse(c.text.trim());

  @override
  void dispose() {
    for (final c in [_budgetMin, _budgetMax, _city, _district, _surface]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final min = _parse(_budgetMin), max = _parse(_budgetMax);
    if (min != null && max != null && min > max) {
      setState(() => _error = 'Le budget minimum dépasse le budget maximum.');
      return;
    }
    setState(() => _error = null);
    final ok = await _matching.saveCriteria(SearchCriteria(
      dealType: _deal,
      types: _types,
      budgetMin: min,
      budgetMax: max,
      city: _city.text,
      district: _district.text,
      minRooms: _rooms,
      minSurface: _parse(_surface),
      needsParking: _parking,
      alertsEnabled: _alerts,
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: ok ? AppColors.success : AppColors.error,
      content: Text(ok ? 'Critères enregistrés' : 'Impossible d’enregistrer vos critères.'),
    ));
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final saving = context.watch<MatchingProvider>().isSaving;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, 'Mes critères'),
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: SafeArea(
          top: false,
          child: PrimaryButton(label: 'Enregistrer mes critères', loading: saving, onPressed: _save),
        ),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.infoBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.auto_awesome, size: 18, color: AppColors.primary),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Ces critères alimentent vos recommandations « Pour vous » et les alertes '
                '« nouveau bien pour vous » (score ≥ 80 %).',
                style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.primary),
              ),
            ),
          ]),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          MessageBanner(type: BannerType.error, message: _error!),
        ],
        const SizedBox(height: 16),
        const CriteriaLabel('Je cherche à'),
        DealTypeSelector(value: _deal, onChanged: (d) => setState(() => _deal = d)),
        const SizedBox(height: 16),
        const CriteriaLabel('Type recherché'),
        TypeChips(selected: _types, onChanged: (t) => setState(() => _types = t)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: CriteriaField(
                label: 'Budget min (TND)', hint: '300000', controller: _budgetMin, number: true),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: CriteriaField(
                label: 'Budget max (TND)', hint: '500000', controller: _budgetMax, number: true),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: CriteriaField(label: 'Ville', hint: 'Tunis', controller: _city)),
          const SizedBox(width: 10),
          Expanded(
            child: CriteriaField(label: 'Quartier', hint: 'Berges du Lac', controller: _district),
          ),
        ]),
        const SizedBox(height: 14),
        const CriteriaLabel('Chambres minimum'),
        RoomsChips(value: _rooms, onChanged: (r) => setState(() => _rooms = r)),
        const SizedBox(height: 14),
        CriteriaField(label: 'Surface min (m²)', hint: '90', controller: _surface, number: true),
        const SizedBox(height: 16),
        WhiteCard(
          child: Column(children: [
            SwitchListTile(
              value: _parking,
              onChanged: (v) => setState(() => _parking = v),
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.primary,
              title: const Text('Parking indispensable', style: TextStyle(fontSize: 14)),
            ),
            const Divider(height: 1, color: AppColors.background),
            SwitchListTile(
              value: _alerts,
              onChanged: (v) => setState(() => _alerts = v),
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.primary,
              title: const Text('Alertes nouveaux biens', style: TextStyle(fontSize: 14)),
              subtitle: const Text('Être notifié quand une annonce me correspond à 80 % ou plus',
                  style: TextStyle(fontSize: 12)),
            ),
          ]),
        ),
      ]),
    );
  }
}
