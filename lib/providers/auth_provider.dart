import 'package:flutter/foundation.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/user_repository.dart';
import '../models/user.dart';
import '../services/session_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthRepository? authRepository, UserRepository? userRepository})
      : _auth = authRepository ?? AuthRepository(),
        _users = userRepository ?? UserRepository();

  final AuthRepository _auth;
  final UserRepository _users;

  bool isLoading = false;
  String? errorMessage;
  String? errorField; // champ en erreur ('email'…)
  User? currentUser;

  bool get isLoggedIn => currentUser != null;

  void clearError() {
    if (errorMessage == null) return;
    errorMessage = null;
    errorField = null;
    notifyListeners();
  }

  Future<bool> login(String email, String password, {bool rememberMe = true}) =>
      _run(() async {
        currentUser = await _auth.login(email, password);
        await SessionService.save(currentUser!, remember: rememberMe);
      });

  Future<bool> register(RegistrationData data) =>
      _run(() async => _auth.register(data));

  /// Restaure l'utilisateur si « Se souvenir » était coché.
  Future<bool> restoreSession() async {
    final session = await SessionService.getSession();
    if (!session.isLoggedIn) return false;
    final user = await _users.findById(session.userId);
    if (user == null || !user.isActive) {
      await SessionService.clear();
      return false;
    }
    currentUser = user;
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    await SessionService.clear();
    currentUser = null;
    notifyListeners();
  }

  Future<bool> emailExists(String email) => _users.emailExists(email);

  Future<bool> _run(Future<void> Function() action) async {
    isLoading = true;
    errorMessage = null;
    errorField = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on AuthException catch (e) {
      errorMessage = e.message;
      errorField = e.field;
      return false;
    } catch (e) {
      debugPrint('AuthProvider: $e');
      errorMessage = 'Une erreur est survenue. Réessayez.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
