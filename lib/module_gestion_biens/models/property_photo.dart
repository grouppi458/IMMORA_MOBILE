/// Photo d'un bien (table `property_photos`, BF3.2).
/// Les fichiers sont copiés dans /photos/ (image_picker + path_provider) ;
/// [path] est le chemin local affiché par l'application.
class PropertyPhoto {
  final int? id;
  final int propertyId;
  final String path;
  final bool isMain; // photo principale (badge « Principale »)
  final int position; // ordre d'affichage (glisser pour réordonner)
  final int addedAt;

  PropertyPhoto({
    this.id,
    required this.propertyId,
    required this.path,
    this.isMain = false,
    this.position = 0,
    required this.addedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'propertyId': propertyId,
        'path': path,
        'isMain': isMain ? 1 : 0,
        'position': position,
        'addedAt': addedAt,
      };

  factory PropertyPhoto.fromMap(Map<String, dynamic> m) => PropertyPhoto(
        id: m['id'],
        propertyId: m['propertyId'],
        path: m['path'],
        isMain: m['isMain'] == 1,
        position: m['position'] ?? 0,
        addedAt: m['addedAt'],
      );
}
