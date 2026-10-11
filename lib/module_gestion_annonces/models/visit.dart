import 'package:immora_mobile/core/utils/enums.dart';

/// Demande de visite (table `visits`, M6). Le client la demande depuis une
/// annonce publiée ; l'agence ou l'agent la confirme, la reprogramme, la
/// marque effectuée ou l'annule.
class Visit {
  final int? id;
  final int propertyId; // bien visité (lu par « Pour vous », BF5.8)
  final int? listingId; // annonce d'origine (null si elle a été supprimée)
  final int agencyId;
  final int clientId; // users.id (rôle client)
  final int? agentId; // agents.id, responsable du bien
  final VisitStatus status;
  final int scheduledAt; // date et heure convenues (millis)
  final String? clientNote;
  final int? decidedAt; // confirmation ou annulation
  final int? doneAt;
  final String? cancelReason;
  final int? rating; // 1–5, note du client après la visite
  final String? ratingComment;
  final String? agentNote; // compte rendu de l'agent
  final int createdAt;
  final int updatedAt;

  Visit({
    this.id,
    required this.propertyId,
    this.listingId,
    required this.agencyId,
    required this.clientId,
    this.agentId,
    required this.status,
    required this.scheduledAt,
    this.clientNote,
    this.decidedAt,
    this.doneAt,
    this.cancelReason,
    this.rating,
    this.ratingComment,
    this.agentNote,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOpen => status == VisitStatus.requested || status == VisitStatus.confirmed;
  bool get isRated => rating != null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'propertyId': propertyId,
        'listingId': listingId,
        'agencyId': agencyId,
        'clientId': clientId,
        'agentId': agentId,
        'status': status.name,
        'scheduledAt': scheduledAt,
        'clientNote': clientNote,
        'decidedAt': decidedAt,
        'doneAt': doneAt,
        'cancelReason': cancelReason,
        'rating': rating,
        'ratingComment': ratingComment,
        'agentNote': agentNote,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory Visit.fromMap(Map<String, dynamic> m) => Visit(
        id: m['id'],
        propertyId: m['propertyId'],
        listingId: m['listingId'],
        agencyId: m['agencyId'],
        clientId: m['clientId'],
        agentId: m['agentId'],
        status: VisitStatus.values.byName(m['status']),
        scheduledAt: m['scheduledAt'],
        clientNote: m['clientNote'],
        decidedAt: m['decidedAt'],
        doneAt: m['doneAt'],
        cancelReason: m['cancelReason'],
        rating: m['rating'],
        ratingComment: m['ratingComment'],
        agentNote: m['agentNote'],
        createdAt: m['createdAt'],
        updatedAt: m['updatedAt'],
      );
}
