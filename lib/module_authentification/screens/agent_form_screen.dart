import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/widgets/auth_text_field.dart';
import 'package:immora_mobile/core/widgets/message_banner.dart';
import 'package:immora_mobile/core/widgets/primary_button.dart';
import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/module_authentification/models/agent_with_user.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/core/utils/validators.dart';
import 'package:immora_mobile/module_authentification/providers/user_admin_provider.dart';
import 'package:immora_mobile/module_authentification/widgets/delete_user_action.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';

/// Création ou modification d'un agent (AgentFormPage).
class AgentFormScreen extends StatefulWidget {
  const AgentFormScreen({super.key, required this.agencyId, this.existing});

  final int agencyId;
  final AgentWithUser? existing;

  @override
  State<AgentFormScreen> createState() => _AgentFormScreenState();
}

class _AgentFormScreenState extends State<AgentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.existing?.user.fullName);
  late final _emailCtrl = TextEditingController(text: widget.existing?.user.email);
  late final _phoneCtrl = TextEditingController(text: widget.existing?.user.phone);
  late final _rateCtrl = TextEditingController(
      text: widget.existing == null ? '3' : formatRate(widget.existing!.agent.commissionRate));
  late String _speciality = widget.existing?.agent.speciality ?? 'vente';
  late DateTime _hireDate = widget.existing == null || widget.existing!.agent.hireDate == 0
      ? DateTime.now()
      : DateTime.fromMillisecondsSinceEpoch(widget.existing!.agent.hireDate);
  late bool _isActive = widget.existing?.user.isActive ?? true;
  String? _emailError;
  late final UserAdminProvider _admin;

  @override
  void initState() {
    super.initState();
    _admin = context.read<UserAdminProvider>();
    _rateCtrl.addListener(() => setState(() {})); // met à jour « Enregistré en décimal »
    WidgetsBinding.instance.addPostFrameCallback((_) => _admin.clearError());
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _emailCtrl, _phoneCtrl, _rateCtrl]) {
      c.dispose();
    }
    Future.microtask(_admin.clearError);
    super.dispose();
  }

  String get _decimalHint {
    if (Validators.commissionPercent(_rateCtrl.text) != null) return 'Exemple : 3 % = 0.03';
    final rate = Validators.parsePercent(_rateCtrl.text) / 100;
    return 'Enregistré en décimal : ${double.parse(rate.toStringAsFixed(4))}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _hireDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Date d’embauche',
    );
    if (picked != null) setState(() => _hireDate = picked);
  }

  Future<void> _submit() async {
    setState(() => _emailError = null);
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final result = await _admin.saveAgent(
      existing: widget.existing,
      agencyId: widget.agencyId,
      fullName: _nameCtrl.text,
      email: _emailCtrl.text,
      phone: _phoneCtrl.text,
      speciality: _speciality,
      commissionPercent: _rateCtrl.text,
      hireDate: _hireDate,
      isActive: _isActive,
    );
    if (!mounted) return;
    if (result == null) {
      if (_admin.errorField == 'email') setState(() => _emailError = _admin.errorMessage);
      return;
    }
    if (result.isNotEmpty) {
      await showTemporaryPasswordDialog(context,
          email: _emailCtrl.text.trim().toLowerCase(), password: result);
      if (!mounted) return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.success,
      content: Text(widget.existing == null ? 'Agent ajouté' : 'Agent modifié'),
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<UserAdminProvider>();
    final generalError = admin.errorField == null ? admin.errorMessage : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, widget.existing == null ? 'Nouvel agent' : 'Agent',
          close: true),
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
              hint: 'Ex. Sirine Ben Salah',
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [LengthLimitingTextInputFormatter(50)],
              validator: Validators.fullName,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              label: 'Email',
              icon: Icons.mail_outline,
              hint: 'prenom@agence.tn',
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
            ChoiceChipsField<String>(
              label: 'Spécialité',
              selected: _speciality,
              onSelected: (s) => setState(() => _speciality = s),
              options: [for (final e in agentSpecialities.entries) (e.key, e.value)],
            ),
            const SizedBox(height: 16),
            AuthTextField(
              label: 'Taux de commission (%)',
              icon: Icons.percent,
              hint: '3',
              controller: _rateCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                LengthLimitingTextInputFormatter(5),
              ],
              validator: Validators.commissionPercent,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_decimalHint,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
            ),
            const SizedBox(height: 16),
            const Text('Date d’embauche',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textDark)),
            const SizedBox(height: 6),
            Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppColors.border),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _pickDate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_outlined, size: 20),
                    const SizedBox(width: 12),
                    Text(formatDateNumeric(_hireDate), style: const TextStyle(fontSize: 14)),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 16),
            WhiteCard(
              child: SwitchListTile(
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                activeTrackColor: AppColors.primary,
                title: const Text('Compte actif', style: TextStyle(fontSize: 14)),
                subtitle: const Text('Un compte inactif ne peut pas se connecter.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(label: 'Enregistrer', loading: admin.isSaving, onPressed: _submit),
            // BF1.5 : l'admin ou l'agence peut supprimer un agent.
            if (widget.existing != null) ...[
              const SizedBox(height: 8),
              DeleteUserButton(user: widget.existing!.user),
            ],
          ],
        ),
      ),
    );
  }
}
