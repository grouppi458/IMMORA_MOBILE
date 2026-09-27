import 'constants.dart';

/// Contrôles de saisie des formulaires. Chaque méthode renvoie `null` si la
/// valeur est valide, sinon le message d'erreur à afficher sous le champ.
class Validators {
  Validators._();

  static final _emailRegex =
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
  static final _nameRegex = RegExp(r"^[A-Za-zÀ-ÖØ-öø-ÿ' -]+$");
  static final _cityRegex = RegExp(r"^[A-Za-zÀ-ÖØ-öø-ÿ' -]+$");

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'L’email est obligatoire';
    if (v.length > 100) return 'Email trop long';
    if (!_emailRegex.hasMatch(v)) return 'Format d’email invalide (ex. nom@domaine.tn)';
    return null;
  }

  static String? fullName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Le nom complet est obligatoire';
    if (v.length < nameMinLength) return 'Au moins $nameMinLength caractères';
    if (v.length > nameMaxLength) return 'Au plus $nameMaxLength caractères';
    if (!_nameRegex.hasMatch(v)) return 'Lettres, espaces, apostrophes et tirets uniquement';
    if (!v.contains(' ')) return 'Indiquez le prénom et le nom';
    return null;
  }

  /// Numéro tunisien : 8 chiffres, préfixe +216 / 00216 facultatif.
  static String? phone(String? value) {
    final v = (value ?? '').replaceAll(RegExp(r'[\s.-]'), '');
    if (v.isEmpty) return 'Le téléphone est obligatoire';
    final local = v.replaceFirst(RegExp(r'^(\+216|00216)'), '');
    if (!RegExp(r'^\d{8}$').hasMatch(local)) {
      return 'Numéro tunisien de 8 chiffres (ex. +216 22 123 456)';
    }
    if (!RegExp(r'^[2-9]').hasMatch(local)) return 'Numéro tunisien invalide';
    return null;
  }

  /// Normalise un numéro valide au format `+216XXXXXXXX`.
  static String normalizePhone(String value) {
    final v = value.replaceAll(RegExp(r'[\s.-]'), '');
    return '+216${v.replaceFirst(RegExp(r'^(\+216|00216)'), '')}';
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Le mot de passe est obligatoire';
    if (v.length < passwordMinLength) return '$passwordMinLength caractères minimum';
    if (v.length > passwordMaxLength) return '$passwordMaxLength caractères maximum';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Au moins une lettre et un chiffre';
    }
    return null;
  }

  /// Pour la connexion : on vérifie seulement que le champ est rempli.
  static String? requiredPassword(String? value) =>
      (value ?? '').isEmpty ? 'Le mot de passe est obligatoire' : null;

  static String? agencyName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Le nom de l’agence est obligatoire';
    if (v.length < 2) return 'Au moins 2 caractères';
    if (v.length > 60) return 'Au plus 60 caractères';
    return null;
  }

  static String? city(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'La ville est obligatoire';
    if (v.length < 2 || v.length > 40) return 'Entre 2 et 40 caractères';
    if (!_cityRegex.hasMatch(v)) return 'Lettres uniquement';
    return null;
  }

  static String? address(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'L’adresse est obligatoire';
    if (v.length < 5) return 'Adresse trop courte';
    if (v.length > 120) return 'Adresse trop longue';
    return null;
  }
}
