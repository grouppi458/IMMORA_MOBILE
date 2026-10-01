import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/immora_logo.dart';
import '../widgets/message_banner.dart';
import '../widgets/primary_button.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';
import 'register_choice_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _rememberMe = true;

  bool get _formValid =>
      Validators.email(_emailCtrl.text) == null &&
      Validators.requiredPassword(_passwordCtrl.text) == null;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    context.read<AuthProvider>().clearError();
    setState(() {}); // réévalue l'état du bouton
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(
      _emailCtrl.text,
      _passwordCtrl.text,
      rememberMe: _rememberMe,
    );
    if (!ok || !mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Column(
        children: [
          // En-tête bleu avec logo
          const SafeArea(
            bottom: false,
            child: SizedBox(
              height: 130,
              child: Center(child: ImmoraLogo(height: 44)),
            ),
          ),
          // Feuille blanche
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                child: Form(key: _formKey, child: _buildForm(context)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final hasError = auth.errorMessage != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bon retour',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Connectez-vous à votre espace IMMORA.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 20),
        if (hasError) ...[
          MessageBanner(type: BannerType.error, message: auth.errorMessage!),
          const SizedBox(height: 16),
        ],
        AuthTextField(
          label: 'Email',
          icon: Icons.mail_outline,
          hint: 'vous@email.tn',
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          hasError: hasError,
          validator: Validators.email,
          onChanged: _onChanged,
        ),
        const SizedBox(height: 16),
        AuthTextField(
          label: 'Mot de passe',
          icon: Icons.lock_outline,
          hint: '••••••••',
          controller: _passwordCtrl,
          obscure: true,
          hasError: hasError,
          validator: Validators.requiredPassword,
          onChanged: _onChanged,
        ),
        if (hasError)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Identifiants non reconnus',
              style: TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _rememberMe,
                onChanged: (v) => setState(() => _rememberMe = v ?? false),
              ),
            ),
            const SizedBox(width: 8),
            const Text('Se souvenir', style: TextStyle(fontSize: 13)),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
              ),
              child: const Text(
                'Mot de passe oublié ?',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: hasError ? 'Réessayer' : 'Se connecter',
          loading: auth.isLoading,
          onPressed: _formValid ? _login : null,
        ),
        const SizedBox(height: 16),
        Center(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Pas encore de compte ? ',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              GestureDetector(
                onTap: () {
                  auth.clearError();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RegisterChoiceScreen()),
                  );
                },
                child: const Text(
                  'Créer un compte',
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
    );
  }
}
