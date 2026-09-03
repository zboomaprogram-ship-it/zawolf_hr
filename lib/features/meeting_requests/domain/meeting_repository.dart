class MeetingRoom {
  const MeetingRoom({
    required this.id,
    required this.name,
    this.description = '',
    this.capacity = 0,
    this.isActive = true,
  });
  final String id;
  final String name;
  final String description;
  final int capacity;
  final bool isActive;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeetingRoom &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class MeetingRequest {
  const MeetingRequest({
    required this.id,
    required this.requesterName,
    required this.approverName,
    required this.roomName,
    required this.purpose,
    required this.status,
    required this.startAt,
    required this.endAt,
    this.approvalRoute = const [],
  });

  final String id;
  final String requesterName;
  final String approverName;
  final String roomName;
  final String purpose;
  final String status;
  final DateTime? startAt;
  final DateTime? endAt;
  final List<Map<String, dynamic>> approvalRoute;
}

class MeetingApprover {
  const MeetingApprover({
    required this.id,
    required this.name,
    required this.roleLabel,
  });
  final String id;
  final String name;
  final String roleLabel;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeetingApprover &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

abstract interface class MeetingRepository {
  Future<List<MeetingRoom>> rooms();
  Future<List<MeetingApprover>> approvers();
  Future<bool> isAvailable({
    required String roomId,
    required DateTime start,
    required DateTime end,
  });
  Future<void> create({
    required String managerId,
    required String roomId,
    required DateTime start,
    required DateTime end,
    required String purpose,
  });
  Future<void> saveRoom({
    required String name,
    String description = '',
    int? capacity,
    String? roomId,
    bool isActive = true,
  });
  Future<List<MeetingRequest>> requests({required bool approvalQueue});
  Future<void> decide({
    required String requestId,
    required bool approved,
    String comment = '',
  });
  Future<void> cancel(String requestId);
}
