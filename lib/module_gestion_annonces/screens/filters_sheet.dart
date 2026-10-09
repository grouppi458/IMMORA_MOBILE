import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/module_gestion_annonces/models/search_criteria.dart';
import 'package:immora_mobile/module_gestion_annonces/providers/matching_provider.dart';

/// Ouvre « Filtres » [filters] (BF5.6) en bas de l'écran Recherche.
Future<void> showFiltersSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const FractionallySizedBox(heightFactor: 0.94, child: _FiltersSheet()),
    );

/// Bornes du curseur de budget selon vente / location.
(double max, double step) budgetRange(DealType? deal) =>
    deal == DealType.rent ? (10000, 100) : (3000000, 10000);

class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet();

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late final MatchingProvider _matching = context.read<MatchingProvider>();
  late SearchCriteria _draft = _matching.filters;
  late SearchSort _sort = _matching.sort;
  late final _cityCtrl = TextEditingController(text: _draft.city);
  late final _districtCtrl = TextEditingController(text: _draft.district);
  late final _surfaceCtrl =
      TextEditingController(text: _draft.minSurface?.round().toString() ?? '');

  @override
  void dispose() {
    _cityCtrl.dispose();
    _districtCtrl.dispose();
    _surfaceCtrl.dispose();
    super.dispose();
  }

  void _update(SearchCriteria c) => setState(() => _draft = c);

  void _reset() {
    _cityCtrl.clear();
    _districtCtrl.clear();
    _surfaceCtrl.clear();
    setState(() {
      _draft = SearchCriteria.empty;
      _sort = SearchSort.compatibility;
    });
  }

  void _apply() {
    _matching
      ..setFilters(_draft)
      ..setSort(_sort);
    Navigator.of(context).pop();
  }

  Future<void> _saveAsCriteria() async {
    final saved = _matching.savedCriteria;
    final ok = await _matching
        .saveCriteria(_draft.copyWith(alertsEnabled: saved?.alertsEnabled ?? true));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: ok ? AppColors.success : AppColors.error,
      content: Text(ok
          ? 'Critères mémorisés : ils alimentent « Pour vous » et vos alertes.'
          : 'Impossible d’enregistrer vos critères.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final count = context.watch<MatchingProvider>().resultsFor(_draft).length;
    final (maxBudget, step) = budgetRange(_draft.dealType);
    final low = (_draft.budgetMin ?? 0).clamp(0, maxBudget).toDouble();
    final high = (_draft.budgetMax ?? maxBudget).clamp(low, maxBudget).toDouble();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
        child: Row(children: [
          const Expanded(
            child: Text('Filtres', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ),
          IconButton(
            tooltip: 'Fermer',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ]),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            const _Label('Transaction'),
            DealTypeSelector(
              value: _draft.dealType,
              onChanged: (d) => _update(_draft.copyWith(
                  dealType: () => d, budgetMin: () => null, budgetMax: () => null)),
            ),
            const SizedBox(height: 16),
            const _Label('Type de bien'),
            TypeChips(selected: _draft.types, onChanged: (t) => _update(_draft.copyWith(types: t))),
            const SizedBox(height: 16),
            const _Label('Budget (TND)'),
            RangeSlider(
              values: RangeValues(low, high),
              max: maxBudget,
              divisions: (maxBudget / step).round(),
              activeColor: AppColors.primary,
              labels: RangeLabels(formatNumber(low), formatNumber(high)),
              onChanged: (v) => _update(_draft.copyWith(
                budgetMin: () => v.start <= 0 ? null : v.start,
                budgetMax: () => v.end >= maxBudget ? null : v.end,
              )),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [
                Text(low <= 0 ? 'Min. libre' : formatNumber(low),
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                const Spacer(),
                Text(high >= maxBudget ? 'Max. libre' : formatNumber(high),
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ]),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: _Field(
                  label: 'Ville',
                  hint: 'Tunis',
                  controller: _cityCtrl,
                  onChanged: (v) => _update(_draft.copyWith(city: v)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Field(
                  label: 'Quartier',
                  hint: 'Berges du Lac',
                  controller: _districtCtrl,
                  onChanged: (v) => _update(_draft.copyWith(district: v)),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            const _Label('Chambres minimum'),
            RoomsChips(
              value: _draft.minRooms,
              onChanged: (r) => _update(_draft.copyWith(minRooms: () => r)),
            ),
            const SizedBox(height: 16),
            _Field(
              label: 'Surface minimum (m²)',
              hint: '90',
              controller: _surfaceCtrl,
              number: true,
              onChanged: (v) => _update(
                  _draft.copyWith(minSurface: () => v.isEmpty ? null : double.tryParse(v))),
            ),
            CheckboxListTile(
              value: _draft.needsParking,
              onChanged: (v) => _update(_draft.copyWith(needsParking: v ?? false)),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Avec parking', style: TextStyle(fontSize: 14)),
            ),
            const SizedBox(height: 6),
            const _Label('Trier par'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in SearchSort.values)
                _Choice(label: s.label, selected: s == _sort, onTap: () => setState(() => _sort = s)),
            ]),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _draft.isEmpty ? null : _saveAsCriteria,
                icon: const Icon(Icons.bookmark_border, size: 18),
                label: const Text('Mémoriser comme mes critères'),
              ),
            ),
          ],
        ),
      ),
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: SafeArea(
          top: false,
          child: Row(children: [
            OutlinedButton(
              onPressed: _reset,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(122, 46),
                shape: const StadiumBorder(),
                side: const BorderSide(color: AppColors.border),
              ),
              child: const Text('Réinitialiser'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _apply,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(46),
                  shape: const StadiumBorder(),
                ),
                child: Text(count == 1 ? 'Voir 1 résultat' : 'Voir $count résultats'),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------- Champs partagés
// (aussi utilisés par « Mes critères »)

/// Acheter / Louer (un second appui désélectionne : « peu importe »).
class DealTypeSelector extends StatelessWidget {
  const DealTypeSelector({super.key, required this.value, required this.onChanged});

  final DealType? value;
  final ValueChanged<DealType?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<DealType>(
        segments: const [
          ButtonSegment(value: DealType.sale, label: Text('Acheter')),
          ButtonSegment(value: DealType.rent, label: Text('Louer')),
        ],
        selected: {?value},
        emptySelectionAllowed: true,
        showSelectedIcon: false,
        onSelectionChanged: (s) => onChanged(s.isEmpty ? null : s.first),
        style: SegmentedButton.styleFrom(
          backgroundColor: Colors.white,
          selectedBackgroundColor: AppColors.primary,
          selectedForegroundColor: Colors.white,
          side: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}

/// Types de bien (choix multiple).
class TypeChips extends StatelessWidget {
  const TypeChips({super.key, required this.selected, required this.onChanged});

  final Set<PropertyType> selected;
  final ValueChanged<Set<PropertyType>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final t in PropertyType.values)
        _Choice(
          label: t.label,
          selected: selected.contains(t),
          onTap: () => onChanged(
              selected.contains(t) ? ({...selected}..remove(t)) : {...selected, t}),
        ),
    ]);
  }
}

/// Peu importe · 1+ · 2+ · 3+ · 4+
class RoomsChips extends StatelessWidget {
  const RoomsChips({super.key, required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      _Choice(label: 'Peu importe', selected: value == null, onTap: () => onChanged(null)),
      for (final r in [1, 2, 3, 4])
        _Choice(label: '$r+', selected: value == r, onTap: () => onChanged(r)),
    ]);
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.infoBg,
        backgroundColor: Colors.white,
        side: BorderSide(color: selected ? AppColors.infoBg : AppColors.border),
        labelStyle: TextStyle(
          fontSize: 13,
          color: AppColors.textDark,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    required this.onChanged,
    this.number = false,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool number;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Label(label),
      TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        inputFormatters: number
            ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)]
            : [LengthLimitingTextInputFormatter(40)],
        textCapitalization: number ? TextCapitalization.none : TextCapitalization.words,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    ]);
  }
}

/// Champ de saisie partagé avec « Mes critères ».
class CriteriaField extends StatelessWidget {
  const CriteriaField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.number = false,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool number;

  @override
  Widget build(BuildContext context) => _Field(
      label: label, hint: hint, controller: controller, number: number, onChanged: (_) {});
}

/// Section titrée réutilisée par « Mes critères ».
class CriteriaLabel extends StatelessWidget {
  const CriteriaLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => _Label(text);
}
