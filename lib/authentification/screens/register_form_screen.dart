import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/repositories/auth_repository.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import '../../utils/enums.dart';
import '../../utils/validators.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/message_banner.dart';
import '../widgets/primary_button.dart';
import 'register_choice_screen.dart';

/// Formulaire d'inscription (client, agence ou propriétaire).
class RegisterFormScreen extends StatefulWidget {
  const RegisterFormScreen({super.key, required this.role});

  final AccountRole role;

  @override
  State<RegisterFormScreen> createState() => _RegisterFormScreenState();
}

class _RegisterFormScreenState extends State<RegisterFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _agencyNameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _acceptTerms = false;
  bool _termsError = false;
  String? _emailError; // erreur venant de la base

  late final AuthProvider _auth;

  bool get _isAgency => widget.role.userRole == UserRole.agency;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _auth.clearError());
  }

  @override
  void dispose() {
    // Ne pas laisser l'erreur de ce formulaire s'afficher sur l'écran de connexion.
    Future.microtask(_auth.clearError);
    for (final c in [
      _agencyNameCtrl, _cityCtrl, _addressCtrl, _nameCtrl,
      _emailCtrl, _phoneCtrl, _passwordCtrl, _confirmCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _confirmValidator(String? v) {
    if ((v ?? '').isEmpty) return 'Confirmez le mot de passe';
    if (v != _passwordCtrl.text) return 'Les mots de passe ne correspondent pas';
    return null;
  }

  Future<void> _submit() async {
    final formOk = _formKey.currentState!.validate();
    setState(() => _termsError = !_acceptTerms);
    if (!formOk || !_acceptTerms) return;
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthProvider>();
    final ok = await auth.register(RegistrationData(
      role: widget.role.userRole,
      fullName: _nameCtrl.text,
      email: _emailCtrl.text,
      phone: _phoneCtrl.text,
      password: _passwordCtrl.text,
      agencyName: _isAgency ? _agencyNameCtrl.text : null,
      agencyCity: _isAgency ? _cityCtrl.text : null,
      agencyAddress: _isAgency ? _addressCtrl.text : null,
    ));
    if (!mounted) return;

    if (!ok) {
      if (auth.errorField == 'email') setState(() => _emailError = auth.errorMessage);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.success,
        content: Text(_isAgency
            ? 'Agence créée avec un essai gratuit de $freeTrialDays jours. Connectez-vous.'
            : 'Compte créé avec succès. Connectez-vous.'),
      ),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final generalError = auth.errorField == null ? auth.errorMessage : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.role.formTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (generalError != null) ...[
              MessageBanner(type: BannerType.error, message: generalError),
              const SizedBox(height: 16),
            ],
            if (_isAgency) ...[
              AuthTextField(
                label: 'Nom de l’agence',
                icon: Icons.apartment_outlined,
                hint: 'Ex. Immo Carthage',
                controller: _agencyNameCtrl,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(60)],
                validator: Validators.agencyName,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: 'Ville',
                icon: Icons.location_city_outlined,
                hint: 'Ex. Tunis',
                controller: _cityCtrl,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(40)],
                validator: Validators.city,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: 'Adresse',
                icon: Icons.place_outlined,
                hint: 'Ex. 12 avenue Habib Bourguiba',
                controller: _addressCtrl,
                inputFormatters: [LengthLimitingTextInputFormatter(120)],
                validator: Validators.address,
              ),
              const SizedBox(height: 24),
              const Text('Responsable du compte',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 12),
            ],
            AuthTextField(
              label: 'Nom complet',
              icon: Icons.person_outline,
              hint: 'Ex. Yassine Trabelsi',
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [LengthLimitingTextInputFormatter(nameMaxLength)],
              validator: Validators.fullName,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              label: 'Email',
              icon: Icons.mail_outline,
              hint: 'vous@email.tn',
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
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
            AuthTextField(
              label: 'Mot de passe',
              icon: Icons.lock_outline,
              hint: '$passwordMinLength caractères minimum',
              controller: _passwordCtrl,
              obscure: true,
              inputFormatters: [LengthLimitingTextInputFormatter(passwordMaxLength)],
              validator: Validators.password,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              label: 'Confirmer le mot de passe',
              icon: Icons.lock_outline,
              hint: 'Retapez le mot de passe',
              controller: _confirmCtrl,
              obscure: true,
              inputFormatters: [LengthLimitingTextInputFormatter(passwordMaxLength)],
              validator: _confirmValidator,
            ),
            const SizedBox(height: 6),
            const Text(
              'Haché en SHA-256 + sel avant l’enregistrement.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _acceptTerms,
                    isError: _termsError,
                    onChanged: (v) => setState(() {
                      _acceptTerms = v ?? false;
                      _termsError = false;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'J’accepte les conditions d’utilisation d’IMMORA.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            if (_termsError)
              const Padding(
                padding: EdgeInsets.only(top: 6, left: 32),
                child: Text(
                  'Vous devez accepter les conditions',
                  style: TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Créer mon compte',
              loading: auth.isLoading,
              onPressed: _submit,
            ),
            const SizedBox(height: 16),
            Center(
              child: Wrap(
                children: [
                  const Text(
                    'Déjà inscrit ? ',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  GestureDetector(
                    onTap: () =>
                        Navigator.of(context).popUntil((route) => route.isFirst),
                    child: const Text(
                      'Se connecter',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
