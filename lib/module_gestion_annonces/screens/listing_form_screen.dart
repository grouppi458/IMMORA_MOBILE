import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/module_gestion_biens/ai/description_generator.dart';
import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/constants.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/core/widgets/auth_text_field.dart';
import 'package:immora_mobile/core/widgets/message_banner.dart';
import 'package:immora_mobile/core/widgets/primary_button.dart';
import 'package:immora_mobile/module_authentification/providers/auth_provider.dart';
import 'package:immora_mobile/module_gestion_annonces/models/listing_details.dart';
import 'package:immora_mobile/module_gestion_biens/models/property.dart';
import 'package:immora_mobile/module_gestion_annonces/providers/listing_provider.dart';

/// « Créer / modifier annonce » [listingForm] — BF5.1 (création à partir d'un
/// bien disponible) et BF5.4 (modification du contenu).
class ListingFormScreen extends StatefulWidget {
  const ListingFormScreen({super.key, required this.agencyId, this.details});

  final int agencyId;
  final ListingDetails? details; // null = nouvelle annonce

  @override
  State<ListingFormScreen> createState() => _ListingFormScreenState();
}

class _ListingFormScreenState extends State<ListingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _titleCtrl = TextEditingController(text: widget.details?.listing.title);
  late final _priceCtrl = TextEditingController(
      text: widget.details == null ? '' : widget.details!.listing.displayedPrice.round().toString());
  late final _textCtrl = TextEditingController(text: widget.details?.listing.text);
  late bool _featured = widget.details?.listing.isFeatured ?? false;
  bool _publishNow = true;
  int _duration = listingDurations[1];
  Property? _property;
  late Future<List<Property>> _properties;
  late final ListingProvider _provider;

  bool get _isEdit => widget.details != null;

  @override
  void initState() {
    super.initState();
    _provider = context.read<ListingProvider>();
    _property = widget.details?.property;
    _properties = _isEdit
        ? Future.value(const [])
        : _provider.availableProperties(widget.agencyId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _provider.clearError());
  }

  @override
  void dispose() {
    for (final c in [_titleCtrl, _priceCtrl, _textCtrl]) {
      c.dispose();
    }
    Future.microtask(_provider.clearError);
    super.dispose();
  }

  /// Choix du bien : propose son prix et un titre si les champs sont vides.
  void _selectProperty(Property? p) {
    setState(() {
      _property = p;
      if (p == null) return;
      if (_priceCtrl.text.isEmpty) _priceCtrl.text = p.price.round().toString();
      if (_titleCtrl.text.isEmpty) _titleCtrl.text = p.title;
    });
  }

  void _prefillText() {
    final p = _property;
    if (p == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Choisissez d’abord le bien concerné.')));
      return;
    }
    setState(() => _textCtrl.text = DescriptionGenerator.generate(p));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isEdit && _property == null) {
      setState(() {}); // affiche l'erreur du champ « Bien concerné »
      return;
    }
    FocusScope.of(context).unfocus();
    final price = double.parse(_priceCtrl.text);
    final userId = context.read<AuthProvider>().currentUser?.id;
    final ok = _isEdit
        ? await _provider.updateContent(widget.details!.listing.id!,
            title: _titleCtrl.text,
            text: _textCtrl.text,
            displayedPrice: price,
            isFeatured: _featured)
        : await _provider.create(
            propertyId: _property!.id!,
            agencyId: widget.agencyId,
            createdBy: userId,
            title: _titleCtrl.text,
            text: _textCtrl.text,
            displayedPrice: price,
            durationDays: _duration,
            isFeatured: _featured,
            publish: _publishNow,
          );
    if (!mounted || !ok) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.success,
      content: Text(_isEdit
          ? 'Annonce modifiée'
          : _publishNow
              ? 'Annonce publiée'
              : 'Brouillon enregistré'),
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ListingProvider>();
    String? fieldError(String field) =>
        provider.errorField == field ? provider.errorMessage : null;
    final generalError = provider.errorField == null ? provider.errorMessage : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, _isEdit ? 'Modifier l’annonce' : 'Nouvelle annonce',
          close: true,
          actions: [
            IconButton(
              tooltip: 'Enregistrer',
              icon: const Icon(Icons.check),
              onPressed: provider.isSaving ? null : _submit,
            ),
          ]),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (generalError != null) ...[
              MessageBanner(type: BannerType.error, message: generalError),
              const SizedBox(height: 14),
            ],
            AuthTextField(
              label: 'Titre de l’annonce',
              icon: Icons.title,
              hint: 'Ex. Appartement S+3 lumineux · Lac',
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [LengthLimitingTextInputFormatter(listingTitleMaxLength)],
              hasError: fieldError('title') != null,
              errorText: fieldError('title'),
              validator: (v) => (v ?? '').trim().length < listingTitleMinLength
                  ? 'Au moins $listingTitleMinLength caractères.'
                  : null,
            ),
            const SizedBox(height: 14),
            _PropertyField(
              isEdit: _isEdit,
              selected: _property,
              properties: _properties,
              onChanged: _selectProperty,
              error: fieldError('property'),
            ),
            if (!_isEdit) ...[
              const SizedBox(height: 14),
              ChoiceChipsField<int>(
                label: 'Durée de publication',
                selected: _duration,
                onSelected: (d) => setState(() => _duration = d),
                options: [for (final d in listingDurations) (d, '$d jours')],
              ),
            ],
            const SizedBox(height: 14),
            AuthTextField(
              label: _property?.dealType == DealType.rent
                  ? 'Prix affiché (TND / mois)'
                  : 'Prix affiché (TND)',
              icon: Icons.payments_outlined,
              hint: '485000',
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
              hasError: fieldError('price') != null,
              errorText: fieldError('price'),
              validator: (v) =>
                  (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Indiquez un prix supérieur à 0.' : null,
            ),
            const SizedBox(height: 14),
            const _Label('Options'),
            WhiteCard(
              child: Column(children: [
                _Toggle(
                  label: 'Mettre en avant (badge « À la une »)',
                  value: _featured,
                  onChanged: (v) => setState(() => _featured = v),
                ),
                if (!_isEdit) ...[
                  const Divider(height: 1, color: AppColors.background),
                  _Toggle(
                    label: 'Publier immédiatement',
                    value: _publishNow,
                    onChanged: (v) => setState(() => _publishNow = v),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 14),
            const _Label('Texte de l’annonce'),
            TextFormField(
              controller: _textCtrl,
              minLines: 3,
              maxLines: 8,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (v) =>
                  (v ?? '').trim().length < 20 ? 'Au moins 20 caractères.' : null,
              style: const TextStyle(fontSize: 14, height: 1.4),
              decoration: InputDecoration(
                hintText: 'Décrivez le bien : surface, pièces, équipements, quartier…',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                errorText: fieldError('text'),
                filled: true,
                fillColor: Colors.white,
                counterText: '',
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.error),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.error, width: 1.5),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _prefillText,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  foregroundColor: AppColors.gold,
                ),
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Pré-remplir avec le générateur (M3)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: _isEdit
                  ? 'Enregistrer'
                  : _publishNow
                      ? 'Publier l’annonce'
                      : 'Enregistrer le brouillon',
              loading: provider.isSaving,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Liste des biens disponibles (création) ou bien en lecture seule (modification).
class _PropertyField extends StatelessWidget {
  const _PropertyField({
    required this.isEdit,
    required this.selected,
    required this.properties,
    required this.onChanged,
    this.error,
  });

  final bool isEdit;
  final Property? selected;
  final Future<List<Property>> properties;
  final ValueChanged<Property?> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border),
    );
    InputDecoration decoration({String? errorText}) => InputDecoration(
          prefixIcon: const Icon(Icons.home_work_outlined, size: 20, color: AppColors.textDark),
          filled: true,
          fillColor: isEdit ? AppColors.background : Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          enabledBorder: border,
          disabledBorder: border,
          focusedBorder: border.copyWith(
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          errorBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.error)),
          focusedErrorBorder:
              border.copyWith(borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
          errorText: errorText,
          errorMaxLines: 2,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('Bien concerné'),
        if (isEdit)
          InputDecorator(
            decoration: decoration(),
            child: Text('${selected!.title} · ${selected!.location}',
                overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
          )
        else
          FutureBuilder<List<Property>>(
            future: properties,
            builder: (context, snap) {
              final list = snap.data ?? const <Property>[];
              final loading = snap.connectionState != ConnectionState.done;
              return DropdownButtonFormField<Property>(
                initialValue: selected,
                isExpanded: true,
                decoration: decoration(errorText: error),
                hint: Text(
                  loading
                      ? 'Chargement…'
                      : list.isEmpty
                          ? 'Aucun bien disponible'
                          : 'Choisir un bien disponible',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                ),
                validator: (p) => p == null ? 'Choisissez le bien à publier.' : null,
                items: [
                  for (final p in list)
                    DropdownMenuItem(
                      value: p,
                      child: Text('${p.title} · ${p.district.isEmpty ? p.city : p.district}',
                          overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                    ),
                ],
                onChanged: onChanged,
              );
            },
          ),
        const SizedBox(height: 4),
        Text(
          isEdit
              ? 'Le bien d’une annonce ne peut pas être changé.'
              : selected != null
                  ? '${selected!.shortSpec} · ${selected!.dealType.label} · '
                      '${formatNumber(selected!.price)} TND'
                  : 'Seuls les biens disponibles sans annonce en cours sont proposés.',
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textDark)),
      );
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      dense: true,
      activeThumbColor: Colors.white,
      activeTrackColor: AppColors.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      title: Text(label, style: const TextStyle(fontSize: 14)),
    );
  }
}

