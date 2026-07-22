import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/employee_role.dart';
import '../models/kpi_model.dart';
import '../models/user_model.dart';
import 'audit_log_service.dart';

class KpiService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<KpiTemplateModel>> watchTemplates({
    bool includeInactive = false,
  }) {
    Query<Map<String, dynamic>> query = _db.collection('kpiTemplates');
    if (!includeInactive) {
      query = query.where('isActive', isEqualTo: true);
    }
    return query.snapshots().map((snapshot) {
      final templates = snapshot.docs
          .map(KpiTemplateModel.fromFirestore)
          .toList();
      templates.sort((a, b) => a.department.compareTo(b.department));
      return templates;
    });
  }

  Stream<List<EmployeeKpiModel>> watchMyKpis(String userId, String monthKey) {
    return _db
        .collection('employeeKpis')
        .where('userId', isEqualTo: userId)
        .where('monthKey', isEqualTo: monthKey)
        .snapshots()
        .map(_employeeKpisFromSnapshot);
  }

  Stream<List<EmployeeKpiModel>> watchManagedKpis(
    UserModel reviewer,
    String monthKey,
  ) {
    if (reviewer.role == EmployeeRole.manager) {
      return _watchMergedKpiQueries([
        _db
            .collection('employeeKpis')
            .where('monthKey', isEqualTo: monthKey)
            .where('managerIds', arrayContains: reviewer.uid),
        _db
            .collection('employeeKpis')
            .where('monthKey', isEqualTo: monthKey)
            .where('managerId', isEqualTo: reviewer.uid),
      ]);
    }
    final query = _db
        .collection('employeeKpis')
        .where('monthKey', isEqualTo: monthKey);
    return query.snapshots().map(_employeeKpisFromSnapshot);
  }

  Future<List<UserModel>> loadAssignableEmployees(UserModel reviewer) async {
    if (reviewer.role == EmployeeRole.manager) {
      final results = await Future.wait([
        _db
            .collection('users')
            .where('managerIds', arrayContains: reviewer.uid)
            .get(),
        _db
            .collection('users')
            .where('managerId', isEqualTo: reviewer.uid)
            .get(),
      ]);
      final byId = <String, UserModel>{};
      for (final doc in results.expand((snapshot) => snapshot.docs)) {
        final user = UserModel.fromFirestore(doc);
        if (!user.isActive) continue;
        if (user.role == EmployeeRole.superAdmin) continue;
        if (user.managerId == reviewer.uid ||
            user.managerIds.contains(reviewer.uid)) {
          byId[user.uid] = user;
        }
      }
      final users = byId.values.toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));
      return users;
    }
    final query = _db.collection('users').where('isActive', isEqualTo: true);
    final snap = await query.get();
    final users = snap.docs.map(UserModel.fromFirestore).where((user) {
      if (user.role == EmployeeRole.superAdmin) return false;
      if (reviewer.role == EmployeeRole.manager) {
        return user.managerId == reviewer.uid ||
            user.managerIds.contains(reviewer.uid);
      }
      return true;
    }).toList();
    users.sort((a, b) => a.displayName.compareTo(b.displayName));
    return users;
  }

  Future<void> createTemplate({
    required UserModel creator,
    required String title,
    required String department,
    String companyLocationId = '',
    String companyName = '',
    required List<KpiMetricTemplate> metrics,
  }) async {
    _validateTemplate(title: title, department: department, metrics: metrics);
    final ref = _db.collection('kpiTemplates').doc();
    final template = KpiTemplateModel(
      templateId: ref.id,
      title: title.trim(),
      department: department.trim(),
      companyLocationId: companyLocationId.trim(),
      companyName: companyName.trim(),
      createdBy: creator.uid,
      createdByName: creator.displayName,
      isActive: true,
      metrics: metrics,
    );
    await ref.set(template.toFirestore());
    await AuditLogService.instance.record(
      actorId: creator.uid,
      action: 'kpi_template_created',
      targetCollection: 'kpiTemplates',
      targetId: ref.id,
      metadata: {
        'department': department,
        'companyLocationId': companyLocationId.trim(),
        'companyName': companyName.trim(),
        'metrics': metrics.length,
      },
    );
  }

  Future<void> updateTemplate({
    required KpiTemplateModel template,
    required UserModel editor,
    required String title,
    required String department,
    String companyLocationId = '',
    String companyName = '',
    required List<KpiMetricTemplate> metrics,
  }) async {
    _validateTemplate(title: title, department: department, metrics: metrics);
    await _db.collection('kpiTemplates').doc(template.templateId).update({
      'title': title.trim(),
      'department': department.trim(),
      'companyLocationId': companyLocationId.trim(),
      'companyName': companyName.trim(),
      'metrics': metrics.map((metric) => metric.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await AuditLogService.instance.record(
      actorId: editor.uid,
      action: 'kpi_template_updated',
      targetCollection: 'kpiTemplates',
      targetId: template.templateId,
      metadata: {
        'department': department.trim(),
        'companyLocationId': companyLocationId.trim(),
        'companyName': companyName.trim(),
        'metrics': metrics.length,
      },
    );
  }

  Future<void> setTemplateActive({
    required KpiTemplateModel template,
    required UserModel editor,
    required bool isActive,
  }) async {
    await _db.collection('kpiTemplates').doc(template.templateId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await AuditLogService.instance.record(
      actorId: editor.uid,
      action: isActive ? 'kpi_template_activated' : 'kpi_template_archived',
      targetCollection: 'kpiTemplates',
      targetId: template.templateId,
    );
  }

  Future<void> deleteTemplate({
    required KpiTemplateModel template,
    required UserModel actor,
  }) async {
    await _db.collection('kpiTemplates').doc(template.templateId).delete();
    try {
      await AuditLogService.instance.record(
        actorId: actor.uid,
        action: 'kpi_template_deleted',
        targetCollection: 'kpiTemplates',
        targetId: template.templateId,
        metadata: {
          'title': template.title,
          'department': template.department,
          'companyName': template.companyName,
        },
      );
    } catch (_) {}
  }

  Future<void> deleteEmployeeKpi({
    required EmployeeKpiModel kpi,
    required UserModel actor,
  }) async {
    await _db.collection('employeeKpis').doc(kpi.employeeKpiId).delete();
    try {
      await AuditLogService.instance.record(
        actorId: actor.uid,
        action: 'employee_kpi_deleted',
        targetCollection: 'employeeKpis',
        targetId: kpi.employeeKpiId,
        metadata: {
          'userId': kpi.userId,
          'employeeName': kpi.employeeName,
          'monthKey': kpi.monthKey,
        },
      );
    } catch (_) {}
  }

  Future<void> assignMonthlyKpi({
    required UserModel creator,
    required UserModel employee,
    required KpiTemplateModel template,
    required String monthKey,
  }) async {
    final docId = '${employee.uid}_$monthKey';
    final ref = _db.collection('employeeKpis').doc(docId);
    final metrics = template.metrics
        .map(
          (metric) => EmployeeKpiMetric(
            name: metric.name,
            unit: metric.unit,
            target: metric.target,
            actual: 0,
            weight: metric.weight,
            direction: metric.direction,
          ),
        )
        .toList();
    final kpi = EmployeeKpiModel(
      employeeKpiId: ref.id,
      templateId: template.templateId,
      userId: employee.uid,
      employeeId: employee.employeeId,
      employeeName: employee.displayName,
      department: employee.department,
      managerId: employee.managerId ?? creator.uid,
      managerIds: employee.managerIds.isNotEmpty
          ? employee.managerIds
          : [employee.managerId ?? creator.uid],
      monthKey: monthKey,
      status: 'active',
      metrics: metrics,
      overallProgress: 0,
      createdBy: creator.uid,
    );

    await _db.runTransaction((transaction) async {
      final existing = await transaction.get(ref);
      if (existing.exists) {
        throw Exception('تم تعيين KPI لهذا الموظف في هذه الدورة بالفعل.');
      }
      transaction.set(ref, kpi.toFirestore());
    });
    await AuditLogService.instance.record(
      actorId: creator.uid,
      action: 'employee_kpi_assigned',
      targetCollection: 'employeeKpis',
      targetId: ref.id,
      metadata: {'userId': employee.uid, 'monthKey': monthKey},
    );

    try {
      await _createNotification(
        recipientId: employee.uid,
        type: 'kpi_assigned',
        title: 'تم تعيين أهداف KPI',
        body: 'تم تعيين أهداف شهر $monthKey لك بناءً على ${template.title}.',
        data: {'employeeKpiId': ref.id},
      );
    } catch (_) {}
  }

  Future<({int assigned, int skipped})> assignMonthlyKpiToEmployees({
    required UserModel creator,
    required List<UserModel> employees,
    required KpiTemplateModel template,
    required String monthKey,
  }) async {
    var assigned = 0;
    var skipped = 0;
    for (final employee in employees) {
      try {
        await assignMonthlyKpi(
          creator: creator,
          employee: employee,
          template: template,
          monthKey: monthKey,
        );
        assigned += 1;
      } on Exception catch (error) {
        if (error.toString().contains('بالفعل')) {
          skipped += 1;
          continue;
        }
        rethrow;
      }
    }
    return (assigned: assigned, skipped: skipped);
  }

  Future<void> updateMetricProgress({
    required String employeeKpiId,
    required UserModel reviewer,
    required int metricIndex,
    required double actual,
    String evidenceUrl = '',
    String managerComment = '',
  }) async {
    if (!actual.isFinite || actual < 0) {
      throw Exception('القيمة الفعلية يجب أن تكون صفراً أو رقماً موجباً.');
    }
    final ref = _db.collection('employeeKpis').doc(employeeKpiId);
    final doc = await ref.get();
    if (!doc.exists) throw Exception('سجل KPI غير موجود');
    final kpi = EmployeeKpiModel.fromFirestore(doc);
    if (kpi.status == KpiStatus.finalized) {
      throw Exception('تم إغلاق KPI لهذه الدورة ولا يمكن تعديله.');
    }
    if (metricIndex < 0 || metricIndex >= kpi.metrics.length) {
      throw Exception('المؤشر غير صحيح');
    }
    final metrics = [...kpi.metrics];
    metrics[metricIndex] = metrics[metricIndex].copyWith(
      actual: actual,
      evidenceUrl: _validatedEvidenceUrl(evidenceUrl),
      managerComment: managerComment.trim(),
    );
    final progress = EmployeeKpiModel.calculateProgress(metrics);

    await ref.update({
      'metrics': metrics.map((metric) => metric.toMap()).toList(),
      'overallProgress': progress,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await AuditLogService.instance.record(
      actorId: reviewer.uid,
      action: 'employee_kpi_progress_updated',
      targetCollection: 'employeeKpis',
      targetId: employeeKpiId,
      metadata: {
        'userId': kpi.userId,
        'metricIndex': metricIndex,
        'actual': actual,
        'overallProgress': progress,
      },
    );

    try {
      await _createNotification(
        recipientId: kpi.userId,
        type: 'kpi_progress_updated',
        title: 'تحديث على KPI',
        body: 'تم تحديث تقدمك في مؤشرات شهر ${kpi.monthKey}.',
        data: {'employeeKpiId': employeeKpiId},
      );
    } catch (_) {}
  }

  Future<void> finalizeKpi({
    required EmployeeKpiModel kpi,
    required UserModel reviewer,
  }) async {
    if (kpi.metrics.isEmpty) throw Exception('لا توجد مؤشرات لإغلاقها.');
    await _db.collection('employeeKpis').doc(kpi.employeeKpiId).update({
      'status': KpiStatus.finalized,
      'finalizedBy': reviewer.uid,
      'finalizedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await AuditLogService.instance.record(
      actorId: reviewer.uid,
      action: 'employee_kpi_finalized',
      targetCollection: 'employeeKpis',
      targetId: kpi.employeeKpiId,
      metadata: {'userId': kpi.userId, 'score': kpi.overallProgress},
    );
    try {
      await _createNotification(
        recipientId: kpi.userId,
        type: 'kpi_finalized',
        title: 'تم اعتماد نتيجة KPI',
        body:
            'تم اعتماد نتيجة دورة ${kpi.monthKey}: ${kpi.overallProgress.toStringAsFixed(1)}%.',
        data: {'employeeKpiId': kpi.employeeKpiId},
      );
    } catch (_) {}
  }

  Future<void> reopenKpi({
    required EmployeeKpiModel kpi,
    required UserModel reviewer,
  }) async {
    if (!EmployeeRole.isHr(reviewer.role)) {
      throw Exception('إعادة فتح KPI متاحة لـ HR ومالك النظام فقط.');
    }
    await _db.collection('employeeKpis').doc(kpi.employeeKpiId).update({
      'status': KpiStatus.active,
      'finalizedBy': FieldValue.delete(),
      'finalizedAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await AuditLogService.instance.record(
      actorId: reviewer.uid,
      action: 'employee_kpi_reopened',
      targetCollection: 'employeeKpis',
      targetId: kpi.employeeKpiId,
      metadata: {'userId': kpi.userId},
    );
  }

  void _validateTemplate({
    required String title,
    required String department,
    required List<KpiMetricTemplate> metrics,
  }) {
    if (title.trim().length < 3 || department.trim().isEmpty) {
      throw Exception('أدخل اسم القالب والقسم.');
    }
    if (metrics.isEmpty) throw Exception('أضف مؤشراً واحداً على الأقل.');
    if (metrics.length > 12) throw Exception('الحد الأقصى 12 مؤشراً.');
    final totalWeight = metrics.fold<double>(
      0,
      (total, metric) => total + metric.weight,
    );
    if ((totalWeight - 100).abs() > 0.01) {
      throw Exception('مجموع أوزان المؤشرات يجب أن يساوي 100%.');
    }
    for (final metric in metrics) {
      if (metric.name.trim().length < 2 ||
          metric.target <= 0 ||
          metric.weight <= 0 ||
          !KpiMetricDirection.values.contains(metric.direction)) {
        throw Exception('راجع اسم وهدف ووزن وطريقة احتساب كل مؤشر.');
      }
    }
  }

  String _validatedEvidenceUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.hasScheme ||
        !['http', 'https'].contains(uri.scheme.toLowerCase())) {
      throw Exception('رابط الإثبات يجب أن يبدأ بـ http أو https.');
    }
    return trimmed;
  }

  List<EmployeeKpiModel> _employeeKpisFromSnapshot(QuerySnapshot snapshot) {
    final records = snapshot.docs.map(EmployeeKpiModel.fromFirestore).toList();
    return _sortEmployeeKpis(records);
  }

  Stream<List<EmployeeKpiModel>> _watchMergedKpiQueries(
    List<Query<Map<String, dynamic>>> queries,
  ) {
    late final StreamController<List<EmployeeKpiModel>> controller;
    final latest = <int, List<EmployeeKpiModel>>{};
    final subscriptions =
        <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

    void emit() {
      final byId = <String, EmployeeKpiModel>{};
      for (final records in latest.values) {
        for (final record in records) {
          byId[record.employeeKpiId] = record;
        }
      }
      if (!controller.isClosed) {
        controller.add(_sortEmployeeKpis(byId.values.toList()));
      }
    }

    controller = StreamController<List<EmployeeKpiModel>>(
      onListen: () {
        for (var i = 0; i < queries.length; i++) {
          final index = i;
          subscriptions.add(
            queries[index].snapshots().listen((snapshot) {
              latest[index] = snapshot.docs
                  .map(EmployeeKpiModel.fromFirestore)
                  .toList();
              emit();
            }, onError: controller.addError),
          );
        }
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );

    return controller.stream;
  }

  List<EmployeeKpiModel> _sortEmployeeKpis(List<EmployeeKpiModel> records) {
    records.sort((a, b) => a.employeeName.compareTo(b.employeeName));
    return records;
  }

  Future<void> _createNotification({
    required String recipientId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final notifRef = _db
        .collection('notifications')
        .doc(recipientId)
        .collection('items')
        .doc();

    await notifRef.set({
      'notificationId': notifRef.id,
      'type': type,
      'title': title,
      'body': body,
      'data': data ?? {},
      'isRead': false,
      'pushSent': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('users').doc(recipientId).update({
      'unreadNotifications': FieldValue.increment(1),
    });
  }
}
