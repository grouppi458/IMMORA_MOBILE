/// Notification affichée dans l'application (table `notifications`).
/// Le M5 crée les « nouvelle annonce pour vous » (BF5.9) ; le M6 ajoute les
/// confirmations, annulations et comptes rendus de visite.
class AppNotification {
  final int? id;
  final int userId;
  final String type; // 'newListing' (M5), 'visit…' (M6)
  final String title;
  final String body;
  final int? listingId;
  final int? score; // compatibilité (0–100) pour 'newListing'
  final bool isRead;
  final int createdAt;

  static const newListing = 'newListing';

  // Module 6 — visites (le client est destinataire).
  static const visitConfirmed = 'visitConfirmed';
  static const visitCancelled = 'visitCancelled';
  static const visitDone = 'visitDone';
  static const visitAbsent = 'visitAbsent'; // no-show

  AppNotification({
    this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.listingId,
    this.score,
    this.isRead = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'type': type,
        'title': title,
        'body': body,
        'listingId': listingId,
        'score': score,
        'isRead': isRead ? 1 : 0,
        'createdAt': createdAt,
      };

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
        id: m['id'],
        userId: m['userId'],
        type: m['type'],
        title: m['title'],
        body: m['body'] ?? '',
        listingId: m['listingId'],
        score: m['score'],
        isRead: m['isRead'] == 1,
        createdAt: m['createdAt'],
      );
}
