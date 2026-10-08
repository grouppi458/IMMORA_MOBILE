import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Hachage des mots de passe : SHA-256(sel + mot de passe).
/// Le mot de passe en clair n'est jamais stocké.
class PasswordService {
  PasswordService._();

  static String generateSalt([int length = 16]) {
    final random = Random.secure();
    return base64Url.encode(List<int>.generate(length, (_) => random.nextInt(256)));
  }

  /// Mot de passe temporaire donné à un compte créé par l'admin ou l'agence
  /// (10 caractères, au moins une lettre et un chiffre, sans caractères ambigus).
  static String generateTemporaryPassword() {
    const letters = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ';
    const digits = '23456789';
    const all = letters + digits;
    final random = Random.secure();
    final chars = [
      letters[random.nextInt(letters.length)],
      digits[random.nextInt(digits.length)],
      for (var i = 0; i < 8; i++) all[random.nextInt(all.length)],
    ]..shuffle(random);
    return chars.join();
  }

  static String hash(String password, String salt) =>
      sha256.convert(utf8.encode('$salt$password')).toString();

  static bool verify(String password, String salt, String expectedHash) =>
      hash(password, salt) == expectedHash;
}
