import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:go_router/go_router.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/managed_employee_service.dart';
import '../../theme/theme.dart';
import '../../components/wolf_card.dart';
import '../../core/feature_flags/phase007_feature_flags.dart';
import '../../core/feature_flags/remote_phase007_feature_flags.dart';
import '../../design_system/components/feedback_states.dart' show EmptyState;
import '../../design_system/components/skeletons.dart'
    show SkeletonAttendanceRow, SkeletonDetailPane;

class TeamAttendanceScreen extends StatefulWidget {
  const TeamAttendanceScreen({super.key});

  @override
  State<TeamAttendanceScreen> createState() => _TeamAttendanceScreenState();
}

class _TeamAttendanceScreenState extends State<TeamAttendanceScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DateTime _selectedDate = DateTime.now();
  String _selectedStatus =
      'all'; // 'all' | 'present' | 'late' | 'absent' | 'on-leave'
  final ManagedEmployeeService _managedEmployeeService =
      ManagedEmployeeService();
  Stream<List<Map<String, dynamic>>>? _attendanceListStream;
  String? _attendanceStreamKey;
  late final Stream<QuerySnapshot<Map<String, dynamic>>>
  _hiddenEmployeeIdsStream = _db
      .collection('operationalVisibility')
      .where('hiddenFromAttendance', isEqualTo: true)
      .limit(500)
      .snapshots();

  Stream<List<Map<String, dynamic>>> _attendanceForSelection(
    UserModel manager,
    String date,
    String status,
  ) {
    final key = '${manager.uid}|$date|$status';
    if (_attendanceListStream != null && _attendanceStreamKey == key) {
      return _attendanceListStream!;
    }
    _attendanceStreamKey = key;
    _attendanceListStream = _watchAttendanceForReviewer(manager, date, status);
    return _attendanceListStream!;
  }

  Stream<List<Map<String, dynamic>>> _watchAttendanceForReviewer(
    UserModel manager,
    String date,
    String status,
  ) async* {
    final teamMembers = await _managedEmployeeService.loadForReviewer(manager);
    final userIds = teamMembers.map((e) => e.uid).toSet();
    if (userIds.isEmpty && manager.uid.isNotEmpty) {
      userIds.add(manager.uid);
    }

    final queryList = <Query<Map<String, dynamic>>>[];
    Query<Map<String, dynamic>> baseDirect = _db
        .collection('attendance')
        .where('managerId', isEqualTo: manager.uid)
        .where('date', isEqualTo: date);
    if (status != 'all') {
      baseDirect = baseDirect.where('status', isEqualTo: status);
    }
    queryList.add(baseDirect);

    final userList = userIds.toList();
    for (var offset = 0; offset < userList.length; offset += 30) {
      final end = (offset + 30).clamp(0, userList.length);
      final batch = userList.sublist(offset, end);
      Query<Map<String, dynamic>> userQuery = _db
          .collection('attendance')
          .where('userId', whereIn: batch)
          .where('date', isEqualTo: date);
      if (status != 'all') {
        userQuery = userQuery.where('status', isEqualTo: status);
      }
      queryList.add(userQuery);
    }

    final controller = StreamController<List<Map<String, dynamic>>>();
    final snapshotsMap = <int, List<Map<String, dynamic>>>{};
    final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

    void emit() {
      final byId = <String, Map<String, dynamic>>{};
      for (final list in snapshotsMap.values) {
        for (final item in list) {
          final id = item['id'] as String? ?? item['userId'] as String? ?? '';
          byId[id] = item;
        }
      }
      if (!controller.isClosed) {
        final sorted = byId.values.toList();
        sorted.sort((a, b) =>
            ('${a['employeeName'] ?? ''}').compareTo('${b['employeeName'] ?? ''}'));
        controller.add(sorted);
      }
    }

    for (var i = 0; i < queryList.length; i++) {
      final index = i;
      subs.add(
        queryList[i].snapshots().listen(
          (snap) {
            snapshotsMap[index] = snap.docs.map((doc) {
              final d = Map<String, dynamic>.from(doc.data());
              d['id'] = doc.id;
              return d;
            }).toList();
            emit();
          },
          onError: (e) {
            if (!controller.isClosed) controller.addError(e);
          },
        ),
      );
    }

    controller.onCancel = () {
      for (final s in subs) {
        s.cancel();
      }
    };

    yield* controller.stream;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: ZaWolfColors.primaryCyan,
              onPrimary: ZaWolfColors.background,
              surface: ZaWolfColors.surface01,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final manager = authService.currentUser;
    final theme = Theme.of(context);
    final phase007 = context.watch<RemotePhase007FeatureFlags>();
    final timelineEnabled = phase007.isEnabledFor(
      feature: Phase007Feature.operationalVisibility,
      actorId: manager?.uid ?? '',
    );
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    if (manager == null) {
      return const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: SkeletonDetailPane(),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'حضور وانصراف الفريق',
            style: theme.textTheme.headlineMedium,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Section Panel
          Container(
            padding: const EdgeInsets.all(16),
            color: ZaWolfColors.surface01,
            child: Column(
              children: [
                // Date picker trigger
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () => _selectDate(context),
                      icon: const Icon(
                        Icons.calendar_today,
                        color: ZaWolfColors.primaryCyan,
                        size: 18,
                      ),
                      label: Text(
                        DateFormat('yyyy-MM-dd').format(_selectedDate),
                        style: const TextStyle(
                          color: ZaWolfColors.primaryCyan,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      'التاريخ المختار',
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: ZaWolfColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Status Filter Chips
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('الكل', 'all'),
                        const SizedBox(width: 8),
                        _buildFilterChip('حاضر', 'present'),
                        const SizedBox(width: 8),
                        _buildFilterChip('متأخر', 'late'),
                        const SizedBox(width: 8),
                        _buildFilterChip('غائب', 'absent'),
                        const SizedBox(width: 8),
                        _buildFilterChip('إجازة', 'on-leave'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Stream Results
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _hiddenEmployeeIdsStream,
              builder: (context, hiddenSnapshot) {
                final hiddenIds =
                    hiddenSnapshot.data?.docs.map((doc) => doc.id).toSet() ??
                    const <String>{};
                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _attendanceForSelection(
                    manager,
                    dateStr,
                    _selectedStatus,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: 6,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, __) => const SkeletonAttendanceRow(),
                      );
                    }

                    final docs = (snapshot.data ?? [])
                        .where((data) => !hiddenIds.contains(data['userId']))
                        .toList(growable: false);
                    if (docs.isEmpty) {
                      return const EmptyState(
                        title: 'لا توجد سجلات مطابقة للفلاتر المحددة.',
                        icon: Icons.group_off_outlined,
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index];
                        final name = data['employeeName'] as String? ?? '';
                        final userId = data['userId'] as String? ?? '';
                        final empId = data['employeeId'] as String? ?? '';
                        final status = data['status'] as String? ?? 'present';
                        final checkIn = data['checkInTime'] as Timestamp?;
                        final checkOut = data['checkOutTime'] as Timestamp?;
                        final checkoutPolicyEnabled =
                            data['checkoutPolicyEnabled'] as bool?;
                        final totalHours = (data['totalWorkHours'] as num?)
                            ?.toDouble();
                        final inGeofence =
                            data['isWithinGeofence'] as bool? ?? true;
                        final lateMinutes = data['lateMinutes'] as int? ?? 0;

                        Color statusColor = ZaWolfColors.success;
                        String statusLabel = 'في الميعاد';

                        if (status == 'late') {
                          statusColor = ZaWolfColors.warning;
                          statusLabel = 'متأخر $lateMinutes دقيقة';
                        } else if (status == 'absent') {
                          statusColor = ZaWolfColors.error;
                          statusLabel = 'غائب';
                        } else if (status == 'on-leave') {
                          statusColor = ZaWolfColors.primaryBlue;
                          statusLabel = 'إجازة رسمية';
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          key: ValueKey(data['id'] ?? '$index'),
                          child: WolfCard(
                            onTap: userId.isEmpty
                                ? null
                                : () => context.go(
                                    timelineEnabled
                                        ? '/operations/employee/$userId'
                                        : '/manager/employee/$userId',
                                  ),
                            hasBorderGlow: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header Row
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        statusLabel,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              name,
                                              style: theme
                                                  .textTheme
                                                  .titleMedium!
                                                  .copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            Text(
                                              'كود: $empId',
                                              style: theme.textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 10),
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor:
                                              ZaWolfColors.surface02,
                                          child: Text(
                                            name.substring(0, 1),
                                            style: const TextStyle(
                                              color: ZaWolfColors.primaryCyan,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(
                                  color: ZaWolfColors.surface02,
                                  height: 20,
                                ),

                                // Log Details
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          checkoutPolicyEnabled == false &&
                                                  checkOut == null
                                              ? 'الانصراف: لا ينطبق (سياسة HR)'
                                              : 'الانصراف: ${checkOut != null ? DateFormat('hh:mm a').format(checkOut.toDate()) : '—'}',
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                        Text(
                                          'ساعات العمل: ${totalHours != null ? '${totalHours.toStringAsFixed(1)} ساعة' : '—'}',
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'الحضور: ${checkIn != null ? DateFormat('hh:mm a').format(checkIn.toDate()) : '—'}',
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              inGeofence
                                                  ? 'داخل النطاق ✓'
                                                  : 'خارج النطاق ⚠️',
                                              style: TextStyle(
                                                color: inGeofence
                                                    ? ZaWolfColors.success
                                                    : ZaWolfColors.error,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              ' :النطاق الجغرافي',
                                              style: theme.textTheme.bodyMedium!
                                                  .copyWith(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final active = _selectedStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedStatus = value;
          });
        }
      },
      selectedColor: ZaWolfColors.primaryCyan,
      backgroundColor: ZaWolfColors.surface02,
      labelStyle: TextStyle(
        color: active ? ZaWolfColors.background : ZaWolfColors.textSecondary,
        fontWeight: active ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
