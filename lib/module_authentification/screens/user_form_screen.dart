import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/validators.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/core/widgets/auth_text_field.dart';
import 'package:immora_mobile/core/widgets/message_banner.dart';
import 'package:immora_mobile/core/widgets/primary_button.dart';
import 'package:immora_mobile/module_authentification/models/user.dart';
import 'package:immora_mobile/module_authentification/providers/auth_provider.dart';
import 'package:immora_mobile/module_authentification/providers/user_admin_provider.dart';
import 'package:immora_mobile/module_authentification/widgets/delete_user_action.dart';
import 'package:immora_mobile/module_gestion_agences/providers/agency_provider.dart';

/// Création ou modification d'un compte (UserFormPage) — BF1.1, BF1.2, BF1.4, BF1.5.
/// Les agents se créent depuis la fiche de leur agence (AgentFormScreen).
class UserFormScreen extends StatefulWidget {
  const UserFormScreen({super.key, this.existing, this.agencyId});

  final User? existing;
  final int? agencyId; // agence présélectionnée (liste filtrée par agence)

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.existing?.fullName);
  late final _emailCtrl = TextEditingController(text: widget.existing?.email);
  late final _phoneCtrl = TextEditingController(text: widget.existing?.phone);
  late final _cinCtrl = TextEditingController(text: widget.existing?.cin);
  late final _addressCtrl = TextEditingController(text: widget.existing?.address);
  late UserRole _role = widget.existing?.role ??
      (widget.agencyId != null ? UserRole.agency : UserRole.client);
  late int? _agencyId = widget.existing?.agencyId ?? widget.agencyId;
  late bool _isActive = widget.existing?.isActive ?? true;
  String? _emailError;
  late final UserAdminProvider _users;

  bool get _isEdit => widget.existing != null;
  bool get _isAgent => widget.existing?.role == UserRole.agent;

  @override
  void initState() {
    super.initState();
    _users = context.read<UserAdminProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _users.clearError());
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _emailCtrl, _phoneCtrl, _cinCtrl, _addressCtrl]) {
      c.dispose();
    }
    Future.microtask(_users.clearError);
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _emailError = null);
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final result = await _users.saveUser(
      existing: widget.existing,
      fullName: _nameCtrl.text,
      email: _emailCtrl.text,
      phone: _phoneCtrl.text,
      role: _role,
      agencyId: _role == UserRole.agency ? _agencyId : null,
      cin: _cinCtrl.text,
      address: _addressCtrl.text,
      isActive: _isActive,
    );
    if (!mounted) return;
    if (result == null) {
      if (_users.errorField == 'email') setState(() => _emailError = _users.errorMessage);
      return;
    }
    if (result.isNotEmpty) {
      await showTemporaryPasswordDialog(context,
          email: _emailCtrl.text.trim().toLowerCase(), password: result);
      if (!mounted) return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.success,
      content: Text(_isEdit ? 'Compte modifié' : 'Compte créé'),
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final users = context.watch<UserAdminProvider>();
    final agencies = context.watch<AgencyProvider>().agencies;
    final me = context.watch<AuthProvider>().currentUser;
    final isMe = widget.existing?.id != null && widget.existing?.id == me?.id;
    final generalError = users.errorField == null ? users.errorMessage : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, _isEdit ? 'Utilisateur' : 'Nouvel utilisateur', close: true),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (generalError != null) ...[
              MessageBanner(type: BannerType.error, message: generalError),
              const SizedBox(height: 16),
            ],
            AuthTextField(
              label: 'Nom complet',
              icon: Icons.person_outline,
              hint: 'Ex. Rania Nasri',
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [LengthLimitingTextInputFormatter(50)],
              validator: Validators.fullName,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              label: 'Email',
              icon: Icons.mail_outline,
              hint: 'vous@email.tn',
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
            // BF1.4 : le rôle peut être changé, sauf pour un agent ou pour soi-même.
            if (_isAgent || isMe)
              WhiteCard(child: InfoRow('Rôle', _role.label))
            else
              ChoiceChipsField<UserRole>(
                label: 'Rôle',
                selected: _role,
                onSelected: (r) => setState(() => _role = r),
                options: const [
                  (UserRole.client, 'Client'),
                  (UserRole.owner, 'Propriétaire'),
                  (UserRole.agency, 'Agence'),
                  (UserRole.admin, 'Admin'),
                ],
              ),
            if (!_isEdit)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Les agents s’ajoutent depuis la fiche de leur agence.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
              ),
            if (_role == UserRole.agency) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _agencyId,
                decoration: InputDecoration(
                  labelText: 'Agence',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: [
                  for (final a in agencies)
                    DropdownMenuItem(value: a.agency.id, child: Text(a.agency.name)),
                ],
                onChanged: (v) => setState(() => _agencyId = v),
                validator: (v) => v == null ? 'Choisissez une agence' : null,
              ),
            ],
            // BF1.2 : profil propriétaire (CIN + adresse).
            if (_role == UserRole.owner) ...[
              const SizedBox(height: 16),
              AuthTextField(
                label: 'CIN',
                icon: Icons.badge_outlined,
                hint: '8 chiffres',
                controller: _cinCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                validator: Validators.cin,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: 'Adresse',
                icon: Icons.home_outlined,
                hint: 'Rue, ville',
                controller: _addressCtrl,
                inputFormatters: [LengthLimitingTextInputFormatter(120)],
                validator: Validators.address,
              ),
            ],
            const SizedBox(height: 16),
            WhiteCard(
              child: SwitchListTile(
                value: _isActive,
                // L'admin ne peut pas désactiver son propre compte.
                onChanged: isMe ? null : (v) => setState(() => _isActive = v),
                activeTrackColor: AppColors.primary,
                title: const Text('Compte actif', style: TextStyle(fontSize: 14)),
                subtitle: Text(
                    isMe
                        ? 'Vous ne pouvez pas désactiver votre propre compte.'
                        : 'Un compte inactif ne peut pas se connecter.',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(label: 'Enregistrer', loading: users.isSaving, onPressed: _submit),
            // BF1.5 : suppression réservée à l'administrateur.
            if (_isEdit && !isMe && me?.role == UserRole.admin) ...[
              const SizedBox(height: 8),
              DeleteUserButton(user: widget.existing!),
            ],
          ],
        ),
      ),
    );
  }
}
