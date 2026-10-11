import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/constants.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/core/widgets/primary_button.dart';
import 'package:immora_mobile/module_authentification/providers/auth_provider.dart';
import 'package:immora_mobile/module_gestion_annonces/models/listing_details.dart';
import 'package:immora_mobile/module_gestion_annonces/providers/visit_provider.dart';
import 'package:immora_mobile/module_gestion_annonces/screens/client_shell.dart';
import 'package:immora_mobile/module_gestion_annonces/widgets/client_listing_cards.dart';
import 'package:immora_mobile/module_gestion_annonces/widgets/listing_card.dart';

/// « Demander une visite » (M6 · maquette Figma) : récapitulatif du bien,
/// jour et créneau de 30 min — les créneaux déjà pris par l'agent sont
/// désactivés — message facultatif, puis confirmation du rendez-vous.
class VisitRequestScreen extends StatefulWidget {
  const VisitRequestScreen({super.key, required this.details});

  final ListingDetails details;

  @override
  State<VisitRequestScreen> createState() => _VisitRequestScreenState();
}

class _VisitRequestScreenState extends State<VisitRequestScreen> {
  static const _dayChips = 8;

  final _noteCtrl = TextEditingController();
  final List<DateTime> _days = [];
  late DateTime _day;
  String? _slot;
  Set<int> _taken = {};
  bool _sending = false;
  int _lastRequest = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (var i = 0; i < _dayChips; i++) {
      _days.add(DateTime(today.year, today.month, today.day + i));
    }
    _day = _days.first;
    _loadTaken();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  static int _minutesOf(String slot) {
    final parts = slot.split(':').map(int.parse).toList();
    return parts[0] * 60 + parts[1];
  }

  DateTime _dateTimeOf(String slot) {
    final parts = slot.split(':').map(int.parse).toList();
    return DateTime(_day.year, _day.month, _day.day, parts[0], parts[1]);
  }

  bool _available(String slot) =>
      !_taken.contains(_minutesOf(slot)) && _dateTimeOf(slot).isAfter(DateTime.now());

  Future<void> _loadTaken() async {
    final listingId = widget.details.listing.id;
    if (listingId == null) return;
    final request = ++_lastRequest;
    final day = _day;
    final taken = await context.read<VisitProvider>().slotsTaken(listingId: listingId, day: day);
    if (!mounted || request != _lastRequest) return;
    setState(() {
      _taken = taken;
      final slot = _slot;
      if (slot != null && !_available(slot)) _slot = null;
    });
  }

  void _selectDay(DateTime day) {
    setState(() {
      _day = day;
      _slot = null;
      _taken = {};
    });
    _loadTaken();
  }

  Future<void> _pickOtherDay() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: today,
      lastDate: today.add(const Duration(days: 60)),
      locale: const Locale('fr'),
    );
    if (picked == null || !mounted) return;
    final day = DateTime(picked.year, picked.month, picked.day);
    if (!_days.any((d) => d == day)) {
      _days.add(day);
      _days.sort();
    }
    _selectDay(day);
  }

  /// « 11:00 et 15:00 » / « 11:00, 15:00 et 15:30 ».
  String _takenLabels() {
    final labels = _taken.toList()..sort();
    String label(int m) =>
        '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
    final text = labels.map(label).toList();
    if (text.length == 1) return text.first;
    return '${text.sublist(0, text.length - 1).join(', ')} et ${text.last}';
  }

  Future<void> _submit() async {
    final slot = _slot;
    final clientId = context.read<AuthProvider>().currentUser?.id;
    if (slot == null || clientId == null || _sending) return;
    setState(() => _sending = true);
    final error = await context.read<VisitProvider>().request(
          clientId: clientId,
          listingId: widget.details.listing.id!,
          scheduledAt: _dateTimeOf(slot),
          note: _noteCtrl.text,
        );
    if (!mounted) return;
    setState(() => _sending = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.error, content: Text(error)),
      );
      // Le créneau a pu être pris entre-temps : on rafraîchit la grille.
      await _loadTaken();
      return;
    }
    await _showSentDialog(_dateTimeOf(slot));
  }

  Future<void> _showSentDialog(DateTime when) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: AppColors.successBg, shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_outline, color: AppColors.success, size: 34),
            ),
            const SizedBox(height: 14),
            const Text('Demande envoyée',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'L’agence confirmera votre visite du '
              '${formatDateLong(when.millisecondsSinceEpoch)} à '
              '${formatTime(when.millisecondsSinceEpoch)}. Vous recevrez un rappel '
              '$visitReminderHours h avant.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: 'Voir mes visites',
              onPressed: () {
                Navigator.of(ctx).pop();
                ClientShell.openTab?.call(ClientShell.visitsTab);
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.details;
    final place = d.property.district.isEmpty ? d.property.city : d.property.district;
    final base = d.property.type.shortLabel(d.property.rooms);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, 'Demander une visite', close: true),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        WhiteCard(
          child: Row(children: [
            SizedBox(
              width: 92,
              height: 100,
              child: ListingPhoto(type: d.property.type, iconSize: 30),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(place.isEmpty ? base : '$base · $place',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.place_outlined, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(d.property.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    ListingPrice(price: d.listing.displayedPrice, deal: d.property.dealType),
                  ],
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        const Text('Date souhaitée',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final day in _days) ...[
              _DayChip(
                label: formatDayChip(day),
                selected: day == _day,
                onTap: () => _selectDay(day),
              ),
              const SizedBox(width: 8),
            ],
            _DayChip(
              icon: Icons.calendar_month_outlined,
              selected: false,
              onTap: _pickOtherDay,
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Text(
          'Créneaux disponibles · 09:00–18:00 · 30 min',
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.1,
          children: [for (final slot in visitTimeSlots) _slotTile(slot)],
        ),
        if (_taken.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: toneGold.$1,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.schedule, color: AppColors.gold, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_takenLabels()} sont déjà pris : un agent ne peut pas avoir '
                  'deux visites au même moment.',
                  style: const TextStyle(color: AppColors.gold, fontSize: 12.5, height: 1.4),
                ),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 18),
        const Text('Message à l’agence (optionnel)',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(
          controller: _noteCtrl,
          maxLines: 3,
          maxLength: visitNoteMaxLength,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Bonjour, je souhaiterais visiter ce bien avec mon épouse.',
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13.5),
            filled: true,
            fillColor: Colors.white,
            counterText: '',
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ]),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: PrimaryButton(
              icon: Icons.send_outlined,
              label: 'Envoyer la demande',
              loading: _sending,
              onPressed: _slot == null ? null : _submit,
            ),
          ),
        ),
      ),
    );
  }

  Widget _slotTile(String slot) {
    final available = _available(slot);
    final selected = _slot == slot;
    return Material(
      color: selected ? AppColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: available ? () => setState(() => _slot = slot) : null,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.border, width: 1),
          ),
          child: Text(
            slot,
            style: TextStyle(
              fontSize: 15,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected
                  ? Colors.white
                  : available
                      ? AppColors.textDark
                      : AppColors.textMuted.withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({this.label, this.icon, required this.selected, required this.onTap});

  final String? label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.infoBg : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.infoBg : AppColors.border),
          ),
          child: icon != null
              ? Icon(icon, size: 18, color: AppColors.primary)
              : Text(label!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.primary : AppColors.textDark,
                  )),
        ),
      ),
    );
  }
}
