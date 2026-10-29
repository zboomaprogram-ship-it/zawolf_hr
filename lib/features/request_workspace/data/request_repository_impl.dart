import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/safe_presentation_message.dart';
import '../../request_visibility/domain/entities/request_view_query.dart';
import '../../request_visibility/domain/entities/request_visibility_record.dart';
import '../../request_visibility/domain/repositories/request_visibility_repository.dart';
import '../domain/entities/request_record.dart';
import '../domain/repositories/request_repository.dart';

/// Production implementation of [RequestRepository] (Task C014).
///
/// Bounded reads: bridges onto [RequestVisibilityRepository] for query boundaries
/// and handles deterministic updates for approvals/rejections without unbounded scans.
final class RequestRepositoryImpl implements RequestRepository {
  RequestRepositoryImpl({
    required RequestVisibilityRepository visibilityRepository,
    FirebaseFirestore? firestore,
  })  : _visibilityRepository = visibilityRepository,
        _db = firestore ?? FirebaseFirestore.instance;

  final RequestVisibilityRepository _visibilityRepository;
  final FirebaseFirestore _db;

  @override
  Future<RequestListResult> getPendingQueue({
    required String actorId,
    required String companyId,
    String? cursor,
    int limit = 20,
  }) async {
    final now = DateTime.now();
    final query = RequestViewQuery(
      actorScope: RequestActorScope(
        actorId: actorId,
        role: 'manager',
      ),
      tab: RequestViewTab.active,
      fromDate: now.subtract(const Duration(days: 365)),
      toDate: now.add(const Duration(days: 30)),
      pageCursor: cursor,
      pageSize: limit,
    );
    return _fetchFromVisibility(query, isActionable: true);
  }

  @override
  Future<RequestListResult> getBrowseRequests({
    required String actorId,
    required String companyId,
    RequestWorkspaceFilter? filter,
    String? cursor,
    int limit = 20,
  }) async {
    final now = DateTime.now();
    final query = RequestViewQuery(
      actorScope: RequestActorScope(
        actorId: actorId,
        role: 'hr',
      ),
      tab: RequestViewTab.all,
      fromDate: filter?.fromDate ?? now.subtract(const Duration(days: 365)),
      toDate: filter?.toDate ?? now.add(const Duration(days: 30)),
      searchTerm: filter?.searchTerm ?? '',
      pageCursor: cursor,
      pageSize: limit,
    );
    return _fetchFromVisibility(query, isActionable: false);
  }

  @override
  Future<RequestListResult> getMyHistory({
    required String actorId,
    required String companyId,
    String? cursor,
    int limit = 20,
  }) async {
    final now = DateTime.now();
    final query = RequestViewQuery(
      actorScope: RequestActorScope(
        actorId: actorId,
        role: 'employee',
      ),
      tab: RequestViewTab.history,
      fromDate: now.subtract(const Duration(days: 730)),
      toDate: now.add(const Duration(days: 30)),
      employeeScopeIds: [actorId],
      pageCursor: cursor,
      pageSize: limit,
    );
    return _fetchFromVisibility(query, isActionable: false);
  }

  @override
  Future<RequestDetailResult> getDetail({
    required String collection,
    required String requestId,
  }) async {
    try {
      final doc = await _db.collection(collection).doc(requestId).get();
      if (!doc.exists) {
        return const RequestDetailNotFound();
      }
      final data = doc.data() ?? <String, dynamic>{};
      final record = _mapDetailRecord(doc.id, collection, data);
      return RequestDetailLoaded(record);
    } catch (e) {
      return RequestDetailFailure(
        safeArabicBusinessMessage(e) ?? 'تعذر تحميل تفاصيل الطلب. أعد المحاولة.',
      );
    }
  }

  @override
  Future<RequestActionResult> approveRequest({
    required String collection,
    required String requestId,
    required String actorId,
    String? note,
  }) async {
    return _updateStatus(
      collection: collection,
      requestId: requestId,
      actorId: actorId,
      newStatus: 'approved',
      note: note,
      successMessage: 'تم اعتماد الطلب بنجاح',
    );
  }

  @override
  Future<RequestActionResult> rejectRequest({
    required String collection,
    required String requestId,
    required String actorId,
    required String note,
  }) async {
    return _updateStatus(
      collection: collection,
      requestId: requestId,
      actorId: actorId,
      newStatus: 'rejected',
      note: note,
      successMessage: 'تم رفض الطلب',
    );
  }

  @override
  Future<RequestActionResult> cancelRequest({
    required String collection,
    required String requestId,
    required String actorId,
    String? reason,
  }) async {
    return _updateStatus(
      collection: collection,
      requestId: requestId,
      actorId: actorId,
      newStatus: 'cancelled',
      note: reason,
      successMessage: 'تم إلغاء الطلب بنجاح',
    );
  }

  Future<RequestActionResult> _updateStatus({
    required String collection,
    required String requestId,
    required String actorId,
    required String newStatus,
    required String successMessage,
    String? note,
  }) async {
    try {
      final docRef = _db.collection(collection).doc(requestId);
      final updateData = <String, dynamic>{
        'status': newStatus,
        'status_ar': _statusInArabic(newStatus),
        'updatedAt': FieldValue.serverTimestamp(),
        'actionBy': actorId,
        if (note != null && note.trim().isNotEmpty) 'actionNote': note.trim(),
        'history': FieldValue.arrayUnion([
          {
            'action': newStatus,
            'actorId': actorId,
            'timestamp': Timestamp.now(),
            if (note != null) 'note': note.trim(),
          }
        ]),
      };

      await docRef.update(updateData);
      return RequestActionSuccess(message: successMessage);
    } catch (e) {
      return RequestActionFailure(
        safeArabicBusinessMessage(e) ?? 'تعذر تحديث حالة الطلب. تحقق من الصلاحيات ثم أعد المحاولة.',
      );
    }
  }

  Future<RequestListResult> _fetchFromVisibility(
    RequestViewQuery query, {
    required bool isActionable,
  }) async {
    final result = await _visibilityRepository.load(query);
    return switch (result) {
      RequestViewLoaded(:final records, :final nextCursor) => RequestListLoaded(
          records: records
              .map((r) => _mapFromVisibility(r, isActionable: isActionable))
              .toList(growable: false),
          nextCursor: nextCursor,
        ),
      RequestViewEmpty() => const RequestListEmpty(),
      RequestViewRetryableFailure(:final safeMessage) =>
        RequestListFailure(safeMessage),
      RequestViewAccessDenied(:final safeMessage) =>
        RequestListFailure(safeMessage),
    };
  }

  RequestRecord _mapFromVisibility(
    RequestVisibilityRecord vis, {
    required bool isActionable,
  }) {
    return RequestRecord(
      id: vis.documentId,
      collection: vis.collection,
      category: _categoryFromSource(vis.sourceType),
      status: _statusFromLifecycle(vis.lifecycleState),
      stage: _stageFromApproval(vis.approvalStage),
      requesterId: vis.employeeId,
      createdAt: vis.occurredAt,
      requesterName: vis.employeeName,
      requesterCode: vis.employeeCode,
      summary: vis.reason,
      isActionableByMe: isActionable,
    );
  }

  RequestRecord _mapDetailRecord(
    String docId,
    String collection,
    Map<String, dynamic> data,
  ) {
    final createdAt = _parseTimestamp(data['createdAt']) ??
        _parseTimestamp(data['timestamp']) ??
        _parseTimestamp(data['date']) ??
        DateTime.now();

    final statusStr = (data['status'] as String? ?? 'pending').toLowerCase();
    final status = switch (statusStr) {
      'approved' => RequestWorkspaceStatus.approved,
      'rejected' => RequestWorkspaceStatus.rejected,
      'cancelled' => RequestWorkspaceStatus.cancelled,
      'confirmed' => RequestWorkspaceStatus.confirmed,
      _ => RequestWorkspaceStatus.pending,
    };

    final rawHistory = data['history'] as List? ?? const [];
    final historyEvents = <RequestTimelineEvent>[
      RequestTimelineEvent(
        title: 'تقديم الطلب',
        timestamp: createdAt,
        actorName: data['employeeName'] as String?,
      ),
      for (final event in rawHistory)
        if (event is Map)
          RequestTimelineEvent(
            title: _actionTitleInArabic(event['action'] as String? ?? ''),
            timestamp: _parseTimestamp(event['timestamp']) ?? DateTime.now(),
            actorName: event['actorId'] as String?,
            note: event['note'] as String?,
          ),
    ];

    return RequestRecord(
      id: docId,
      collection: collection,
      category: _categoryFromCollection(collection),
      status: status,
      stage: RequestWorkflowStage.manager,
      requesterId: data['employeeId'] as String? ?? '',
      createdAt: createdAt,
      requesterName: data['employeeName'] as String?,
      requesterCode: data['employeeCode'] as String?,
      department: data['department'] as String?,
      summary: data['reason'] as String? ?? data['details'] as String?,
      details: data,
      isActionableByMe: status == RequestWorkspaceStatus.pending,
      historyEvents: historyEvents,
    );
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  RequestWorkspaceCategory _categoryFromSource(RequestSourceType source) =>
      switch (source) {
        RequestSourceType.leave => RequestWorkspaceCategory.leave,
        RequestSourceType.permission => RequestWorkspaceCategory.permission,
        RequestSourceType.attendanceCorrection =>
          RequestWorkspaceCategory.attendanceCorrection,
        RequestSourceType.salaryDeduction =>
          RequestWorkspaceCategory.salaryDeduction,
        RequestSourceType.lateArrivalDeduction =>
          RequestWorkspaceCategory.lateArrivalDeduction,
        RequestSourceType.advance => RequestWorkspaceCategory.advance,
        RequestSourceType.administrative =>
          RequestWorkspaceCategory.administrative,
        RequestSourceType.custom => RequestWorkspaceCategory.custom,
        RequestSourceType.meeting => RequestWorkspaceCategory.meeting,
        RequestSourceType.complaint => RequestWorkspaceCategory.complaint,
        RequestSourceType.resignation => RequestWorkspaceCategory.resignation,
        RequestSourceType.employeeDeletion =>
          RequestWorkspaceCategory.employeeDeletion,
        _ => RequestWorkspaceCategory.unknown,
      };

  RequestWorkspaceCategory _categoryFromCollection(String collection) =>
      switch (collection) {
        'leaves' => RequestWorkspaceCategory.leave,
        'permissions' => RequestWorkspaceCategory.permission,
        'attendanceCorrectionRequests' =>
          RequestWorkspaceCategory.attendanceCorrection,
        'manual_deductions' => RequestWorkspaceCategory.salaryDeduction,
        'advances' => RequestWorkspaceCategory.advance,
        'administrativeRequests' => RequestWorkspaceCategory.administrative,
        'customRequests' => RequestWorkspaceCategory.custom,
        'meetingRequests' => RequestWorkspaceCategory.meeting,
        'complaints' => RequestWorkspaceCategory.complaint,
        'resignations' => RequestWorkspaceCategory.resignation,
        'employeeDeletionRequests' => RequestWorkspaceCategory.employeeDeletion,
        _ => RequestWorkspaceCategory.unknown,
      };

  RequestWorkspaceStatus _statusFromLifecycle(RequestLifecycleState state) =>
      switch (state) {
        RequestLifecycleState.pending => RequestWorkspaceStatus.pending,
        RequestLifecycleState.approved => RequestWorkspaceStatus.approved,
        RequestLifecycleState.rejected => RequestWorkspaceStatus.rejected,
        RequestLifecycleState.cancelled => RequestWorkspaceStatus.cancelled,
        RequestLifecycleState.confirmed => RequestWorkspaceStatus.confirmed,
        _ => RequestWorkspaceStatus.unknown,
      };

  RequestWorkflowStage _stageFromApproval(RequestApprovalStage stage) =>
      switch (stage) {
        RequestApprovalStage.manager => RequestWorkflowStage.manager,
        RequestApprovalStage.hr => RequestWorkflowStage.hr,
        RequestApprovalStage.ceo => RequestWorkflowStage.ceo,
        RequestApprovalStage.finalised => RequestWorkflowStage.completed,
        _ => RequestWorkflowStage.unknown,
      };

  String _statusInArabic(String status) => switch (status) {
        'approved' => 'معتمد',
        'rejected' => 'مرفوض',
        'cancelled' => 'ملغي',
        'confirmed' => 'مؤكد',
        _ => 'قيد الانتظار',
      };

  String _actionTitleInArabic(String action) => switch (action) {
        'approved' => 'اعتماد الطلب',
        'rejected' => 'رفض الطلب',
        'cancelled' => 'إلغاء الطلب',
        _ => 'تحديث الحالة',
      };
}
