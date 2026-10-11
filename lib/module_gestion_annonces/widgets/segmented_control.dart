import 'package:flutter/material.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';

/// Sélecteur à deux positions (M6) : « À venir · 2 | Passées · 3 »,
/// « Mes visites | Toute l'agence ».
class SegmentedControl extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.left,
    required this.right,
    required this.selected,
    required this.onSelect,
  });

  final String left;
  final String right;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget half(String label, int index) {
      final active = selected == index;
      return Expanded(
        child: Material(
          color: active ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => onSelect(index),
            child: Container(
              height: 42,
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? Colors.white : AppColors.textMuted,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [half(left, 0), half(right, 1)]),
    );
  }
}
