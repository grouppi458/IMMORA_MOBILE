import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/module_authentification/models/user.dart';
import 'package:immora_mobile/module_authentification/providers/auth_provider.dart';
import 'package:immora_mobile/module_authentification/providers/user_admin_provider.dart';

/// BF1.5 — demande confirmation puis supprime (ou désactive) [user].
/// Renvoie true si l'opération a réussi : l'écran appelant peut se fermer.
Future<bool> confirmAndDeleteUser(BuildContext context, User user) async {
  final users = context.read<UserAdminProvider>();
  final me = context.read<AuthProvider>().currentUser;
  if (me == null) return false;

  final ok = await confirmDialog(
    context,
    title: 'Supprimer ${user.fullName} ?',
    message: 'Le compte sera supprimé définitivement. S’il est lié à des biens, '
        'visites ou transactions, il sera seulement désactivé pour garder l’historique.',
    confirmLabel: 'Supprimer',
  );
  if (!ok || !context.mounted) return false;

  final result = await users.deleteUser(user, currentUserId: me.id!);
  if (!context.mounted) return false;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    backgroundColor: result == null ? AppColors.error : AppColors.success,
    content: Text(switch (result) {
      'deleted' => 'Compte supprimé',
      'deactivated' => 'Compte lié à des données : il a été désactivé',
      _ => users.errorMessage ?? 'Erreur',
    }),
  ));
  return result != null;
}

/// Bouton rouge « Supprimer le compte » placé en bas des formulaires.
class DeleteUserButton extends StatelessWidget {
  const DeleteUserButton({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () async {
        final done = await confirmAndDeleteUser(context, user);
        if (done && context.mounted) Navigator.of(context).pop();
      },
      icon: const Icon(Icons.delete_outline, color: AppColors.error),
      label: const Text('Supprimer le compte',
          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
    );
  }
}
