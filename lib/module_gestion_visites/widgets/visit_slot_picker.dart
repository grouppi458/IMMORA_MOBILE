import 'package:flutter/material.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/constants.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';

/// Choix d'un rendez-vous : une date (dans les deux mois à venir) puis un
/// créneau horaire de [visitTimeSlots]. [onChanged] reçoit le rendez-vous
/// complet, ou null tant que le choix est incomplet.
class VisitSlotPicker extends StatefulWidget {
  const VisitSlotPicker({super.key, this.initial, required this.onChanged});

  final DateTime? initial;
  final ValueChanged<DateTime?> onChanged;

  @override
  State<VisitSlotPicker> createState() => _VisitSlotPickerState();
}

class _VisitSlotPickerState extends State<VisitSlotPicker> {
  DateTime? _date;
  String? _slot;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _date = DateTime(initial.year, initial.month, initial.day);
      _slot = formatTime(initial.millisecondsSinceEpoch);
    }
  }

  DateTime? get _slotDateTime {
    final d = _date;
    final s = _slot;
    if (d == null || s == null) return null;
    final parts = s.split(':').map(int.parse).toList();
    return DateTime(d.year, d.month, d.day, parts[0], parts[1]);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 60)),
      locale: const Locale('fr'),
    );
    if (picked == null) return;
    setState(() => _date = picked);
    widget.onChanged(_slotDateTime);
  }

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Date et horaire souhaités',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.event_outlined, size: 18),
          label: Text(_date == null ? 'Choisir la date' : formatDate(_date!.millisecondsSinceEpoch)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.border),
            shape: const StadiumBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final slot in visitTimeSlots)
            ChoiceChip(
              label: Text(slot),
              selected: _slot == slot,
              showCheckmark: false,
              onSelected: _date == null
                  ? null
                  : (_) {
                      setState(() => _slot = slot);
                      widget.onChanged(_slotDateTime);
                    },
              selectedColor: AppColors.infoBg,
              backgroundColor: Colors.white,
              side: BorderSide(color: _slot == slot ? AppColors.infoBg : AppColors.border),
              labelStyle: TextStyle(
                fontSize: 13,
                color: _date == null ? AppColors.textMuted : AppColors.textDark,
                fontWeight: _slot == slot ? FontWeight.w700 : FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
        ]),
        if (_date == null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Choisissez d’abord une date.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ),
      ]),
    );
  }
}
