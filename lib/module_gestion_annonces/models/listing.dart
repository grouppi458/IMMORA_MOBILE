import 'package:immora_mobile/core/utils/enums.dart';

/// Annonce (table `listings`) : la publication d'un bien sur la vitrine
/// visible par les clients (Module 5).
class Listing {
  final int? id;
  final int propertyId;
  final int agencyId;
  final int? createdBy; // users.id de l'agence ou de l'agent
  final String title;
  final String text;
  final double displayedPrice; // TND
  final int durationDays; // 30, 60 ou 90 (+ prolongations)
  final ListingStatus status;
  final bool isFeatured; // mise en avant
  final int viewsCount;
  final int? publishedAt; // null tant que l'annonce est un brouillon
  final int? expiresAt;
  final int createdAt;
  final int updatedAt;

  Listing({
    this.id,
    required this.propertyId,
    required this.agencyId,
    this.createdBy,
    required this.title,
    required this.text,
    required this.displayedPrice,
    required this.durationDays,
    this.status = ListingStatus.draft,
    this.isFeatured = false,
    this.viewsCount = 0,
    this.publishedAt,
    this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPublished => status == ListingStatus.published;

  /// Jours restants avant expiration (0 si dépassée, null si jamais publiée).
  int? get daysLeft {
    if (expiresAt == null) return null;
    final diff = DateTime.fromMillisecondsSinceEpoch(expiresAt!).difference(DateTime.now());
    // Arrondi au jour supérieur : une annonce de 60 jours affiche « J-60 ».
    return diff.isNegative ? 0 : (diff.inMinutes / Duration.minutesPerDay).ceil();
  }

  static const columns = [
    'id', 'propertyId', 'agencyId', 'createdBy', 'title', 'text', 'displayedPrice',
    'durationDays', 'status', 'isFeatured', 'viewsCount', 'publishedAt', 'expiresAt',
    'createdAt', 'updatedAt',
  ];

  Map<String, dynamic> toMap() => {
        'id': id,
        'propertyId': propertyId,
        'agencyId': agencyId,
        'createdBy': createdBy,
        'title': title,
        'text': text,
        'displayedPrice': displayedPrice,
        'durationDays': durationDays,
        'status': status.name,
        'isFeatured': isFeatured ? 1 : 0,
        'viewsCount': viewsCount,
        'publishedAt': publishedAt,
        'expiresAt': expiresAt,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory Listing.fromMap(Map<String, dynamic> m) => Listing(
        id: m['id'],
        propertyId: m['propertyId'],
        agencyId: m['agencyId'],
        createdBy: m['createdBy'],
        title: m['title'],
        text: m['text'] ?? '',
        displayedPrice: (m['displayedPrice'] as num).toDouble(),
        durationDays: m['durationDays'],
        status: ListingStatus.values.byName(m['status']),
        isFeatured: m['isFeatured'] == 1,
        viewsCount: m['viewsCount'] ?? 0,
        publishedAt: m['publishedAt'],
        expiresAt: m['expiresAt'],
        createdAt: m['createdAt'],
        updatedAt: m['updatedAt'],
      );
}
