import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/widgets/auth_text_field.dart';
import 'package:immora_mobile/core/widgets/message_banner.dart';
import 'package:immora_mobile/core/widgets/primary_button.dart';
import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/module_gestion_agences/models/agency.dart';
import 'package:immora_mobile/core/utils/constants.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/core/utils/validators.dart';
import 'package:immora_mobile/module_gestion_agences/providers/agency_provider.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';

/// Création (agency == null) ou modification d'une agence (AgencyFormPage).
class AgencyFormScreen extends StatefulWidget {
  const AgencyFormScreen({super.key, this.agency});

  final Agency? agency;

  @override
  State<AgencyFormScreen> createState() => _AgencyFormScreenState();
}

class _AgencyFormScreenState extends State<AgencyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.agency?.name);
  late final _emailCtrl = TextEditingController(text: widget.agency?.email);
  late final _phoneCtrl = TextEditingController(text: widget.agency?.phone);
  late final _cityCtrl = TextEditingController(text: widget.agency?.city);
  late final _addressCtrl = TextEditingController(text: widget.agency?.address);
  late String? _logoPath = widget.agency?.logoPath;
  SubscriptionPlan _plan = SubscriptionPlan.basic;
  String? _emailError;
  late final AgencyProvider _admin;

  bool get _isEdit => widget.agency != null;

  @override
  void initState() {
    super.initState();
    _admin = context.read<AgencyProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _admin.clearError());
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _emailCtrl, _phoneCtrl, _cityCtrl, _addressCtrl]) {
      c.dispose();
    }
    Future.microtask(_admin.clearError);
    super.dispose();
  }

  /// Choisit une image dans la galerie et la copie dans le dossier de l'app.
  Future<void> _pickLogo() async {
    try {
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 85);
      if (picked == null) return;
      final dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'logos'));
      await dir.create(recursive: true);
      final target = p.join(
          dir.path, 'agency_${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}');
      await File(picked.path).copy(target);
      setState(() => _logoPath = target);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d’ouvrir la galerie.')));
    }
  }

  Future<void> _submit() async {
    setState(() => _emailError = null);
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final String? result;
    if (_isEdit) {
      final a = widget.agency!;
      result = await _admin.updateAgency(Agency(
        id: a.id,
        name: _nameCtrl.text,
        email: _emailCtrl.text,
        phone: _phoneCtrl.text,
        address: _addressCtrl.text,
        city: _cityCtrl.text,
        logoPath: _logoPath,
        isActive: a.isActive,
        createdAt: a.createdAt,
      ));
    } else {
      result = await _admin.createAgency(
        name: _nameCtrl.text,
        email: _emailCtrl.text,
        phone: _phoneCtrl.text,
        city: _cityCtrl.text,
        address: _addressCtrl.text,
        plan: _plan,
        logoPath: _logoPath,
      );
    }
    if (!mounted) return;
    if (result == null) {
      if (_admin.errorField == 'email') setState(() => _emailError = _admin.errorMessage);
      return;
    }
    if (!_isEdit) {
      await showTemporaryPasswordDialog(context,
          email: _emailCtrl.text.trim().toLowerCase(), password: result);
      if (!mounted) return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.success,
      content: Text(_isEdit ? 'Agence modifiée' : 'Agence créée'),
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AgencyProvider>();
    final generalError = admin.errorField == null ? admin.errorMessage : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, _isEdit ? 'Modifier l’agence' : 'Nouvelle agence',
          close: true),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!_isEdit) ...[
              const MessageBanner(
                type: BannerType.info,
                message: 'La création génère automatiquement l’espace agence '
                    'et le premier compte « agency ».',
              ),
              const SizedBox(height: 16),
            ],
            if (generalError != null) ...[
              MessageBanner(type: BannerType.error, message: generalError),
              const SizedBox(height: 16),
            ],
            AuthTextField(
              label: 'Nom de l’agence',
              icon: Icons.apartment_outlined,
              hint: 'Ex. Carthage Immobilier',
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [LengthLimitingTextInputFormatter(60)],
              validator: Validators.agencyName,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              label: 'Email',
              icon: Icons.mail_outline,
              hint: 'contact@agence.tn',
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              hasError: _emailError != null,
              errorText: _emailError,
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
                LengthLimitingTextInputFormatter(100),
              ],
              validator: Validators.email,
              onChanged: (_) {
                if (_emailError != null) setState(() => _emailError = null);
              },
            ),
            const SizedBox(height: 16),
            AuthTextField(
              label: 'Téléphone',
              icon: Icons.phone_outlined,
              hint: '+216 …',
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d+ ]')),
                LengthLimitingTextInputFormatter(16),
              ],
              validator: Validators.phone,
            ),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: AuthTextField(
                  label: 'Ville',
                  icon: Icons.place_outlined,
                  hint: 'Tunis',
                  controller: _cityCtrl,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [LengthLimitingTextInputFormatter(40)],
                  validator: Validators.city,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AuthTextField(
                  label: 'Adresse',
                  icon: Icons.signpost_outlined,
                  hint: 'Rue…',
                  controller: _addressCtrl,
                  inputFormatters: [LengthLimitingTextInputFormatter(120)],
                  validator: Validators.address,
                ),
              ),
            ]),
            if (!_isEdit) ...[
              const SizedBox(height: 16),
              ChoiceChipsField<SubscriptionPlan>(
                label: 'Plan d’abonnement',
                selected: _plan,
                onSelected: (p) => setState(() => _plan = p),
                options: [
                  for (final plan in SubscriptionPlan.values)
                    (plan, '${plan.label} · ${formatNumber(planDefaults[plan]!.monthlyPrice)} TND'),
                ],
              ),
            ],
            const SizedBox(height: 16),
            const Text('Logo',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textDark)),
            const SizedBox(height: 6),
            _LogoPicker(path: _logoPath, onPick: _pickLogo,
                onClear: () => setState(() => _logoPath = null)),
            const SizedBox(height: 24),
            PrimaryButton(
              label: _isEdit ? 'Enregistrer' : 'Créer l’agence',
              loading: admin.isSaving,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoPicker extends StatelessWidget {
  const _LogoPicker({required this.path, required this.onPick, required this.onClear});

  final String? path;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasLogo = path != null && File(path!).existsSync();
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPick,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            if (hasLogo)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(File(path!), width: 32, height: 32, fit: BoxFit.cover),
              )
            else
              const Icon(Icons.image_outlined, color: AppColors.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasLogo ? 'Logo sélectionné · toucher pour changer' : 'Choisir une image (galerie)',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
            ),
            if (hasLogo)
              IconButton(
                tooltip: 'Retirer le logo',
                icon: const Icon(Icons.close, size: 18),
                onPressed: onClear,
              ),
          ]),
        ),
      ),
    );
  }
}
