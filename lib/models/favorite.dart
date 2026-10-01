class Favorite {
  final int? id;
  final int clientId;
  final int propertyId;
  final int addedAt;

  Favorite({
    this.id,
    required this.clientId,
    required this.propertyId,
    required this.addedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientId': clientId,
      'propertyId': propertyId,
      'addedAt': addedAt,
    };
  }

  factory Favorite.fromMap(Map<String, dynamic> map) {
    return Favorite(
      id: map['id'] as int?,
      clientId: map['clientId'] as int,
      propertyId: map['propertyId'] as int,
      addedAt: map['addedAt'] as int,
    );
  }
}
