import 'package:flutter/material.dart';

import 'package:immora_mobile/module_gestion_biens/ai/price_estimator.dart';
import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/constants.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/core/widgets/message_banner.dart';
import 'package:immora_mobile/module_gestion_biens/models/property.dart';
import 'package:immora_mobile/module_gestion_biens/widgets/property_card.dart';

/// BF3.6–BF3.7 — « Estimation du prix » [priceEstimate] : prix moyen au m² des
/// comparables (même ville, type et transaction) × surface × coefficients,
/// fourchette ± 10 % et contrôle de cohérence avec le prix saisi.
/// « Appliquer » renvoie l'estimation (`Navigator.pop`) au formulaire.
class PriceEstimateScreen extends StatefulWidget {
  const PriceEstimateScreen({super.key, required this.property, this.currentPrice});

  final Property property;

  /// Prix déjà saisi dans le formulaire : affiche le bandeau de cohérence.
  final int? currentPrice;

  @override
  State<PriceEstimateScreen> createState() => _PriceEstimateScreenState();
}

class _PriceEstimateScreenState extends State<PriceEstimateScreen> {
  PriceEstimate? _estimate;

  @override
  void initState() {
    super.initState();
    PriceEstimator().estimate(widget.property).then((estimate) {
      if (mounted) setState(() => _estimate = estimate);
    });
  }

  @override
  Widget build(BuildContext context) {
    final estimate = _estimate;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, 'Estimation du prix'),
      body: estimate == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const MessageBanner(
                  type: BannerType.info,
                  icon: Icons.auto_awesome,
                  title: 'lib/module_gestion_biens/ai/price_estimator.dart',
                  message: 'Prix moyen au m² des biens comparables (même ville, '
                      'type et transaction ; statut sold ou available) × surface '
                      '× coefficients.',
                ),
                const SizedBox(height: 14),
                _HeaderCard(estimate: estimate),
                if (widget.currentPrice != null) ...[
                  const SizedBox(height: 14),
                  _coherenceBanner(estimate, widget.currentPrice!),
                ],
                const SizedBox(height: 14),
                _FactorsCard(estimate: estimate, property: widget.property),
                if (estimate.comparables.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const SectionTitle('Comparables utilisés'),
                  const SizedBox(height: 8),
                  WhiteCard(
                    child: Column(children: [
                      for (var i = 0; i < estimate.comparables.length; i++) ...[
                        _ComparableRow(property: estimate.comparables[i]),
                        if (i < estimate.comparables.length - 1)
                          const Divider(
                              height: 1, indent: 14, endIndent: 14, color: AppColors.border),
                      ],
                    ]),
                  ),
                ],
                if (estimate.usedFallback) ...[
                  const SizedBox(height: 14),
                  MessageBanner(
                    type: BannerType.warning,
                    message: 'Moins de $estimateMinComparables comparables : le prix '
                        'moyen par défaut de la ville (defaultPricePerM2) est utilisé.',
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  shape: const StadiumBorder(),
                  side: const BorderSide(color: AppColors.border),
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Ignorer'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: estimate == null
                    ? null
                    : () => Navigator.of(context).pop(estimate.value),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Appliquer'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  /// « Votre prix (485 000 TND) est 3,6 % au-dessus de l’estimation : cohérent. »
  Widget _coherenceBanner(PriceEstimate estimate, int price) {
    final deviation = estimate.deviationPercent(price.toDouble());
    final coherent = estimate.isCoherent(price.toDouble());
    return MessageBanner(
      type: coherent ? BannerType.success : BannerType.error,
      message: 'Votre prix (${formatNumber(price)} TND) est '
          '${formatNumber(deviation.abs(), decimals: 1)} % '
          '${deviation >= 0 ? 'au-dessus' : 'en dessous'} de l’estimation : '
          '${coherent ? 'cohérent' : 'écart important'}.',
    );
  }
}

/// Carte bleu marine « Prix estimé » + fourchette.
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.estimate});

  final PriceEstimate estimate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        const Text('Prix estimé',
            style: TextStyle(color: Colors.white70, fontSize: 13.5)),
        const SizedBox(height: 6),
        Text('${formatNumber(estimate.value)} TND',
            style: const TextStyle(
                color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          'Fourchette ${formatNumber(estimate.low)} – ${formatNumber(estimate.high)} TND '
          '(± ${formatRate(estimateRangePercent)} %)',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ]),
    );
  }
}

/// Tableau des facteurs : prix au m², surface, coefficients, comparables.
class _FactorsCard extends StatelessWidget {
  const _FactorsCard({required this.estimate, required this.property});

  final PriceEstimate estimate;
  final Property property;

  String _coefficient(double value) => value.toStringAsFixed(2).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final amenities =
        property.amenities.isEmpty ? 'aucun' : property.amenities.join(', ');
    final comparables = estimate.comparablesCount;

    return WhiteCard(
      child: Column(children: [
        InfoRow('Prix moyen au m² (${estimate.areaLabel})',
            '${formatNumber(estimate.pricePerM2)} TND'),
        const Divider(height: 1, indent: 14, endIndent: 14, color: AppColors.border),
        InfoRow('Surface', '${formatNumber(property.surface)} m²'),
        const Divider(height: 1, indent: 14, endIndent: 14, color: AppColors.border),
        InfoRow('Coef. état (${property.condition.label.toLowerCase()})',
            '× ${_coefficient(estimate.conditionCoefficient)}'),
        const Divider(height: 1, indent: 14, endIndent: 14, color: AppColors.border),
        InfoRow('Chambres (S+${property.rooms})', '+ ${formatRate(estimate.roomsBonus)} %'),
        const Divider(height: 1, indent: 14, endIndent: 14, color: AppColors.border),
        InfoRow('Équipements ($amenities)', '+ ${formatRate(estimate.amenitiesBonus)} %'),
        const Divider(height: 1, indent: 14, endIndent: 14, color: AppColors.border),
        InfoRow('Comparables trouvés', '$comparables bien${comparables > 1 ? 's' : ''}'),
      ]),
    );
  }
}

/// « Appart. S+3 · Lac — 470 000 TND · 142 m² » + badge de statut.
class _ComparableRow extends StatelessWidget {
  const _ComparableRow({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    final place = property.district.isEmpty
        ? property.city
        : property.district.split(' ').last;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.infoBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(iconForPropertyType(property.type), color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_shortType(property.type)} S+${property.rooms} · $place',
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(
              '${formatNumber(property.price)} TND · ${formatNumber(property.surface)} m²',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ]),
        ),
        StatusBadge(property.status.label, toneForPropertyStatus(property.status)),
      ]),
    );
  }

  String _shortType(PropertyType type) =>
      type == PropertyType.apartment ? 'Appart.' : type.label;
}
