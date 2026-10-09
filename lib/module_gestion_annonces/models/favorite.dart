/// Favori d'un client sur une annonce (table `favorites`, BF5.2).
/// Une même annonce ne peut être ajoutée qu'une fois : UNIQUE(clientId, listingId).
class Favorite {
  final int? id;
  final int clientId; // users.id (rôle client)
  final int listingId;
  final int addedAt;

  Favorite({
    this.id,
    required this.clientId,
    required this.listingId,
    required this.addedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'clientId': clientId,
        'listingId': listingId,
        'addedAt': addedAt,
      };

  factory Favorite.fromMap(Map<String, dynamic> m) => Favorite(
        id: m['id'],
        clientId: m['clientId'],
        listingId: m['listingId'],
        addedAt: m['addedAt'],
      );
}
