import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/dashboard_attendance_summary_service.dart';
import '../../services/pending_requests_service.dart';
import '../../models/employee_role.dart';
import '../../models/sales_kpi_summary.dart';
import '../../theme/theme.dart';
import '../../components/attendance_insights_card.dart';

import '../../components/sales_kpi_summary_card.dart';
import '../../components/sales_kpi_filter_sheet.dart';
import '../../components/wolf_card.dart';
import '../../design_system/tokens.dart';
import '../../design_system/components/app_logo.dart';
import '../../design_system/components/priority_strip.dart';
import '../../design_system/components/section_header.dart';
import '../../design_system/components/stat_card.dart';
import '../widgets/end_of_day_briefing_card.dart';
import '../../services/sales_kpi_integration_service.dart';
import '../../utils/user_facing_error.dart';

class HrDashboardScreen extends StatefulWidget {
  const HrDashboardScreen({super.key});

  @override
  State<HrDashboardScreen> createState() => _HrDashboardScreenState();
}

class _HrDashboardScreenState extends State<HrDashboardScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final DashboardAttendanceSummaryService _summaryService =
      DashboardAttendanceSummaryService();
  int _employeesCount = 0;
  int _locationsCount = 0;
  bool _loadingCounts = true;
  Future<DashboardAttendanceSummary>? _attendanceSummaryFuture;
  String? _selectedSalesKpiPeriod;

  @override
  void initState() {
    super.initState();
    _fetchSummaryCounts();
  }

  Future<void> _fetchSummaryCounts() async {
    try {
      final results = await Future.wait([
        _db.collection('users').count().get(),
        _db
            .collection('locations')
            .where('isActive', isEqualTo: true)
            .count()
            .get(),
      ]);

      if (mounted) {
        setState(() {
          _employeesCount = results[0].count ?? 0;
          _locationsCount = results[1].count ?? 0;
          _loadingCounts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingCounts = false;
        });
      }
    }
  }

  void _loadAttendanceSummary() {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return;
    setState(() {
      _attendanceSummaryFuture = _summaryService.loadForReviewer(user);
    });
  }

  Future<void> _editSalesKpiPeriod(
    SalesKpiSummary current,
    String actorId,
  ) async {
    final service = SalesKpiIntegrationService();
    final currentFilters =
        await service.watchFilters().first ??
        SalesKpiFilters(
          startDate: current.periodStart,
          endDate: current.periodEnd,
        );
    if (!mounted) return;
    final updated = await showSalesKpiFilterSheet(
      context,
      initial: currentFilters,
      options: current.options,
    );
    if (updated != null && mounted) {
      await service.updateFilters(filters: updated, actorId: actorId);
      if (!mounted) return;
      final newPeriodKey =
          updated.startDate.length >= 7
              ? updated.startDate.substring(0, 7)
              : '';
      setState(() {
        _selectedSalesKpiPeriod = newPeriodKey;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ الفلاتر والفترة بنجاح وتم ربطها بالمزامنة.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final hrAdmin = authService.currentUser;
    final theme = Theme.of(context);

    if (hrAdmin == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
        ),
      );
    }
    final canAccessReports = EmployeeRole.canAccessReports(hrAdmin.role);

    _attendanceSummaryFuture ??= _summaryService.loadForReviewer(hrAdmin);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'لوحة الموارد البشرية (HR)',
          style: theme.textTheme.headlineMedium,
        ),
        actions: [
          IconButton(
            tooltip: 'بصمتي الشخصية (تسجيل الحضور)',
            icon: const Icon(
              Icons.fingerprint,
              color: ZaWolfColors.primaryCyan,
              size: 28,
            ),
            onPressed: () => context.push('/employee/dashboard'),
          ),
          IconButton(
            tooltip: 'سجل الحضور والغياب',
            icon: const Icon(
              Icons.co_present_outlined,
              color: ZaWolfColors.primaryCyan,
            ),
            onPressed: () => context.push('/hr/attendance-summary'),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: ZaWolfColors.error),
            onPressed: () async {
              await authService.signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          DsSpacing.lg,
          DsSpacing.lg,
          DsSpacing.lg,
          110,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header
            Container(
              padding: const EdgeInsets.all(DsSpacing.lg),
              decoration: BoxDecoration(
                color: ZaWolfColors.surface01,
                borderRadius: DsRadius.inputBorder,
                border: Border.all(color: ZaWolfColors.surface03),
              ),
              child: Row(
                children: [
                  const AppLogo(size: 46),
                  const SizedBox(width: DsSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'مرحباً، ${hrAdmin.displayName}',
                          style: theme.textTheme.headlineSmall!.copyWith(
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.rtl,
                        ),
                        Text(
                          'التحكم العام بالمنظومة · ${hrAdmin.locationName}',
                          style: theme.textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DsSpacing.lg),

            // 2. Priority strip — pending approvals & attendance access
            ValueListenableBuilder<int>(
              valueListenable: PendingRequestsService.instance.pendingCount,
              builder:
                  (context, pendingCount, _) => PriorityStrip(
                    items: [
                      PriorityItem(
                        label: 'بصمتي الشخصية (تسجيل الحضور)',
                        count: 0,
                        icon: Icons.fingerprint,
                        accent: ZaWolfColors.primaryCyan,
                        onTap: () => context.go('/employee/dashboard'),
                      ),
                      PriorityItem(
                        label: 'إدارة وسجلات الحضور',
                        count: 0,
                        icon: Icons.co_present_outlined,
                        accent: ZaWolfColors.primaryBlue,
                        onTap: () => context.go('/hr/attendance-summary'),
                      ),
                      PriorityItem(
                        label: 'طلبات معلقة بانتظار المراجعة',
                        count: pendingCount,
                        icon: Icons.rule_outlined,
                        onTap: () {
                          final firstPending =
                              PendingRequestsService
                                  .instance
                                  .firstPendingCategory;
                          if (firstPending != null) {
                            context.go('/hr/requests?category=$firstPending');
                          } else {
                            context.go('/hr/requests?smart=true');
                          }
                        },
                      ),
                      PriorityItem(
                        label: 'إدارة كؤوس وشارات التميز',
                        count: 0,
                        icon: Icons.emoji_events,
                        accent: const Color(0xFFFFD700),
                        onTap: () => context.push('/hr/custom-badges'),
                      ),
                    ],
                  ),
            ),
            const EndOfDayBriefingCard(isHr: true),
            const SizedBox(height: DsSpacing.md),

            // 3. Metrics row (max four)
            _HrMetricsRow(
              loadingCounts: _loadingCounts,
              employeesCount: _employeesCount,
              locationsCount: _locationsCount,
              attendanceSummaryFuture: _attendanceSummaryFuture!,
            ),

            const SizedBox(height: DsSpacing.xl),

            FutureBuilder<DashboardAttendanceSummary>(
              future: _attendanceSummaryFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return WolfCard(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: ZaWolfColors.error,
                          size: 34,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          userFacingError(
                            snapshot.error!,
                            fallback:
                                'تعذر تحميل ملخص الحضور. لم يتم عرض أرقام تقديرية.',
                          ),
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                        ),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: _loadAttendanceSummary,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const WolfCard(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: CircularProgressIndicator(
                          color: ZaWolfColors.primaryCyan,
                        ),
                      ),
                    ),
                  );
                }
                return AttendanceInsightsCard(
                  summary: snapshot.data!,
                  onRefresh: _loadAttendanceSummary,
                  onTap: () => context.go('/hr/attendance-summary'),
                  onCategoryTap:
                      (status) =>
                          context.go('/hr/attendance-summary?status=$status'),
                );
              },
            ),
            const SizedBox(height: 24),

            if (EmployeeRole.isHrStaff(hrAdmin.role) ||
                hrAdmin.role == EmployeeRole.superAdmin)
              StreamBuilder<SalesKpiSummary?>(
                stream: SalesKpiIntegrationService().watchCurrentSummary(),
                builder: (context, currentSnapshot) {
                  final current = currentSnapshot.data;
                  if (current == null) return const SizedBox.shrink();
                  return StreamBuilder<List<SalesKpiSummary>>(
                    stream: SalesKpiIntegrationService().watchSummaryHistory(),
                    builder: (context, historySnapshot) {
                      final seenKeys = <String>{current.periodKey};
                      final history = <SalesKpiSummary>[
                        current,
                        ...?historySnapshot.data?.where(
                          (item) =>
                              item.periodKey.isNotEmpty &&
                              seenKeys.add(item.periodKey),
                        ),
                      ];
                      final selected = history.firstWhere(
                        (item) => item.periodKey == _selectedSalesKpiPeriod,
                        orElse: () => current,
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: SalesKpiSummaryCard(
                          summary: selected,
                          history: history,
                          onPeriodChanged:
                              (value) => setState(
                                () => _selectedSalesKpiPeriod = value.periodKey,
                              ),
                          onEditPeriod:
                              () => _editSalesKpiPeriod(selected, hrAdmin.uid),
                        ),
                      );
                    },
                  );
                },
              ),

            // Grouped quick actions by domain
            SectionHeader(
              title: 'الحضور والوقت',
              actionLabel: 'عرض الكل',
              onAction: () => context.go('/hub/time'),
            ),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: MediaQuery.sizeOf(context).width >= 1200 ? 4 : 2,
              crossAxisSpacing: DsSpacing.lg,
              mainAxisSpacing: DsSpacing.lg,
              childAspectRatio:
                  MediaQuery.sizeOf(context).width >= 1200 ? 1.45 : 1.3,
              children: [
                _actionTile(
                  'تسجيل بصمتي الشخصية',
                  'بصمة الحضور والانصراف اليومية',
                  Icons.fingerprint,
                  () => context.go('/employee/dashboard'),
                  theme,
                ),
                _actionTile(
                  'سجل الحضور والغياب',
                  'كشوف وحركات حضور جميع الموظفين',
                  Icons.co_present_outlined,
                  () => context.go('/hr/attendance-summary'),
                  theme,
                ),
                _actionTile(
                  'تسجيل حضور يدوي',
                  'تسجيل حضور أو انصراف استثنائي لموظف مع سبب ومراجعة',
                  Icons.edit_calendar_outlined,
                  () => context.go('/hr/manual-attendance'),
                  theme,
                ),
                _actionTile(
                  'إدارة الفروع والمواقع',
                  'تحديد النطاقات الجغرافية ومطابقة الحضور',
                  Icons.map_outlined,
                  () => context.go('/hr/locations'),
                  theme,
                ),
                _actionTile(
                  'أيام العطلة',
                  'إجازات الشركة الرسمية',
                  Icons.event_busy_outlined,
                  () => context.go('/hr/day-offs'),
                  theme,
                ),
                _actionTile(
                  'سياسة الدوام',
                  'مواعيد الحضور والانصراف والتنبيهات والخصومات',
                  Icons.schedule_outlined,
                  () => context.go('/hr/attendance-policy'),
                  theme,
                ),
                _actionTile(
                  'المهام الميدانية',
                  'تصريح عمل خارج الفرع ومتابعة الانصراف',
                  Icons.directions_walk_outlined,
                  () => context.go('/hr/field-assignments'),
                  theme,
                ),
                _actionTile(
                  'قاعات الاجتماعات',
                  'إضافة القاعات المتاحة لطلبات الموظفين',
                  Icons.meeting_room_outlined,
                  () => context.go('/hr/meeting-rooms'),
                  theme,
                ),
                _actionTile(
                  'طلبات الاجتماعات',
                  'طلبات تنتظر قرارك وسجل الاجتماعات',
                  Icons.groups_2_outlined,
                  () => context.go('/meeting/approvals'),
                  theme,
                ),
                _actionTile(
                  'أنواع الطلبات المخصصة',
                  'إنشاء نماذج الطلبات ومسارات الموافقة',
                  Icons.playlist_add_check_outlined,
                  () => context.go('/hr/custom-request-types'),
                  theme,
                ),
              ],
            ),
            const SizedBox(height: DsSpacing.xl),
            SectionHeader(
              title: 'الأشخاص والتقارير',
              actionLabel: 'عرض الكل',
              onAction: () => context.go('/hub/people'),
            ),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: MediaQuery.sizeOf(context).width >= 1200 ? 4 : 2,
              crossAxisSpacing: DsSpacing.lg,
              mainAxisSpacing: DsSpacing.lg,
              childAspectRatio:
                  MediaQuery.sizeOf(context).width >= 1200 ? 1.45 : 1.3,
              children: [
                _actionTile(
                  'إدارة الطلبات',
                  'مراجعة الإجازات، الأذونات، والسلف',
                  Icons.assignment_turned_in_outlined,
                  () => context.go('/hr/requests'),
                  theme,
                ),
                _actionTile(
                  'إدارة الموظفين',
                  'إضافة موظف وتعديل بياناته وصلاحياته',
                  Icons.person_add_alt_1,
                  () => context.go('/hr/employees'),
                  theme,
                ),
                _actionTile(
                  'بث الإعلانات العامة',
                  'نشر إشعار إداري لجميع موظفي المنظومة',
                  Icons.campaign_outlined,
                  () => context.go('/hr/announcements'),
                  theme,
                ),
                if (canAccessReports)
                  _actionTile(
                    'تصدير التقارير',
                    'تصدير الحضور والإجازات مباشرة لـ Google Sheets',
                    Icons.file_download_outlined,
                    () => context.go('/hr/reports'),
                    theme,
                  ),
                if (canAccessReports && kIsWeb)
                  _actionTile(
                    'مركز ملفات الشركة',
                    'إدارة المصادر والمخططات وصلاحيات الوصول',
                    Icons.cloud_sync_outlined,
                    () => context.go('/workspace'),
                    theme,
                  ),
                if (canAccessReports && kIsWeb)
                  _actionTile(
                    'تقارير ملفات الشركة',
                    'اكتشاف تقارير نشاط الملفات وتقارير HR المحمية',
                    Icons.folder_shared_outlined,
                    () => context.go('/hr/workspace-reports'),
                    theme,
                  ),
              ],
            ),
            const SizedBox(height: DsSpacing.xl),
            SectionHeader(
              title: 'أنظمة ومعطيات الشركة التشغيلية (Company OS)',
              actionLabel: 'عرض الكل',
              onAction: () => context.go('/company-os'),
            ),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: MediaQuery.sizeOf(context).width >= 1200 ? 4 : 2,
              crossAxisSpacing: DsSpacing.lg,
              mainAxisSpacing: DsSpacing.lg,
              childAspectRatio:
                  MediaQuery.sizeOf(context).width >= 1200 ? 1.45 : 1.3,
              children: [
                _actionTile(
                  'خدمات الشركة',
                  'بوابة التذاكر الذاتية وقاعدة المعرفة',
                  Icons.business_center_outlined,
                  () => context.go('/company-os'),
                  theme,
                ),
                _actionTile(
                  'عمليات IT والأصول',
                  'إدارة الدعم الفني والمعدات والاشتراكات',
                  Icons.support_agent_outlined,
                  () => context.go('/company-os/it'),
                  theme,
                ),
                _actionTile(
                  'عمليات الشركة والتدقيق',
                  'لوحة الأداء الشاملة وسجل التدقيق الفوري',
                  Icons.monitor_heart_outlined,
                  () => context.go('/company-os/operations'),
                  theme,
                ),
                _actionTile(
                  'محرر الهيكل التنظيمي',
                  'تخصيص القطاعات والأقسام والمدراء المباشرين',
                  Icons.account_tree_outlined,
                  () => context.go('/hr/organization-trees'),
                  theme,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
    ThemeData theme,
  ) {
    return WolfCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.sm,
        vertical: DsSpacing.xs,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: ZaWolfColors.primaryCyan, size: 26),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.titleMedium!.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall!.copyWith(
              fontSize: 9.5,
              color: ZaWolfColors.textSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Metrics row: up to four StatCards from existing data sources only.
class _HrMetricsRow extends StatelessWidget {
  final bool loadingCounts;
  final int employeesCount;
  final int locationsCount;
  final Future<DashboardAttendanceSummary> attendanceSummaryFuture;

  const _HrMetricsRow({
    required this.loadingCounts,
    required this.employeesCount,
    required this.locationsCount,
    required this.attendanceSummaryFuture,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: PendingRequestsService.instance.pendingCount,
      builder: (context, pendingCount, _) {
        return FutureBuilder<DashboardAttendanceSummary>(
          future: attendanceSummaryFuture,
          builder: (context, summarySnapshot) {
            final summary = summarySnapshot.data;
            final attendancePercent =
                summary?.percentOf(summary.attended).round();
            return Row(
              children: [
                Expanded(
                  child: StatCard(
                    icon: Icons.today_outlined,
                    value:
                        attendancePercent == null ? '—' : '$attendancePercent%',
                    label: 'حضور اليوم',
                    onTap: () => context.go('/hr/attendance-summary'),
                  ),
                ),
                const SizedBox(width: DsSpacing.md),
                Expanded(
                  child: StatCard(
                    icon: Icons.people_alt_outlined,
                    value: loadingCounts ? '—' : '$employeesCount',
                    label: 'الموظفون',
                  ),
                ),
                const SizedBox(width: DsSpacing.md),
                Expanded(
                  child: StatCard(
                    icon: Icons.rule_outlined,
                    value: '$pendingCount',
                    label: 'طلبات معلقة',
                    onTap: () {
                      final category =
                          PendingRequestsService.instance.firstPendingCategory;
                      context.go(
                        category == null
                            ? '/hr/requests?smart=true'
                            : '/hr/requests?category=$category',
                      );
                    },
                  ),
                ),
                const SizedBox(width: DsSpacing.md),
                Expanded(
                  child: StatCard(
                    icon: Icons.domain_outlined,
                    value: loadingCounts ? '—' : '$locationsCount',
                    label: 'الفروع النشطة',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
