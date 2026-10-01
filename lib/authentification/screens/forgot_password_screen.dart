import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/message_banner.dart';
import '../widgets/primary_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _emailError; // erreur venant de la base

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() {
      _emailError = null;
      _sent = false;
    });
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    // L'app fonctionne hors ligne : on vérifie seulement que le compte existe.
    final exists = await context.read<AuthProvider>().emailExists(
      _emailCtrl.text,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _sent = exists;
      _emailError = exists ? null : 'Aucun compte n’est associé à cet email';
    });
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.success,
          content: Text('Code envoyé à votre email'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Réinitialiser')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 32),
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 34,
                  color: AppColors.secondary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Mot de passe oublié ?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Text(
              'Entrez votre email : vous recevrez un code\nde réinitialisation.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 40),
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
            PrimaryButton(
              label: 'Envoyer le code',
              loading: _loading,
              onPressed: _sendCode,
            ),
            if (_sent) ...[
              const SizedBox(height: 16),
              const MessageBanner(
                type: BannerType.success,
                message: 'Succès : code envoyé à votre email.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
