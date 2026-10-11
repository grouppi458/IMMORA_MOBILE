import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'package:immora_mobile/core/database/database_helper.dart';
import 'package:immora_mobile/core/errors/app_exception.dart';
import 'package:immora_mobile/core/utils/constants.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/module_gestion_annonces/models/app_notification.dart';
import 'package:immora_mobile/module_gestion_visites/models/visit.dart';
import 'package:immora_mobile/module_gestion_visites/models/visit_details.dart';

/// Demandes de visite (Module 6). Les règles métier lèvent une
/// [AdminException] affichée telle quelle.
class VisitRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  /// Statuts « en cours » : une seule visite ouverte par client et par bien.
  static const _openStatuses = ['requested', 'confirmed'];

  static const selectDetails = '''
    SELECT v.*,
      COALESCE(l.title, '') AS listingTitle,
      p.title AS propertyTitle, p.type AS propertyType, p.dealType AS propertyDealType,
      p.price AS propertyPrice, p.rooms AS propertyRooms,
      p.city AS propertyCity, p.district AS propertyDistrict,
      p.latitude AS propertyLat, p.longitude AS propertyLng,
      a.name AS agencyName,
      uc.fullName AS clientName, uc.phone AS clientPhone,
      ua.fullName AS agentName
    FROM visits v
    JOIN properties p ON p.id = v.propertyId
    LEFT JOIN listings l ON l.id = v.listingId
    JOIN agencies a ON a.id = v.agencyId
    JOIN users uc ON uc.id = v.clientId
    LEFT JOIN agents ag ON ag.id = v.agentId
    LEFT JOIN users ua ON ua.id = ag.userId''';

  static VisitDetails detailsFromRow(Map<String, dynamic> m) => VisitDetails(
        visit: Visit.fromMap(m),
        listingTitle: m['listingTitle'] ?? '',
        propertyTitle: m['propertyTitle'] ?? '',
        propertyType: PropertyType.values.byName(m['propertyType']),
        dealType: DealType.values.byName(m['propertyDealType']),
        price: (m['propertyPrice'] as num?)?.toDouble() ?? 0,
        rooms: (m['propertyRooms'] as num?)?.toInt() ?? 0,
        city: m['propertyCity'] ?? '',
        district: m['propertyDistrict'] ?? '',
        latitude: (m['propertyLat'] as num?)?.toDouble(),
        longitude: (m['propertyLng'] as num?)?.toDouble(),
        agencyName: m['agencyName'] ?? '',
        clientName: m['clientName'] ?? '',
        clientPhone: m['clientPhone'],
        agentName: m['agentName'],
      );

  // ---------------------------------------------------------------- Demande

  /// Le client demande la visite d'une annonce publiée à [scheduledAt]
  /// (date + créneau). Le bien doit être disponible et n'avoir aucune autre
  /// visite en cours pour ce client. Renvoie l'identifiant de la visite.
  Future<int> request({
    required int clientId,
    required int listingId,
    required DateTime scheduledAt,
    String? note,
  }) async {
    final when = scheduledAt.millisecondsSinceEpoch;
    _validateSlot(scheduledAt);
    final n = note?.trim();
    final noteValue = n == null || n.isEmpty ? null : n;
    if (noteValue != null && noteValue.length > visitNoteMaxLength) {
      throw AdminException('Le message ne peut pas dépasser $visitNoteMaxLength caractères.',
          field: 'note');
    }
    final db = await _db;
    final listing = await _listing(db, listingId);
    if (listing == null) throw AdminException('Annonce introuvable.');
    if (listing['status'] != ListingStatus.published.name) {
      throw AdminException('Cette annonce n’est plus en ligne.');
    }
    final propertyId = listing['propertyId'] as int;
    await _ensurePropertyAvailable(db, propertyId);
    final alreadyOpen = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM visits WHERE clientId = ? AND propertyId = ? '
          'AND status IN (?, ?)',
          [clientId, propertyId, ..._openStatuses],
        )) ??
        0;
    if (alreadyOpen > 0) {
      throw AdminException('Vous avez déjà une visite en cours pour ce bien.');
    }

    final agentId = await _agentOfProperty(db, propertyId);
    await _ensureAgentFree(db, agentId: agentId, when: when);

    final now = DateTime.now().millisecondsSinceEpoch;
    return db.insert('visits', {
      'propertyId': propertyId,
      'listingId': listingId,
      'agencyId': listing['agencyId'],
      'clientId': clientId,
      'agentId': agentId,
      'status': VisitStatus.requested.name,
      'scheduledAt': when,
      'clientNote': noteValue,
      'createdAt': now,
      'updatedAt': now,
    });
  }

  /// Créneaux (minutes depuis minuit) déjà pris par l'agent du bien ce
  /// jour-là (visites en cours uniquement) : le formulaire de demande les
  /// désactive (maquette Figma « Demander une visite »).
  Future<Set<int>> slotsTaken({required int listingId, required DateTime day}) async {
    final db = await _db;
    final listing = await _listing(db, listingId);
    if (listing == null) return const {};
    final agentId = await _agentOfProperty(db, listing['propertyId'] as int);
    if (agentId == null) return const {};
    final start = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final taken = await _takenForAgent(db, agentId, start, start + Duration.millisecondsPerDay);
    return taken
        .map((m) => DateTime.fromMillisecondsSinceEpoch(m))
        .map((d) => d.hour * 60 + d.minute)
        .toSet();
  }

  // ---------------------------------------------------------------- Lecture

  /// Visites d'un client, les plus récentes d'abord.
  Future<List<VisitDetails>> clientVisits(int clientId) async {
    final rows = await (await _db)
        .rawQuery('$selectDetails WHERE v.clientId = ? ORDER BY v.scheduledAt DESC', [clientId]);
    return rows.map(detailsFromRow).toList();
  }

  /// Visites des biens d'un propriétaire (maquette « Visites de mes biens »).
  Future<List<VisitDetails>> ownerVisits(int ownerId) async {
    final rows = await (await _db)
        .rawQuery('$selectDetails WHERE p.ownerId = ? ORDER BY v.scheduledAt DESC', [ownerId]);
    return rows.map(detailsFromRow).toList();
  }

  /// Visites d'une agence. [agentId] non null = uniquement les visites
  /// assignées à cet agent (non assignées exclues). Les plus proches d'abord.
  Future<List<VisitDetails>> agencyVisits(int agencyId, {int? agentId, VisitStatus? status}) async {
    final where = ['v.agencyId = ?'];
    final args = <Object>[agencyId];
    if (agentId != null) {
      where.add('v.agentId = ?');
      args.add(agentId);
    }
    if (status != null) {
      where.add('v.status = ?');
      args.add(status.name);
    }
    final rows = await (await _db).rawQuery(
      '$selectDetails WHERE ${where.join(' AND ')} ORDER BY v.scheduledAt DESC',
      args,
    );
    return rows.map(detailsFromRow).toList();
  }

  /// Nombre de demandes en attente (pastille côté pro).
  Future<int> pendingCount(int agencyId, {int? agentId}) async =>
      Sqflite.firstIntValue(await (await _db).rawQuery(
            'SELECT COUNT(*) FROM visits WHERE agencyId = ? AND status = ?'
            '${agentId == null ? '' : ' AND agentId = ?'}',
            [agencyId, VisitStatus.requested.name, ?agentId],
          )) ??
      0;

  /// Identifiant agents.id d'un compte agent, null si ce n'est pas un agent.
  Future<int?> agentIdForUser(int userId) async {
    final rows = await (await _db)
        .query('agents', columns: ['id'], where: 'userId = ?', whereArgs: [userId], limit: 1);
    return rows.isEmpty ? null : rows.first['id'] as int;
  }

  // ---------------------------------------------------------------- Décisions

  /// Confirme une visite demandée ; [newSlot] la reprogramme en même temps.
  Future<void> confirm(int id, {DateTime? newSlot}) async {
    final db = await _db;
    final visit = await _get(db, id);
    if (visit.visit.status != VisitStatus.requested) {
      throw AdminException('Seule une visite « demandée » peut être confirmée.');
    }
    if (newSlot != null) _validateSlot(newSlot);
    final now = DateTime.now().millisecondsSinceEpoch;
    final scheduledAt = newSlot?.millisecondsSinceEpoch ?? visit.visit.scheduledAt;
    await _ensureAgentFree(db,
        agentId: visit.visit.agentId, when: scheduledAt, excludeVisitId: id);
    await _save(db, id, {
      'status': VisitStatus.confirmed.name,
      'scheduledAt': scheduledAt,
      'decidedAt': now,
    });
    await _notifyClient(db, visit, AppNotification.visitConfirmed, 'Visite confirmée',
        'Votre visite de « ${visit.displayTitle} » est confirmée pour le '
            '${formatDate(scheduledAt)} à ${formatTime(scheduledAt)}.');
  }

  /// Reprogramme une visite déjà confirmée (le créneau demandé n'est plus
  /// possible). Le client est notifié du nouveau rendez-vous.
  Future<void> reschedule(int id, DateTime newSlot) async {
    final db = await _db;
    final visit = await _get(db, id);
    if (visit.visit.status != VisitStatus.confirmed) {
      throw AdminException('Seule une visite « confirmée » peut être reprogrammée.');
    }
    _validateSlot(newSlot);
    final scheduledAt = newSlot.millisecondsSinceEpoch;
    await _ensureAgentFree(db,
        agentId: visit.visit.agentId, when: scheduledAt, excludeVisitId: id);
    await _save(db, id, {
      'scheduledAt': scheduledAt,
      'decidedAt': DateTime.now().millisecondsSinceEpoch,
    });
    await _notifyClient(db, visit, AppNotification.visitConfirmed, 'Visite reprogrammée',
        'Votre visite de « ${visit.displayTitle} » est reportée au '
            '${formatDate(scheduledAt)} à ${formatTime(scheduledAt)}.');
  }

  /// Marque une visite demandée ou confirmée comme effectuée.
  Future<void> markDone(int id) async {
    final db = await _db;
    final visit = await _get(db, id);
    if (!visit.visit.isOpen) {
      throw AdminException('Cette visite est déjà ${visit.visit.status.label.toLowerCase()}.');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await _save(db, id, {
      'status': VisitStatus.done.name,
      'decidedAt': visit.visit.decidedAt ?? now,
      'doneAt': now,
    });
    await _notifyClient(db, visit, AppNotification.visitDone, 'Visite effectuée',
        '« ${visit.displayTitle} » : merci d’avoir visité avec ${visit.agencyName}.');
  }

  /// Marque une visite confirmée « absente » : le client ne s'est pas présenté
  /// (no-show), l'agence le signale.
  Future<void> markAbsent(int id) async {
    final db = await _db;
    final visit = await _get(db, id);
    if (visit.visit.status != VisitStatus.confirmed) {
      throw AdminException('Seule une visite « confirmée » peut être marquée absente.');
    }
    await _save(db, id, {
      'status': VisitStatus.absent.name,
      'decidedAt': DateTime.now().millisecondsSinceEpoch,
    });
    await _notifyClient(db, visit, AppNotification.visitAbsent, 'Visite manquée',
        'Vous n’étiez pas présent au rendez-vous du ${formatDate(visit.visit.scheduledAt)} '
            'à ${formatTime(visit.visit.scheduledAt)}.');
  }

  /// Le client note une visite effectuée (1–5 étoiles + commentaire libre).
  Future<void> rate(int id, {required int rating, String? comment}) async {
    final db = await _db;
    final visit = await _get(db, id);
    if (visit.visit.status != VisitStatus.done) {
      throw AdminException('Seule une visite effectuée peut être notée.');
    }
    if (rating < visitRatingMin || rating > visitRatingMax) {
      throw AdminException(
          'Choisissez une note entre $visitRatingMin et $visitRatingMax étoiles.',
          field: 'rating');
    }
    final c = comment?.trim();
    final commentValue = c == null || c.isEmpty ? null : c;
    if (commentValue != null && commentValue.length > visitNoteMaxLength) {
      throw AdminException('Le commentaire ne peut pas dépasser $visitNoteMaxLength caractères.',
          field: 'comment');
    }
    await _save(db, id, {'rating': rating, 'ratingComment': commentValue});
  }

  /// Compte rendu de l'agent (note interne côté pro).
  Future<void> saveAgentNote(int id, String? note) async {
    final db = await _db;
    await _get(db, id);
    final n = note?.trim();
    final value = n == null || n.isEmpty ? null : n;
    if (value != null && value.length > visitNoteMaxLength) {
      throw AdminException('La note ne peut pas dépasser $visitNoteMaxLength caractères.',
          field: 'note');
    }
    await _save(db, id, {'agentNote': value});
  }

  /// Annule une visite en cours. [notifyClient] false quand c'est le client
  /// lui-même qui annule.
  Future<void> cancel(int id, {required String reason, bool notifyClient = true}) async {
    final db = await _db;
    final visit = await _get(db, id);
    if (!visit.visit.isOpen) {
      throw AdminException('Cette visite est déjà ${visit.visit.status.label.toLowerCase()}.');
    }
    final r = reason.trim();
    if (r.isEmpty) throw AdminException('Indiquez un motif d’annulation.', field: 'reason');
    final now = DateTime.now().millisecondsSinceEpoch;
    await _save(db, id, {
      'status': VisitStatus.cancelled.name,
      'decidedAt': now,
      'cancelReason': r,
    });
    if (notifyClient) {
      await _notifyClient(db, visit, AppNotification.visitCancelled, 'Visite annulée',
          'Votre visite de « ${visit.displayTitle} » a été annulée ($r). '
              'Proposez un autre créneau à ${visit.agencyName}.');
    }
  }

  // ---------------------------------------------------------------- Interne

  void _validateSlot(DateTime slot) {
    if (!slot.isAfter(DateTime.now())) {
      throw AdminException('Choisissez une date et un horaire à venir.', field: 'slot');
    }
  }

  Future<Map<String, Object?>?> _listing(Database db, int id) async {
    final rows =
        await db.query('listings', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> _ensurePropertyAvailable(Database db, int propertyId) async {
    final rows = await db
        .query('properties', columns: ['status'], where: 'id = ?', whereArgs: [propertyId]);
    if (rows.isEmpty || rows.first['status'] != PropertyStatus.available.name) {
      throw AdminException('Le bien n’est plus disponible.');
    }
  }

  Future<int?> _agentOfProperty(Database db, int propertyId) async {
    final rows = await db
        .query('properties', columns: ['agentId'], where: 'id = ?', whereArgs: [propertyId]);
    return rows.isEmpty ? null : rows.first['agentId'] as int?;
  }

  /// Un agent ne peut pas avoir deux visites en cours au même créneau
  /// (maquette « Demander une visite » : créneaux pris désactivés).
  Future<void> _ensureAgentFree(Database db,
      {int? agentId, required int when, int? excludeVisitId}) async {
    if (agentId == null) return;
    final taken = await _takenForAgent(db, agentId, when, when + 1, excludeVisitId);
    if (taken.isNotEmpty) {
      throw AdminException(
          'Ce créneau n’est plus disponible : un agent ne peut pas avoir deux visites '
          'au même moment.',
          field: 'slot');
    }
  }

  /// Créneaux (millis) déjà occupés par l'agent entre [start] (inclus) et
  /// [end] (exclu), visites en cours uniquement.
  Future<Set<int>> _takenForAgent(Database db, int agentId, int start, int end,
      [int? excludeVisitId]) async {
    final rows = await db.rawQuery(
      'SELECT scheduledAt FROM visits WHERE agentId = ? AND status IN (?, ?) '
      'AND scheduledAt >= ? AND scheduledAt < ?'
      '${excludeVisitId == null ? '' : ' AND id <> ?'}',
      [agentId, ..._openStatuses, start, end, ?excludeVisitId],
    );
    return rows.map((r) => r['scheduledAt'] as int).toSet();
  }

  Future<VisitDetails> _get(Database db, int id) async {
    final rows = await db.rawQuery('$selectDetails WHERE v.id = ?', [id]);
    if (rows.isEmpty) throw AdminException('Visite introuvable.');
    return detailsFromRow(rows.first);
  }

  Future<void> _save(Database db, int id, Map<String, Object?> values) => db.update(
      'visits', {...values, 'updatedAt': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?', whereArgs: [id]);

  Future<void> _notifyClient(
      Database db, VisitDetails visit, String type, String title, String body) async {
    try {
      await db.insert('notifications', {
        'userId': visit.visit.clientId,
        'type': type,
        'title': title,
        'body': body,
        'listingId': visit.visit.listingId,
        'isRead': 0,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      // Une notification ne doit jamais bloquer l'action principale.
      debugPrint('VisitRepository: notification non créée ($e)');
    }
  }
}
