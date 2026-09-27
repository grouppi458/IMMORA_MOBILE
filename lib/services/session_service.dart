import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../utils/enums.dart';

const String keyUserId = 'current_user_id';
const String keyAgencyId = 'current_agency_id';
const String keyRole = 'current_role';
const String keyIsLogged = 'is_logged_in';

class Session {
  final int userId;
  final int? agencyId;
  final UserRole? role;
  final bool isLoggedIn;

  const Session({
    required this.userId,
    this.agencyId,
    this.role,
    required this.isLoggedIn,
  });

  static const empty = Session(userId: 0, isLoggedIn: false);
}

/// Session courante (shared_preferences), lue par les 3 ingénieurs.
class SessionService {
  SessionService._();

  static Future<Session> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt(keyUserId);
    if (userId == null) return Session.empty;
    final roleName = prefs.getString(keyRole);
    return Session(
      userId: userId,
      agencyId: prefs.getInt(keyAgencyId),
      role: roleName == null ? null : UserRole.values.byName(roleName),
      isLoggedIn: prefs.getBool(keyIsLogged) ?? false,
    );
  }

  /// [remember] = false : la session ne sera pas restaurée au prochain lancement.
  static Future<void> save(User user, {bool remember = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyUserId, user.id!);
    if (user.agencyId != null) {
      await prefs.setInt(keyAgencyId, user.agencyId!);
    } else {
      await prefs.remove(keyAgencyId);
    }
    await prefs.setString(keyRole, user.role.name);
    await prefs.setBool(keyIsLogged, remember);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyUserId);
    await prefs.remove(keyAgencyId);
    await prefs.remove(keyRole);
    await prefs.remove(keyIsLogged);
  }
}
