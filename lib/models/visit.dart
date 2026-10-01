enum VisitStatus { requested, confirmed, cancelled, done, noShow }

class Visit {
  final int? id;
  final int agencyId;
  final int propertyId;
  final int clientId;
  final int? agentId;
  final int scheduledAt;
  final int durationMinutes;
  final VisitStatus status;
  final String? clientMessage;
  final String? agentNote;
  final int? clientRating;
  final int createdAt;
  final int updatedAt;

  Visit({
    this.id,
    required this.agencyId,
    required this.propertyId,
    required this.clientId,
    this.agentId,
    required this.scheduledAt,
    this.durationMinutes = 30,
    this.status = VisitStatus.requested,
    this.clientMessage,
    this.agentNote,
    this.clientRating,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'agencyId': agencyId,
      'propertyId': propertyId,
      'clientId': clientId,
      'agentId': agentId,
      'scheduledAt': scheduledAt,
      'durationMinutes': durationMinutes,
      'status': status.name,
      'clientMessage': clientMessage,
      'agentNote': agentNote,
      'clientRating': clientRating,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Visit.fromMap(Map<String, dynamic> map) {
    return Visit(
      id: map['id'] as int?,
      agencyId: map['agencyId'] as int,
      propertyId: map['propertyId'] as int,
      clientId: map['clientId'] as int,
      agentId: map['agentId'] as int?,
      scheduledAt: map['scheduledAt'] as int,
      durationMinutes: map['durationMinutes'] as int? ?? 30,
      status: VisitStatus.values.byName(
        map['status'] as String? ?? 'requested',
      ),
      clientMessage: map['clientMessage'] as String?,
      agentNote: map['agentNote'] as String?,
      clientRating: map['clientRating'] as int?,
      createdAt: map['createdAt'] as int,
      updatedAt: map['updatedAt'] as int,
    );
  }

  Visit copyWith({
    int? id,
    int? agencyId,
    int? propertyId,
    int? clientId,
    int? agentId,
    int? scheduledAt,
    int? durationMinutes,
    VisitStatus? status,
    String? clientMessage,
    String? agentNote,
    int? clientRating,
    int? createdAt,
    int? updatedAt,
  }) {
    return Visit(
      id: id ?? this.id,
      agencyId: agencyId ?? this.agencyId,
      propertyId: propertyId ?? this.propertyId,
      clientId: clientId ?? this.clientId,
      agentId: agentId ?? this.agentId,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      status: status ?? this.status,
      clientMessage: clientMessage ?? this.clientMessage,
      agentNote: agentNote ?? this.agentNote,
      clientRating: clientRating ?? this.clientRating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
