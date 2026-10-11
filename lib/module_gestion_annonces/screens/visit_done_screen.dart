import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/constants.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/core/widgets/message_banner.dart';
import 'package:immora_mobile/core/widgets/primary_button.dart';
import 'package:immora_mobile/module_gestion_annonces/models/visit_details.dart';
import 'package:immora_mobile/module_gestion_annonces/providers/visit_provider.dart';
import 'package:immora_mobile/module_gestion_annonces/widgets/visit_hero.dart';

const _ratingLabels = ['Décevant', 'Moyen', 'Bien', 'Très bien', 'Excellent'];

/// « Visite effectuée » (M6 · maquette Figma) : le client note la visite
/// (1–5 étoiles) et laisse un commentaire facultatif.
class VisitDoneScreen extends StatefulWidget {
  const VisitDoneScreen({super.key, required this.details});

  final VisitDetails details;

  @override
  State<VisitDoneScreen> createState() => _VisitDoneScreenState();
}

class _VisitDoneScreenState extends State<VisitDoneScreen> {
  late int _rating = widget.details.visit.rating ?? 0;
  late final _commentCtrl = TextEditingController(
    text: widget.details.visit.ratingComment ?? '',
  );
  bool _sending = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0 || _sending) return;
    setState(() => _sending = true);
    final error = await context.read<VisitProvider>().rate(
          widget.details.visit.id!,
          rating: _rating,
          comment: _commentCtrl.text,
        );
    if (!mounted) return;
    setState(() => _sending = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.error, content: Text(error)),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      backgroundColor: AppColors.success,
      content: Text('Merci pour votre note !'),
    ));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.details;
    final v = d.visit;
    final place = d.district.isEmpty ? d.city : d.district;
    final label = d.propertyType.shortLabel(d.rooms);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, 'Visite effectuée'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        VisitHero(
          title: place.isEmpty ? label : '$label · $place',
          statusLabel: v.status.label,
          statusTone: toneGreen,
          dateText: formatDateTimeShort(v.scheduledAt),
        ),
        const SizedBox(height: 18),
        const Text('Notez cette visite',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        WhiteCard(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 1; i <= visitRatingMax; i++)
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _rating = i),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 36,
                        color: i <= _rating
                            ? AppColors.gold
                            : AppColors.textMuted.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _rating == 0 ? 'Touchez une étoile pour noter' : '$_rating / 5 · ${_ratingLabels[_rating - 1]}',
              style: const TextStyle(fontSize: 13.5, color: AppColors.textMuted),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        const Text('Commentaire (optionnel)',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(
          controller: _commentCtrl,
          maxLines: 3,
          maxLength: visitNoteMaxLength,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Agent ponctuel, bien conforme aux photos…',
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
        const SizedBox(height: 6),
        const MessageBanner(
          type: BannerType.success,
          message: 'Ce bien vous plaît ? L’agence peut préparer une offre.',
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: AppColors.success,
            content: Text('${d.agencyName} est prévenue de votre intérêt.'),
          )),
          icon: const Icon(Icons.phone_outlined, size: 18),
          label: const Text('Contacter l’agence'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.border),
            shape: const StadiumBorder(),
            minimumSize: const Size.fromHeight(50),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
              label: 'Envoyer ma note',
              loading: _sending,
              onPressed: _rating == 0 ? null : _submit,
            ),
          ),
        ),
      ),
    );
  }
}
