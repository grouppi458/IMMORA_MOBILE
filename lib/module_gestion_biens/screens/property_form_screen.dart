import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/constants.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/core/widgets/auth_text_field.dart';
import 'package:immora_mobile/core/widgets/message_banner.dart';
import 'package:immora_mobile/module_gestion_biens/models/property.dart';
import 'package:immora_mobile/module_gestion_biens/providers/property_provider.dart';
import 'package:immora_mobile/module_gestion_biens/screens/ai_description_screen.dart';
import 'package:immora_mobile/module_gestion_biens/screens/price_estimate_screen.dart';
import 'package:immora_mobile/module_gestion_biens/screens/property_map_screen.dart';
import 'package:immora_mobile/module_gestion_biens/screens/property_photos_screen.dart';
import 'package:immora_mobile/module_gestion_biens/widgets/property_card.dart';

/// Équipements du formulaire (maquette « Créer / modifier un bien »).
const _amenityKeys = ['parking', 'ascenseur', 'jardin', 'piscine', 'meublé'];
const _amenityLabels = {
  'parking': 'Parking',
  'ascenseur': 'Ascenseur',
  'jardin': 'Jardin',
  'piscine': 'Piscine',
  'meublé': 'Meublé',
};

/// « Créer / modifier un bien » [propForm] — BF3.1 (saisie contrôlée), BF3.2
/// (photos, localisation), BF3.4 (statut posé à la création).
class PropertyFormScreen extends StatefulWidget {
  const PropertyFormScreen({super.key, required this.agencyId, this.property});

  final int agencyId;
  final Property? property; // null = création

  @override
  State<PropertyFormScreen> createState() => _PropertyFormScreenState();
}

class _PropertyFormScreenState extends State<PropertyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _surfaceCtrl = TextEditingController();
  final _roomsCtrl = TextEditingController();
  final _bathCtrl = TextEditingController();
  final _floorCtrl = TextEditingController();
  final _landCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  late PropertyType _type = widget.property?.type ?? PropertyType.apartment;
  late DealType _deal = widget.property?.dealType ?? DealType.sale;
  late PropertyCondition _condition =
      widget.property?.condition ?? PropertyCondition.good;
  late final Set<String> _amenities = {...?widget.property?.amenities};

  List<(int, String, String)> _owners = [];
  List<(int, String)> _agents = [];
  (int, String, String)? _owner;
  (int, String)? _agent;

  String _address = '';
  double? _latitude;
  double? _longitude;
  int _photoCount = 0;

  String? _serverField;
  String? _serverMessage;

  bool get _isEdit => widget.property != null;

  @override
  void initState() {
    super.initState();
    final p = widget.property;
    if (p != null) {
      _titleCtrl.text = p.title;
      _priceCtrl.text = formatNumber(p.price);
      _surfaceCtrl.text = formatNumber(p.surface);
      _roomsCtrl.text = p.rooms > 0 ? '${p.rooms}' : '';
      _bathCtrl.text = '${p.bathrooms}';
      _floorCtrl.text = p.floor == null ? '' : '${p.floor}';
      _landCtrl.text = p.landSurface == null ? '' : formatNumber(p.landSurface!);
      _cityCtrl.text = p.city;
      _districtCtrl.text = p.district;
      _descCtrl.text = p.description;
      _address = p.address;
      _latitude = p.latitude;
      _longitude = p.longitude;
    }
    final provider = context.read<PropertyProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) => provider.clearError());
    provider.ownerOptions().then((list) {
      if (!mounted) return;
      setState(() {
        _owners = list;
        _owner = _ownerOf(p?.ownerId);
      });
    });
    provider.agentOptions(widget.agencyId).then((list) {
      if (!mounted) return;
      setState(() {
        _agents = list;
        _agent = _agentOf(p?.agentId);
      });
    });
    if (p != null && p.id != null) {
      provider.photos(p.id!).then((photos) {
        if (mounted) setState(() => _photoCount = photos.length);
      });
    }
  }

  @override
  void dispose() {
    for (final c in [
      _titleCtrl, _priceCtrl, _surfaceCtrl, _roomsCtrl, _bathCtrl,
      _floorCtrl, _landCtrl, _cityCtrl, _districtCtrl, _descCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  (int, String, String)? _ownerOf(int? id) {
    for (final o in _owners) {
      if (o.$1 == id) return o;
    }
    return null;
  }

  (int, String)? _agentOf(int? id) {
    for (final a in _agents) {
      if (a.$1 == id) return a;
    }
    return null;
  }

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.'));

  int? _intOf(TextEditingController c) => int.tryParse(c.text.trim());

  String? _error(String field) => _serverField == field ? _serverMessage : null;

  void _clearServerError(String field) {
    if (_serverField == field) {
      setState(() {
        _serverField = null;
        _serverMessage = null;
      });
    }
  }

  // ------------------------------------------------------------- Sélecteurs

  Future<void> _pickType() async {
    final chosen = await showModalBottomSheet<PropertyType>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final t in PropertyType.values)
              ListTile(
                leading: Icon(iconForPropertyType(t), color: AppColors.primary),
                title: Text(t.label),
                subtitle: Text(t.name,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                trailing: t == _type
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.of(ctx).pop(t),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) setState(() => _type = chosen);
  }

  Future<void> _pickOwner() async {
    final result = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Propriétaire',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: const InitialsAvatar('?', tone: toneGrey),
              title: const Text('Sans propriétaire'),
              onTap: () => Navigator.of(ctx).pop('none'),
            ),
            if (_owners.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Aucun propriétaire enregistré.',
                    style: TextStyle(color: AppColors.textMuted)),
              )
            else
              for (final o in _owners)
                ListTile(
                  leading: InitialsAvatar(o.$2, tone: toneGold),
                  title: Text(o.$2),
                  subtitle: Text(o.$3.isEmpty ? '—' : o.$3),
                  trailing: _owner?.$1 == o.$1
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(o),
                ),
          ],
        ),
      ),
    );
    if (result == null) return;
    setState(() => _owner = result == 'none' ? null : result as (int, String, String));
  }

  Future<void> _pickAgent() async {
    final result = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Agent responsable',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: const InitialsAvatar('?', tone: toneGrey),
              title: const Text('Sans agent'),
              onTap: () => Navigator.of(ctx).pop('none'),
            ),
            if (_agents.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Aucun agent dans cette agence.',
                    style: TextStyle(color: AppColors.textMuted)),
              )
            else
              for (final a in _agents)
                ListTile(
                  leading: InitialsAvatar(a.$2, tone: toneAgent),
                  title: Text(a.$2),
                  trailing: _agent?.$1 == a.$1
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(a),
                ),
          ],
        ),
      ),
    );
    if (result == null) return;
    setState(() => _agent = result == 'none' ? null : result as (int, String));
  }

  Future<void> _openMap() async {
    final result = await Navigator.of(context).push<PropertyLocation>(
      MaterialPageRoute(
        builder: (_) => PropertyMapScreen(
          initialAddress: _address,
          latitude: _latitude,
          longitude: _longitude,
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      _address = result.address;
      _latitude = result.latitude;
      _longitude = result.longitude;
    });
  }

  Future<void> _openPhotos() async {
    final p = widget.property;
    if (p == null || p.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enregistrez d’abord le bien pour ajouter des photos.')));
      return;
    }
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => PropertyPhotosScreen(propertyId: p.id!)));
    if (!mounted) return;
    final photos = await context.read<PropertyProvider>().photos(p.id!);
    if (mounted) setState(() => _photoCount = photos.length);
  }

  /// BF3.6 — « Estimer le prix avec l’IA » : l'estimation s'applique au prix.
  Future<void> _openEstimate() async {
    final result = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => PriceEstimateScreen(
          property: _buildProperty(),
          currentPrice: _num(_priceCtrl)?.round(),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _priceCtrl.text = formatNumber(result));
  }

  /// BF3.8 — « Générer avec l’IA » : le texte proposé remplit la description.
  Future<void> _openDescription() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => AiDescriptionScreen(property: _buildProperty())),
    );
    if (result == null || !mounted) return;
    setState(() => _descCtrl.text = result);
  }

  // -------------------------------------------------------------- Enregistrer

  Property _buildProperty() {
    final prev = widget.property;
    return Property(
      id: prev?.id,
      agencyId: widget.agencyId,
      ownerId: _owner?.$1,
      agentId: _agent?.$1,
      title: _titleCtrl.text.trim(),
      type: _type,
      dealType: _deal,
      price: _num(_priceCtrl) ?? 0,
      surface: _num(_surfaceCtrl) ?? 0,
      landSurface: _type == PropertyType.villa ? _num(_landCtrl) : prev?.landSurface,
      rooms: _intOf(_roomsCtrl) ?? 0,
      bathrooms: _intOf(_bathCtrl) ?? 1,
      floor: _intOf(_floorCtrl),
      city: _cityCtrl.text.trim(),
      district: _districtCtrl.text.trim(),
      address: _address,
      latitude: _latitude,
      longitude: _longitude,
      amenities: [for (final k in _amenityKeys) if (_amenities.contains(k)) k],
      condition: _condition,
      description: _descCtrl.text.trim(),
      status: prev?.status ?? PropertyStatus.available,
      mainPhotoPath: prev?.mainPhotoPath,
      createdAt: prev?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<PropertyProvider>();
    final p = _buildProperty();
    final ok = widget.property == null
        ? await provider.create(p)
        : await provider.update(p);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _serverField = provider.errorField;
        _serverMessage = provider.errorMessage;
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.success,
      content: Text(_isEdit ? 'Bien modifié' : 'Bien créé'),
    ));
    Navigator.of(context).pop(true);
  }

  // ------------------------------------------------------------------ Build

  @override
  Widget build(BuildContext context) {
    final banner = _serverMessage != null && _serverField == null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, _isEdit ? 'Modifier le bien' : 'Nouveau bien',
          close: true,
          actions: [
            IconButton(
              tooltip: 'Enregistrer',
              icon: const Icon(Icons.check),
              onPressed: _submit,
            ),
          ]),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (banner) ...[
              MessageBanner(type: BannerType.error, message: _serverMessage!),
              const SizedBox(height: 14),
            ],
            AuthTextField(
              label: 'Titre de l’annonce',
              icon: Icons.title,
              hint: 'Ex. Appartement S+3 · Lac',
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.sentences,
              errorText: _error('title'),
              hasError: _error('title') != null,
              onChanged: (_) => _clearServerError('title'),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.length < propertyTitleMinLength || t.length > propertyTitleMaxLength) {
                  return 'Entre $propertyTitleMinLength et $propertyTitleMaxLength caractères.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            const _FieldLabel('Type de bien'),
            InkWell(
              onTap: _pickType,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  Icon(iconForPropertyType(_type), size: 20, color: AppColors.textDark),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(_type.label, style: const TextStyle(fontSize: 14))),
                  const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
                ]),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              PropertyType.values.map((t) => t.name).join(' · '),
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            const _FieldLabel('Transaction'),
            _SegmentedDeal(
              value: _deal,
              onChanged: (d) => setState(() => _deal = d),
            ),
            const SizedBox(height: 14),
            ChoiceChipsField<PropertyCondition>(
              label: 'État',
              options: [for (final c in PropertyCondition.values) (c, c.label)],
              selected: _condition,
              onSelected: (c) => setState(() => _condition = c),
            ),
            const SizedBox(height: 14),
            AuthTextField(
              label: 'Prix (TND)',
              icon: Icons.paid_outlined,
              hint: 'Ex. 485 000',
              controller: _priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\s.,]'))],
              errorText: _error('price'),
              hasError: _error('price') != null,
              onChanged: (_) => _clearServerError('price'),
              validator: (v) =>
                  (_num(_priceCtrl) ?? 0) <= 0 ? 'Indiquez un prix supérieur à 0.' : null,
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _openEstimate,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                minimumSize: const Size.fromHeight(46),
              ),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Estimer le prix avec l’IA'),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: AuthTextField(
                  label: 'Surface (m²)',
                  icon: Icons.square_foot,
                  hint: '145',
                  controller: _surfaceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\s.,]'))],
                  errorText: _error('surface'),
                  hasError: _error('surface') != null,
                  onChanged: (_) => _clearServerError('surface'),
                  validator: (v) =>
                      (_num(_surfaceCtrl) ?? 0) <= 0 ? 'Surface requise.' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AuthTextField(
                  label: 'Chambres',
                  icon: Icons.bed_outlined,
                  hint: '3',
                  controller: _roomsCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AuthTextField(
                  label: 'SdB',
                  icon: Icons.bathtub_outlined,
                  hint: '2',
                  controller: _bathCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: AuthTextField(
                  label: 'Étage',
                  icon: Icons.stairs_outlined,
                  hint: '4',
                  controller: _floorCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AuthTextField(
                  label: 'Surface terrain',
                  icon: Icons.landscape_outlined,
                  hint: _type == PropertyType.villa ? '800' : '—',
                  controller: _landCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\s.,]'))],
                  errorText: _error('landSurface'),
                  hasError: _error('landSurface') != null,
                  onChanged: (_) => _clearServerError('landSurface'),
                  validator: (v) => _type == PropertyType.villa && (_num(_landCtrl) ?? 0) <= 0
                      ? 'Requis pour une villa.'
                      : null,
                ),
              ),
            ]),
            const SizedBox(height: 14),
            const _FieldLabel('Équipements'),
            WhiteCard(
              child: Column(children: [
                for (var i = 0; i < _amenityKeys.length; i++) ...[
                  SwitchListTile(
                    value: _amenities.contains(_amenityKeys[i]),
                    onChanged: (v) => setState(() {
                      if (v) {
                        _amenities.add(_amenityKeys[i]);
                      } else {
                        _amenities.remove(_amenityKeys[i]);
                      }
                    }),
                    dense: true,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.primary,
                    title: Text(_amenityLabels[_amenityKeys[i]]!,
                        style: const TextStyle(fontSize: 14)),
                  ),
                  if (i < _amenityKeys.length - 1)
                    const Divider(height: 1, indent: 14, endIndent: 14, color: AppColors.border),
                ],
              ]),
            ),
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: AuthTextField(
                  label: 'Ville',
                  icon: Icons.place_outlined,
                  hint: 'Tunis',
                  controller: _cityCtrl,
                  textCapitalization: TextCapitalization.words,
                  errorText: _error('city'),
                  hasError: _error('city') != null,
                  onChanged: (_) => _clearServerError('city'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Indiquez la ville.' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AuthTextField(
                  label: 'Quartier',
                  icon: Icons.map_outlined,
                  hint: 'Les Berges du Lac',
                  controller: _districtCtrl,
                  textCapitalization: TextCapitalization.words,
                ),
              ),
            ]),
            const SizedBox(height: 14),
            WhiteCard(
              child: Column(children: [
                NavTile(
                  icon: Icons.map_outlined,
                  tone: toneBlue,
                  title: 'Localisation sur la carte',
                  subtitle: _latitude == null || _longitude == null
                      ? 'Non renseignée'
                      : '${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                  onTap: _openMap,
                ),
                const Divider(height: 1, indent: 14, endIndent: 14, color: AppColors.border),
                NavTile(
                  icon: Icons.photo_camera_outlined,
                  tone: toneGold,
                  title: 'Photos',
                  subtitle: !_isEdit
                      ? 'Après l’enregistrement'
                      : _photoCount == 0
                          ? 'Aucune photo'
                          : '$_photoCount photo${_photoCount > 1 ? 's' : ''} · 1 principale',
                  onTap: _openPhotos,
                ),
                const Divider(height: 1, indent: 14, endIndent: 14, color: AppColors.border),
                NavTile(
                  icon: Icons.person_outline,
                  tone: toneGold,
                  title: 'Propriétaire',
                  subtitle: _owner?.$2 ?? 'Aucun',
                  onTap: _pickOwner,
                ),
                const Divider(height: 1, indent: 14, endIndent: 14, color: AppColors.border),
                NavTile(
                  icon: Icons.support_agent_outlined,
                  tone: toneAgent,
                  title: 'Agent responsable',
                  subtitle: _agent?.$2 ?? 'Aucun',
                  onTap: _pickAgent,
                ),
              ]),
            ),
            const SizedBox(height: 14),
            const _FieldLabel('Description'),
            TextFormField(
              controller: _descCtrl,
              minLines: 4,
              maxLines: 8,
              maxLength: propertyDescriptionMaxLength,
              onChanged: (_) => _clearServerError('description'),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Appartement S+3 de 145 m² situé aux Berges du Lac…',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                errorText: _error('description'),
                filled: true,
                fillColor: _error('description') != null ? AppColors.errorBg : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _openDescription,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.gold,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                ),
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Générer avec l’IA',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 4),
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: const StadiumBorder(),
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Enregistrer le bien'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textDark)),
      );
}

/// Sélecteur « Vente | Location » (maquette « Créer / modifier un bien »).
class _SegmentedDeal extends StatelessWidget {
  const _SegmentedDeal({required this.value, required this.onChanged});

  final DealType value;
  final ValueChanged<DealType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        for (final deal in DealType.values)
          Expanded(
            child: InkWell(
              onTap: () => onChanged(deal),
              borderRadius: BorderRadius.circular(9),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: deal == value ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  deal.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: deal == value ? Colors.white : AppColors.textDark,
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
