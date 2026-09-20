import 'dart:ui' show PointerDeviceKind;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../models/employee_role.dart';
import '../models/request_approval_policy.dart';
import '../services/request_approval_policy_service.dart';
import '../theme/theme.dart';

class RequestApprovalTimeline extends StatelessWidget {
  const RequestApprovalTimeline({
    super.key,
    required this.data,
    this.compact = false,
  });

  final Map<String, dynamic> data;
  final bool compact;

  static final Future<RequestApprovalPolicy> _approvalPolicy =
      RequestApprovalPolicyService().getPolicy();

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  List<Map<String, dynamic>> get _history {
    return (data['approvalHistory'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Map<String, dynamic>? _event(String stage, [int? index]) {
    final matches = _history.where((event) => event['stage'] == stage).toList();
    if (matches.isEmpty) return null;
    if (index != null && index < matches.length) return matches[index];
    return matches.last;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: FutureBuilder<RequestApprovalPolicy>(
        future: _approvalPolicy,
        initialData: const RequestApprovalPolicy(),
        builder:
            (context, snapshot) => _buildTimeline(
              context,
              snapshot.data ?? const RequestApprovalPolicy(),
            ),
      ),
    );
  }

  Widget _buildTimeline(
    BuildContext context,
    RequestApprovalPolicy approvalPolicy,
  ) {
    final status = data['status'] as String? ?? 'pending';
    final route =
        (data['approvalRoute'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
          ..sort(
            (left, right) => ((left['order'] as num?)?.toInt() ?? 0).compareTo(
              (right['order'] as num?)?.toInt() ?? 0,
            ),
          );
    if (route.isNotEmpty) {
      return _buildCustomRouteTimeline(context, status, route);
    }
    final isAdvance = data['advanceRouteStage'] != null ||
        data['requestType'] == 'advance' ||
        (data.containsKey('amount') &&
            (data.containsKey('monthKey') ||
                data.containsKey('advanceId') ||
                data.containsKey('installmentMonths'))) ||
        _history.any(
          (event) => event['stage'] == 'accounting' || event['stage'] == 'ceo',
        );
    if (isAdvance) {
      return _buildAdvanceRouteTimeline(context, status);
    }
    var managerNames =
        (data['managerNames'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList();
    var managerIds =
        (data['managerIds'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList();
    if (managerNames.isEmpty && (data['managerName'] as String?)?.trim().isNotEmpty == true) {
      managerNames = [(data['managerName'] as String).trim()];
    }
    if (managerIds.isEmpty && (data['managerId'] as String?)?.trim().isNotEmpty == true) {
      managerIds = [(data['managerId'] as String).trim()];
    }
    final assignedCeoId = '${data['ceoId'] ?? ''}';
    final managerTrail =
        (data['managerApprovalTrail'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
    final requiresCeo = data['requiresCeoApproval'] == true;
    final standaloneCeo =
        requiresCeo && data['ceoApprovalViaManagerChain'] != true;
    final hrEvent = _event('hr');
    final hasRecordedHrReview =
        hrEvent != null ||
        data['hrReviewedAt'] != null ||
        status == 'pending_hr';
    final showHrStage =
        hasRecordedHrReview ||
        data['requiresHrApproval'] == true ||
        managerNames.isEmpty ||
        (data['requiresHrApproval'] == null &&
            approvalPolicy.requireHrAfterManagerApproval);
    final hasManagerRejected = managerTrail.any(
      (m) => m['status'] == 'rejected' || m['action'] == 'rejected',
    );
    final hasHrRejected = hrEvent?['status'] == 'rejected';
    final hasCeoRejected = _event('ceo')?['status'] == 'rejected';
    final hasRecordedRejectionInStages =
        hasManagerRejected || hasHrRejected || hasCeoRejected;

    final managerStagesCount = hasManagerRejected
        ? (managerTrail.indexWhere((m) => m['status'] == 'rejected' || m['action'] == 'rejected') + 1)
        : managerNames.length;

    final stages = <_TimelineStage>[
      _TimelineStage(
        label: 'تم الإرسال',
        person: data['employeeName'] as String? ?? '',
        icon: Icons.send_outlined,
        state: _StageState.done,
        timestamp:
            _date(_event('submitted')?['timestamp']) ??
            _date(data['submittedAt']),
      ),
      for (var i = 0; i < managerStagesCount; i++)
        _TimelineStage(
          label:
              i < managerIds.length && managerIds[i] == assignedCeoId
                  ? 'CEO المعيّن'
                  : (i == 0 ? 'المدير المباشر' : 'المدير الأعلى'),
          person: (i < managerTrail.length &&
                  (managerTrail[i]['reviewerName'] as String?)?.trim().isNotEmpty == true)
              ? (managerTrail[i]['reviewerName'] as String).trim()
              : (i < managerNames.length ? managerNames[i] : ''),
          jobTitle:
              _roleLabel(
                i < managerTrail.length
                    ? managerTrail[i]['reviewerRole'] as String?
                    : null,
              ) ??
              (i < managerIds.length && managerIds[i] == assignedCeoId
                  ? 'الرئيس التنفيذي'
                  : null),
          icon:
              i < managerIds.length && managerIds[i] == assignedCeoId
                  ? Icons.workspace_premium_outlined
                  : Icons.supervisor_account_outlined,
          state: _managerState(status, managerTrail, i),
          timestamp:
              i < managerTrail.length
                  ? _date(managerTrail[i]['timestamp'] ?? managerTrail[i]['reviewedAt'])
                  : null,
        ),
      if (!hasManagerRejected && showHrStage && !requiresCeo)
        _TimelineStage(
          label: 'الموارد البشرية',
          person:
              (hrEvent?['actorName'] as String?) ??
              (data['hrReviewerName'] as String?) ??
              'HR',
          jobTitle:
              _roleLabel(hrEvent?['actorRole'] as String?) ?? 'الموارد البشرية',
          icon: Icons.badge_outlined,
          state: _namedStageState(status, 'hr', hrEvent),
          timestamp:
              _date(hrEvent?['timestamp']) ?? _date(data['hrReviewedAt']),
        ),
      if (!hasManagerRejected && !hasHrRejected && standaloneCeo)
        _TimelineStage(
          label: 'اعتماد CEO',
          person:
              (_event('ceo')?['actorName'] as String?) ??
              (data['ceoName'] as String?) ??
              'CEO-100',
          jobTitle: 'الرئيس التنفيذي',
          icon: Icons.workspace_premium_outlined,
          state: _namedStageState(status, 'ceo', _event('ceo')),
          timestamp: _date(_event('ceo')?['timestamp']),
        ),
      if (!hasManagerRejected && showHrStage && requiresCeo)
        _TimelineStage(
          label: 'الموارد البشرية',
          person:
              (hrEvent?['actorName'] as String?) ??
              (data['hrReviewerName'] as String?) ??
              'HR',
          jobTitle:
              _roleLabel(hrEvent?['actorRole'] as String?) ?? 'الموارد البشرية',
          icon: Icons.badge_outlined,
          state: _namedStageState(status, 'hr', hrEvent),
          timestamp:
              _date(hrEvent?['timestamp']) ?? _date(data['hrReviewedAt']),
        ),
      if (status == 'approved' ||
          status == 'cancelled' ||
          (status == 'rejected' && !hasRecordedRejectionInStages) ||
          (status != 'rejected' && status != 'cancelled' && status != 'approved'))
        _TimelineStage(
          label:
              status == 'rejected'
                  ? 'مرفوض'
                  : status == 'cancelled'
                  ? 'ملغي'
                  : 'مقبول نهائياً',
          person:
              data['finalApproverName'] as String? ??
              data['reviewerName'] as String? ??
              '',
          jobTitle: _finalApproverRoleLabel(),
          icon:
              status == 'rejected'
                  ? Icons.cancel_outlined
                  : status == 'cancelled'
                  ? Icons.block_outlined
                  : Icons.verified_outlined,
          state:
              status == 'rejected' || status == 'cancelled'
                  ? _StageState.rejected
                  : status == 'approved'
                  ? _StageState.done
                  : _StageState.waiting,
          timestamp: _date(data['finalApprovalAt']) ?? _date(data['reviewedAt']),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(color: ZaWolfColors.surface03),
        Text(
          'مسار الموافقات',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: ZaWolfColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 10),
        _ScrollableTimelineRow(stages: stages, compact: compact),
        if (status == 'rejected' &&
            (data['reviewerComment'] as String?)?.trim().isNotEmpty == true)
          Text(
            'سبب الرفض: ${data['reviewerComment']}',
            style: const TextStyle(color: ZaWolfColors.error),
            textDirection: TextDirection.rtl,
          ),
      ],
    );
  }

  Widget _buildCustomRouteTimeline(
    BuildContext context,
    String status,
    List<Map<String, dynamic>> route,
  ) {
    final currentApproverId = '${data['currentApproverId'] ?? ''}';
    final hasRouteRejected = route.any((r) => r['state'] == 'rejected');
    final rejectedIndex = route.indexWhere((r) => r['state'] == 'rejected');
    final count = hasRouteRejected ? (rejectedIndex + 1) : route.length;

    final stages = <_TimelineStage>[
      _TimelineStage(
        label: 'تم الإرسال',
        person: data['employeeName'] as String? ?? '',
        icon: Icons.send_outlined,
        state: _StageState.done,
        timestamp:
            _date(_event('submitted')?['at']) ?? _date(data['submittedAt']),
      ),
      for (var index = 0; index < count; index++)
        _TimelineStage(
          label: 'الموافقة ${index + 1}',
          person: '${route[index]['approverName'] ?? 'مسؤول الموافقة'}',
          jobTitle:
              '${route[index]['approverRole'] ?? ''}'.trim().isEmpty
                  ? null
                  : '${route[index]['approverRole']}',
          icon: Icons.how_to_reg_outlined,
          state: _customRouteState(route[index], currentApproverId),
          timestamp: _date(route[index]['actedAt']),
        ),
      if (status == 'approved' ||
          status == 'cancelled' ||
          (status == 'rejected' && !hasRouteRejected) ||
          (status != 'rejected' && status != 'cancelled' && status != 'approved'))
        _TimelineStage(
          label:
              status == 'rejected'
                  ? 'مرفوض'
                  : status == 'cancelled'
                  ? 'ملغي'
                  : 'مقبول نهائياً',
          person:
              data['finalApproverName'] as String? ??
              data['reviewerName'] as String? ??
              '',
          icon:
              status == 'rejected'
                  ? Icons.cancel_outlined
                  : status == 'cancelled'
                  ? Icons.block_outlined
                  : Icons.verified_outlined,
          state:
              status == 'rejected' || status == 'cancelled'
                  ? _StageState.rejected
                  : status == 'approved'
                  ? _StageState.done
                  : _StageState.waiting,
          timestamp: _date(data['finalApprovalAt']) ?? _date(data['reviewedAt']),
        ),
    ];
    return _renderStages(context, status, stages);
  }

  Widget _buildAdvanceRouteTimeline(BuildContext context, String status) {
    final routeStage = '${data['advanceRouteStage'] ?? ''}';
    final currentName = '${data['managerName'] ?? ''}';
    final hasAdvanceRejected = _history.any((e) => e['status'] == 'rejected');
    _TimelineStage stage(String key, String label, IconData icon) {
      final event = _event(key);
      final isCurrent =
          (key == 'hr' &&
              (status == 'pending_hr' ||
                  (status.startsWith('pending') &&
                      (routeStage.isEmpty || routeStage == 'hr')))) ||
          (key == 'ceo' &&
              routeStage == 'ceo' &&
              status.startsWith('pending')) ||
          (key == 'accounting' &&
              routeStage == 'accounting' &&
              status.startsWith('pending'));
      final defaultName = key == 'ceo'
          ? (data['ceoName'] as String? ?? 'سامي المتولي المتولي')
          : (key == 'accounting'
              ? (data['accountantName'] as String? ?? 'الحسابات')
              : (key == 'hr' ? 'الموارد البشرية' : ''));
      final isDone = event != null
          ? event['status'] != 'rejected'
          : (key == 'hr' &&
                  (routeStage == 'ceo' ||
                      routeStage == 'accounting' ||
                      status == 'approved')) ||
              (key == 'ceo' &&
                  (routeStage == 'accounting' || status == 'approved')) ||
              (key == 'accounting' && status == 'approved');
      final isRejected = event?['status'] == 'rejected' ||
          (status == 'rejected' && (isCurrent || routeStage == key));

      return _TimelineStage(
        label: label,
        person:
            (event?['actorName'] as String?) ??
            (isCurrent ? currentName : defaultName),
        jobTitle: label,
        icon: icon,
        state: isRejected
            ? _StageState.rejected
            : isDone
                ? _StageState.done
                : (isCurrent ? _StageState.current : _StageState.waiting),
        timestamp: _date(event?['at']) ?? _date(event?['timestamp']),
      );
    }

    return _renderStages(context, status, [
      _TimelineStage(
        label: 'تم الإرسال',
        person: data['employeeName'] as String? ?? '',
        icon: Icons.send_outlined,
        state: _StageState.done,
        timestamp:
            _date(_event('submitted')?['at']) ?? _date(data['submittedAt']),
      ),
      stage('hr', 'الموارد البشرية', Icons.badge_outlined),
      stage('ceo', 'الرئيس التنفيذي', Icons.workspace_premium_outlined),
      stage('accounting', 'الحسابات', Icons.account_balance_outlined),
      if (status == 'approved' ||
          status == 'cancelled' ||
          (status == 'rejected' && !hasAdvanceRejected) ||
          (status != 'rejected' && status != 'cancelled' && status != 'approved'))
        _TimelineStage(
          label:
              status == 'rejected'
                  ? 'مرفوض'
                  : status == 'cancelled'
                  ? 'ملغي'
                  : 'مقبول نهائياً',
          person: data['reviewerName'] as String? ?? '',
          icon:
              status == 'rejected'
                  ? Icons.cancel_outlined
                  : status == 'cancelled'
                  ? Icons.block_outlined
                  : Icons.verified_outlined,
          state:
              status == 'rejected' || status == 'cancelled'
                  ? _StageState.rejected
                  : status == 'approved'
                  ? _StageState.done
                  : _StageState.waiting,
          timestamp: _date(data['reviewedAt']),
        ),
    ]);
  }

  _StageState _customRouteState(
    Map<String, dynamic> stage,
    String currentApproverId,
  ) {
    return switch ('${stage['state'] ?? 'pending'}') {
      'approved' => _StageState.done,
      'rejected' => _StageState.rejected,
      _ when '${stage['approverId'] ?? ''}' == currentApproverId =>
        _StageState.current,
      _ => _StageState.waiting,
    };
  }

  Widget _renderStages(
    BuildContext context,
    String status,
    List<_TimelineStage> stages,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(color: ZaWolfColors.surface03),
        Text(
          'مسار الموافقات',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: ZaWolfColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 10),
        _ScrollableTimelineRow(stages: stages, compact: compact),
        if (status == 'rejected' &&
            (data['reviewerComment'] as String?)?.trim().isNotEmpty == true)
          Text(
            'سبب الرفض: ${data['reviewerComment']}',
            style: const TextStyle(color: ZaWolfColors.error),
            textDirection: TextDirection.rtl,
          ),
      ],
    );
  }

  String? _finalApproverRoleLabel() {
    if (_history.isEmpty) return null;
    final event = _history.last;
    return _roleLabel(event['actorRole'] as String?) ??
        switch (event['stage']) {
          'hr' => 'الموارد البشرية',
          'ceo' => 'الرئيس التنفيذي',
          'manager' => 'مدير',
          _ => null,
        };
  }

  String? _roleLabel(String? role) {
    return switch (role) {
      EmployeeRole.teamLeader => 'قائد فريق',
      EmployeeRole.manager => 'مدير',
      EmployeeRole.hrAdmin => 'مسؤول موارد بشرية',
      EmployeeRole.superAdmin => 'مالك النظام',
      _ => null,
    };
  }

  _StageState _managerState(
    String status,
    List<Map<String, dynamic>> trail,
    int index,
  ) {
    if (index < trail.length) {
      return trail[index]['status'] == 'rejected'
          ? _StageState.rejected
          : _StageState.done;
    }
    final current = (data['managerApprovalIndex'] as num?)?.toInt() ?? 0;
    if (status == 'pending_manager' && index == current) {
      return _StageState.current;
    }
    return _StageState.waiting;
  }

  _StageState _namedStageState(
    String status,
    String stage,
    Map<String, dynamic>? event,
  ) {
    if (event != null) {
      return event['status'] == 'rejected'
          ? _StageState.rejected
          : _StageState.done;
    }
    if (status == 'pending_$stage') return _StageState.current;
    if (status == 'approved') return _StageState.done;
    return _StageState.waiting;
  }
}

enum _StageState { done, current, waiting, rejected }

class _TimelineStage {
  const _TimelineStage({
    required this.label,
    required this.person,
    required this.icon,
    required this.state,
    this.jobTitle,
    this.timestamp,
  });

  final String label;
  final String person;
  final IconData icon;
  final _StageState state;
  final String? jobTitle;
  final DateTime? timestamp;
}

class _TimelineConnector extends StatelessWidget {
  const _TimelineConnector({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 17),
          child: Row(
            textDirection: TextDirection.ltr,
            children: [
              Icon(
                Icons.arrow_back_ios_new_rounded,
                size: compact ? 10 : 12,
                color: ZaWolfColors.textMuted,
                textDirection: TextDirection.ltr,
              ),
              const Expanded(
                child: Divider(height: 1, color: ZaWolfColors.surface03),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageTile extends StatelessWidget {
  const _StageTile({required this.stage, required this.compact});

  final _TimelineStage stage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = switch (stage.state) {
      _StageState.done => ZaWolfColors.success,
      _StageState.current => ZaWolfColors.warning,
      _StageState.rejected => ZaWolfColors.error,
      _StageState.waiting => ZaWolfColors.textMuted,
    };
    return SizedBox(
      width: compact ? 108 : 124,
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.14),
              border: Border.all(color: color),
            ),
            child: Icon(stage.icon, size: 20, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            stage.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          if (stage.person.isNotEmpty)
            Text(
              stage.person,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ZaWolfColors.textSecondary,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          if (stage.jobTitle?.isNotEmpty == true)
            Text(
              stage.jobTitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ZaWolfColors.textMuted,
                fontSize: 9,
              ),
              textAlign: TextAlign.center,
            ),
          if (stage.timestamp != null)
            Text(
              DateFormat('dd/MM · HH:mm').format(stage.timestamp!),
              style: const TextStyle(
                color: ZaWolfColors.textMuted,
                fontSize: 9,
              ),
              textDirection: TextDirection.ltr,
            ),
        ],
      ),
    );
  }
}

class _ScrollableTimelineRow extends StatelessWidget {
  const _ScrollableTimelineRow({
    required this.stages,
    required this.compact,
  });

  final List<_TimelineStage> stages;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 120.0 : 142.0;
    return SizedBox(
      height: height,
      child: ScrollConfiguration(
        behavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
          },
        ),
        child: Scrollbar(
          thumbVisibility: false,
          interactive: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              textDirection: TextDirection.rtl,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < stages.length; index++) ...[
                  _StageTile(stage: stages[index], compact: compact),
                  if (index < stages.length - 1)
                    _TimelineConnector(compact: compact),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

