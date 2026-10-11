import 'package:flutter/material.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/module_gestion_biens/widgets/property_card.dart';

/// BF3.4 — « Changer le statut du bien » (bottom sheet de la maquette M3).
/// Renvoie le statut choisi, ou `null` si l'agence annule.
Future<PropertyStatus?> showPropertyStatusSheet(
  BuildContext context, {
  required PropertyStatus current,
}) =>
    showModalBottomSheet<PropertyStatus>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => _StatusSheet(current: current),
    );

class _StatusSheet extends StatefulWidget {
  const _StatusSheet({required this.current});

  final PropertyStatus current;

  @override
  State<_StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends State<_StatusSheet> {
  late PropertyStatus _selected = widget.current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Changer le statut du bien',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final status in PropertyStatus.values) ...[
              InkWell(
                onTap: () => setState(() => _selected = status),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StatusBadge(status.label, toneForPropertyStatus(status)),
                          const SizedBox(height: 6),
                          Text(status.hint,
                              style: const TextStyle(
                                  fontSize: 12.5, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    Icon(
                      _selected == status
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: _selected == status ? AppColors.primary : AppColors.border,
                    ),
                  ]),
                ),
              ),
              if (status != PropertyStatus.values.last)
                const Divider(height: 1, color: AppColors.border),
            ],
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    shape: const StadiumBorder(),
                    side: const BorderSide(color: AppColors.border),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Annuler',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_selected),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: const StadiumBorder(),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Appliquer'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
