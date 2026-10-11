import 'package:flutter/material.dart';

import 'package:immora_mobile/ai/description_generator.dart';
import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/core/widgets/message_banner.dart';
import 'package:immora_mobile/module_gestion_biens/models/property.dart';

/// BF3.8 — « Description IA » [aiDescription] : le modèle de phrase est rempli
/// avec les champs du bien, les équipements détectés sont listés, puis le
/// résultat (modifiable) est renvoyé au formulaire via « Utiliser ».
class AiDescriptionScreen extends StatefulWidget {
  const AiDescriptionScreen({super.key, required this.property});

  /// Bien construit à partir des champs du formulaire (pas encore enregistré).
  final Property property;

  @override
  State<AiDescriptionScreen> createState() => _AiDescriptionScreenState();
}

class _AiDescriptionScreenState extends State<AiDescriptionScreen> {
  late final TextEditingController _resultCtrl =
      TextEditingController(text: DescriptionGenerator.generate(widget.property));

  @override
  void dispose() {
    _resultCtrl.dispose();
    super.dispose();
  }

  void _regenerate() {
    setState(() => _resultCtrl.text = DescriptionGenerator.generate(widget.property));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.property;
    final features = DescriptionGenerator.detectedFeatures(p);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, 'Description IA'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const MessageBanner(
            type: BannerType.info,
            icon: Icons.auto_awesome,
            title: 'lib/ai/description_generator.dart',
            message: 'Un modèle de phrase est rempli avec les champs du bien, '
                'puis les équipements présents sont ajoutés.',
          ),
          const SizedBox(height: 20),
          SectionTitle('Modèle (${p.dealType.label.toLowerCase()})'),
          const SizedBox(height: 8),
          WhiteCard(
            padding: const EdgeInsets.all(14),
            child: Text(
              DescriptionGenerator.template(p.dealType),
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textMuted, height: 1.5),
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle('Équipements détectés'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final f in features) _FeatureChip(f)],
          ),
          const SizedBox(height: 20),
          const Text('Résultat (modifiable)',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 6),
          TextField(
            controller: _resultCtrl,
            minLines: 4,
            maxLines: 8,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
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
          const SizedBox(height: 12),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _regenerate,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  shape: const StadiumBorder(),
                  side: const BorderSide(color: AppColors.border),
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Régénérer'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_resultCtrl.text.trim()),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: const StadiumBorder(),
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Utiliser'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Puce or « Parking », « Étage 4 », « Bon état » (équipements détectés).
class _FeatureChip extends StatelessWidget {
  const _FeatureChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: toneGold.$1,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: TextStyle(
              color: toneGold.$2, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
