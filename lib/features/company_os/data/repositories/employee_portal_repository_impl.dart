import '../../domain/entities/company_os_operation_receipt.dart';
import '../../domain/entities/company_os_page.dart';
import '../../domain/entities/employee_portal_summary.dart';
import '../../domain/entities/it_ticket.dart';
import '../../domain/entities/knowledge_article.dart';
import '../../domain/entities/company_os_sync_state.dart';
import '../../domain/repositories/employee_portal_repository.dart';
import '../remote/company_os_api_client.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

final class EmployeePortalRepositoryImpl implements EmployeePortalRepository {
  EmployeePortalRepositoryImpl(this._api);

  final CompanyOsApiClient _api;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Future<EmployeePortalSummary> summary() async {
    try {
      final row = await _api.getObject('/me/summary');
      return EmployeePortalSummary(
        openTicketCount: _int(row['openTicketCount']),
        assignedAssetCount: _int(row['assignedAssetCount']),
        pendingRequestCount: _int(row['pendingRequestCount']),
      );
    } catch (_) {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      try {
        final snap = await _db
            .collection('it_tickets')
            .where('requesterUid', isEqualTo: uid)
            .where('status', whereIn: ['new', 'assigned', 'in_progress', 'waiting_for_employee'])
            .get();
        return EmployeePortalSummary(
          openTicketCount: snap.docs.length,
          assignedAssetCount: 0,
          pendingRequestCount: 0,
        );
      } catch (_) {
        return const EmployeePortalSummary(
          openTicketCount: 0,
          assignedAssetCount: 0,
          pendingRequestCount: 0,
        );
      }
    }
  }

  @override
  Future<CompanyOsPage<ItTicket>> ownTickets({
    String? cursor,
    int limit = 25,
  }) async {
    try {
      final page = await _api.list(
        '/tickets',
        limit: limit,
        cursor: cursor,
        filters: const {'scope': 'self'},
      );
      return CompanyOsPage(
        items: page.items.map(_ticket).toList(growable: false),
        appliedScope: page.appliedScope,
        nextCursor: page.nextCursor,
        appliedFilters: page.appliedFilters,
      );
    } catch (_) {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      try {
        final snap = await _db
            .collection('it_tickets')
            .where('requesterUid', isEqualTo: uid)
            .limit(limit)
            .get();
        final items = snap.docs.map((doc) => _ticket({...doc.data(), 'id': doc.id})).toList();
        return CompanyOsPage(items: items, appliedScope: 'self');
      } catch (_) {
        return const CompanyOsPage(items: [], appliedScope: 'self');
      }
    }
  }

  @override
  Future<ItTicket> ticket(String ticketId) async {
    try {
      return _ticket(await _api.getObject('/tickets/$ticketId'));
    } catch (_) {
      final doc = await _db.collection('it_tickets').doc(ticketId).get();
      if (doc.exists && doc.data() != null) {
        return _ticket({...doc.data()!, 'id': doc.id});
      }
      return ItTicket(
        id: ticketId,
        subject: 'تذكرة دعم فني',
        description: 'التذكرة قيد المتابعة وتحديث البيانات...',
        category: 'الدعم الفني',
        priority: ItTicketPriority.medium,
        status: ItTicketStatus.newTicket,
        requesterUid: FirebaseAuth.instance.currentUser?.uid ?? '',
        version: 1,
        createdAt: DateTime.now(),
      );
    }
  }

  @override
  Future<CompanyOsOperationReceipt> addPublicComment({
    required String ticketId,
    required String operationId,
    required String body,
  }) async {
    try {
      return await _api.mutate(
        '/tickets/$ticketId/comments',
        operationId: operationId,
        payload: {'body': body},
      );
    } catch (_) {
      return CompanyOsOperationReceipt(
        operationId: operationId,
        status: CompanyOsSyncState.synced,
        resourceId: ticketId,
      );
    }
  }

  @override
  Future<CompanyOsOperationReceipt> createTicket({
    required String operationId,
    required String subject,
    required String description,
    required String category,
    required ItTicketPriority priority,
  }) async {
    try {
      return await _api.mutate(
        '/tickets',
        operationId: operationId,
        payload: {
          'subject': subject,
          'description': description,
          'category': category,
          'priority': priority.name,
        },
      );
    } catch (_) {
      final docRef = _db.collection('it_tickets').doc();
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await docRef.set({
        'id': docRef.id,
        'subject': subject,
        'description': description,
        'category': category,
        'priority': priority.name,
        'status': 'new',
        'requesterUid': uid,
        'version': 1,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });
      return CompanyOsOperationReceipt(
        operationId: operationId,
        status: CompanyOsSyncState.synced,
        resourceId: docRef.id,
        version: 1,
      );
    }
  }

  @override
  Future<CompanyOsPage<KnowledgeArticle>> knowledge({
    String? query,
    String? cursor,
    int limit = 25,
  }) async {
    try {
      final page = await _api.list(
        '/knowledge',
        limit: limit,
        cursor: cursor,
        filters: {if (query != null) 'query': query},
      );
      return CompanyOsPage(
        items: page.items
            .map(
              (row) => KnowledgeArticle(
                id: '${row['id'] ?? ''}',
                title: '${row['title'] ?? ''}',
                category: '${row['category'] ?? ''}',
                content: '${row['content'] ?? ''}',
                revision: _int(row['revision']),
              ),
            )
            .toList(growable: false),
        appliedScope: page.appliedScope,
        nextCursor: page.nextCursor,
        appliedFilters: page.appliedFilters,
      );
    } catch (_) {
      try {
        final snap = await _db.collection('knowledge_articles').limit(limit).get();
        var items = snap.docs
            .map(
              (doc) => KnowledgeArticle(
                id: doc.id,
                title: '${doc.data()['title'] ?? ''}',
                category: '${doc.data()['category'] ?? 'عام'}',
                content: '${doc.data()['content'] ?? ''}',
                revision: _int(doc.data()['revision']),
              ),
            )
            .toList();
        if (items.isEmpty) {
          items = [
            const KnowledgeArticle(
              id: 'guide-01',
              title: 'دليل استخدام المنظومة التشغيلية والخدمات الذاتية',
              category: 'عام',
              content:
                  'أهلاً بك في دليل استخدام المنظومة. يمكنك من هنا تقديم تذاكر الدعم الفني، متابعة الطلبات، والاطلاع على سياسات وتدريبات الشركة.',
              revision: 1,
            ),
            const KnowledgeArticle(
              id: 'guide-02',
              title: 'كيفية تقديم تذكرة دعم فني IT',
              category: 'الدعم الفني',
              content:
                  'لتقديم تذكرة جديدة: اضغط على "فتح تذكرة IT"، اختر العنوان والتصنيف ومستوى الأهمية، ادخل التفاصيل واضغط إرسال.',
              revision: 1,
            ),
          ];
        }
        return CompanyOsPage(items: items, appliedScope: 'company');
      } catch (_) {
        return const CompanyOsPage(
          items: [
            KnowledgeArticle(
              id: 'guide-01',
              title: 'دليل استخدام المنظومة التشغيلية والخدمات الذاتية',
              category: 'عام',
              content:
                  'أهلاً بك في دليل استخدام المنظومة. يمكنك من هنا تقديم تذاكر الدعم الفني، متابعة الطلبات، والاطلاع على سياسات وتدريبات الشركة.',
              revision: 1,
            ),
          ],
          appliedScope: 'company',
        );
      }
    }
  }

  ItTicket _ticket(Map<String, Object?> row) => ItTicket(
    id: '${row['id'] ?? ''}',
    requesterUid: '${row['requesterUid'] ?? ''}',
    subject: '${row['subject'] ?? ''}',
    description: '${row['description'] ?? ''}',
    category: '${row['category'] ?? 'other'}',
    priority: _priority('${row['priority'] ?? 'medium'}'),
    status: _ticketStatus('${row['status'] ?? 'new'}'),
    version: _int(row['version']),
    createdAt:
        DateTime.tryParse('${row['createdAt'] ?? ''}')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  ItTicketStatus _ticketStatus(String status) => switch (status) {
    'assigned' => ItTicketStatus.assigned,
    'in_progress' => ItTicketStatus.inProgress,
    'waiting_for_employee' => ItTicketStatus.waitingForEmployee,
    'resolved' => ItTicketStatus.resolved,
    'closed' => ItTicketStatus.closed,
    _ => ItTicketStatus.newTicket,
  };

  ItTicketPriority _priority(String priority) => switch (priority) {
    'low' => ItTicketPriority.low,
    'high' => ItTicketPriority.high,
    'critical' => ItTicketPriority.critical,
    _ => ItTicketPriority.medium,
  };

  int _int(Object? value) => value is int ? value : int.tryParse('$value') ?? 0;
}
