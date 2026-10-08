/// Erreur métier affichée telle quelle à l'utilisateur (espaces admin et agence).
/// Partagée par le module Authentification (M1) et le module Agences (M2).
class AdminException implements Exception {
  AdminException(this.message, {this.field});

  final String message;

  /// Champ concerné ('email', 'agency'…) pour afficher l'erreur sous ce champ.
  final String? field;

  @override
  String toString() => message;
}
