import 'package:sqflite/sqflite.dart';

import 'package:immora_mobile/module_gestion_annonces/models/app_notification.dart';

/// Données de démonstration du Module 6, calquées sur les maquettes Figma :
/// cinq visites pour le client de démo — effectuée (à noter), effectuée et
/// notée, annulée par l'agence, absente (no-show), confirmée et demandée —
/// plus deux visites supplémentaires sur une même journée pour le calendrier
/// de l'agence, et deux notifications.
class DemoDataVisits {
  DemoDataVisits._();

  static Future<void> seed(Database db) async {
    final existing =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM visits')) ?? 0;
    if (existing > 0) return;

    Future<int?> idWhere(String table, String column, Object value) async {
      final rows = await db.query(table,
          columns: ['id'], where: '$column = ?', whereArgs: [value], limit: 1);
      return rows.isEmpty ? null : rows.first['id'] as int;
    }

    final client = await idWhere('users', 'email', 'client@immora.tn');
    if (client == null) return;

    Future<(int, int, int?, int?)?> listingByTitle(String title) async {
      final rows = await db.rawQuery(
        'SELECT l.id, l.agencyId, l.propertyId, p.agentId FROM listings l '
        'JOIN properties p ON p.id = l.propertyId WHERE l.title = ? LIMIT 1',
        [title],
      );
      if (rows.isEmpty) return null;
      final r = rows.first;
      return (r['id'] as int, r['agencyId'] as int, r['propertyId'] as int?,
          r['agentId'] as int?);
    }

    final now = DateTime.now();
    int at(DateTime d) => d.millisecondsSinceEpoch;
    DateTime daysFromNow(int d, String slot) {
      final base = now.add(Duration(days: d));
      final parts = slot.split(':').map(int.parse).toList();
      return DateTime(base.year, base.month, base.day, parts[0], parts[1]);
    }

    Future<int?> insertVisit(
      String title,
      String status,
      DateTime scheduled,
      DateTime created, {
      DateTime? decidedAt,
      DateTime? doneAt,
      String? note,
      String? cancelReason,
      int? rating,
      String? ratingComment,
      String? agentNote,
    }) async {
      final target = await listingByTitle(title);
      if (target == null) return null;
      final (listingId, agencyId, propertyId, agentId) = target;
      final c = at(created);
      return db.insert('visits', {
        'propertyId': propertyId,
        'listingId': listingId,
        'agencyId': agencyId,
        'clientId': client,
        'agentId': agentId,
        'status': status,
        'scheduledAt': at(scheduled),
        'clientNote': note,
        'decidedAt': decidedAt == null ? null : at(decidedAt),
        'doneAt': doneAt == null ? null : at(doneAt),
        'cancelReason': cancelReason,
        'rating': rating,
        'ratingComment': ratingComment,
        'agentNote': agentNote,
        'createdAt': c,
        'updatedAt': doneAt == null ? (decidedAt == null ? c : at(decidedAt)) : at(doneAt),
      });
    }

    // Effectuée il y a ~10 jours, pas encore notée (« à noter ») : le bien
    // sort de « Pour vous » (BF5.8) et la notification invite à noter.
    await insertVisit('S+3 familial à El Menzah 5', 'done', daysFromNow(-10, '10:30'),
        now.subtract(const Duration(days: 12)),
        decidedAt: now.subtract(const Duration(days: 11)),
        doneAt: now.subtract(const Duration(days: 10)));
    await db.insert('notifications', {
      'userId': client,
      'type': AppNotification.visitDone,
      'title': 'Visite effectuée',
      'body': '« S+3 familial à El Menzah 5 » : merci d’avoir visité avec Carthage Immobilier.',
      'listingId': null,
      'isRead': 1,
      'createdAt': at(now.subtract(const Duration(days: 10))),
    });

    // Effectuée et notée : alimente la vue agent (note du client + compte rendu).
    await insertVisit('S+3 meublé avec vue à Carthage', 'done', daysFromNow(-9, '15:30'),
        now.subtract(const Duration(days: 11)),
        decidedAt: now.subtract(const Duration(days: 10)),
        doneAt: now.subtract(const Duration(days: 9)),
        rating: 4,
        ratingComment: 'Agent ponctuel, bien conforme aux photos.',
        agentNote: 'Client très intéressé, souhaite négocier autour de 420 000 TND.');

    // Annulée par l'agence.
    await insertVisit('Plateau de bureaux au Centre Urbain Nord', 'cancelled',
        daysFromNow(-26, '11:00'), now.subtract(const Duration(days: 28)),
        decidedAt: now.subtract(const Duration(days: 27)),
        cancelReason: 'Indisponibilité de l’agence');

    // Le client ne s'est pas présenté (no-show).
    await insertVisit('Studio meublé à Lafayette', 'absent', daysFromNow(-29, '14:00'),
        now.subtract(const Duration(days: 31)),
        decidedAt: now.subtract(const Duration(days: 29)));

    // Confirmée dans 3 jours.
    await insertVisit('S+2 récent à Ennasr', 'confirmed', daysFromNow(3, '17:00'),
        now.subtract(const Duration(days: 2)),
        decidedAt: now.subtract(const Duration(days: 1)),
        note: 'Si possible en fin de journée.');
    await db.insert('notifications', {
      'userId': client,
      'type': AppNotification.visitConfirmed,
      'title': 'Visite confirmée',
      'body': 'Votre visite de « S+2 récent à Ennasr » est confirmée.',
      'listingId': null,
      'isRead': 0,
      'createdAt': at(now.subtract(const Duration(days: 1))),
    });

    // Demandée pour demain, en attente de réponse de l'agence.
    await insertVisit('Bel S+2 lumineux aux Berges du Lac 2', 'requested',
        daysFromNow(1, '09:00'), now.subtract(const Duration(hours: 3)),
        note: 'Je suis disponible plus tôt si besoin.');

    // Journée chargée dans 2 jours : trois visites pour le calendrier pro.
    await insertVisit('S+3 spacieux à L’Aouina', 'confirmed', daysFromNow(2, '10:00'),
        now.subtract(const Duration(days: 1)), decidedAt: now.subtract(const Duration(hours: 2)));
    await insertVisit('Maison familiale avec jardin à El Menzah 6', 'requested',
        daysFromNow(2, '11:00'), now.subtract(const Duration(hours: 5)),
        note: 'Je suis disponible toute la matinée.');
    await insertVisit('Villa d’exception avec piscine à La Marsa', 'confirmed',
        daysFromNow(2, '15:30'), now.subtract(const Duration(days: 2)),
        decidedAt: now.subtract(const Duration(days: 1)));
  }
}
