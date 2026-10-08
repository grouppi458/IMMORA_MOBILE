class Agency {
  final int? id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String city;
  final String? logoPath; // chemin local de l'image
  final bool isActive;
  final int createdAt; // DateTime.now().millisecondsSinceEpoch

  Agency({
    this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.city,
    this.logoPath,
    this.isActive = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'city': city,
        'logoPath': logoPath,
        'isActive': isActive ? 1 : 0,
        'createdAt': createdAt,
      };

  factory Agency.fromMap(Map<String, dynamic> m) => Agency(
        id: m['id'],
        name: m['name'],
        email: m['email'],
        phone: m['phone'] ?? '',
        address: m['address'] ?? '',
        city: m['city'] ?? '',
        logoPath: m['logoPath'],
        isActive: m['isActive'] == 1,
        createdAt: m['createdAt'],
      );
}
