import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../components/wolf_card.dart';
import '../../components/wolf_input_field.dart';
import '../../models/task_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/task_service.dart';
import '../../theme/theme.dart';
import '../../design_system/components/rtl_navigation.dart';
import '../../design_system/components/skeletons.dart' show SkeletonList;

class TasksManagementScreen extends StatefulWidget {
  // Legacy fallback retained while work_outcomes_v2 is piloted and reversible.
  const TasksManagementScreen({super.key});

  @override
  State<TasksManagementScreen> createState() => _TasksManagementScreenState();
}

class _TasksManagementScreenState extends State<TasksManagementScreen> {
  final TaskService _taskService = TaskService();
  final TextEditingController _searchController = TextEditingController();
  String _filter = 'open';
  String _assigneeFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reviewer = context.watch<AuthService>().currentUser;
    final theme = Theme.of(context);

    if (reviewer == null) {
      return const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(16),
          child: SkeletonList(itemCount: 5, itemHeight: 84),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;
          return Scaffold(
            appBar: AppBar(
              leading: Navigator.canPop(context)
                  ? IconButton(
                      icon: Icon(RtlNavigation.backIcon(context)),
                      tooltip: 'رجوع',
                      onPressed: () => Navigator.pop(context),
                    )
                  : null,
              title: Text('إدارة المهام', style: theme.textTheme.headlineMedium),
              actions: [
                IconButton(
                  tooltip: 'إضافة مهمة',
                  onPressed: () => _showCreateTaskSheet(context, reviewer),
                  icon: const Icon(Icons.add_task, color: ZaWolfColors.primaryCyan),
                ),
              ],
            ),
            floatingActionButton: isDesktop
                ? null
                : FloatingActionButton.extended(
                    onPressed: () => _showCreateTaskSheet(context, reviewer),
                    backgroundColor: ZaWolfColors.primaryCyan,
                    foregroundColor: Colors.black,
                    icon: const Icon(Icons.add),
                    label: const Text('مهمة جديدة'),
                  ),
            body: StreamBuilder<List<EmployeeTaskModel>>(
              stream: _taskService.watchManagedTasks(reviewer),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
                  );
                }
                final allTasks = snapshot.data ?? [];
                final assignees = <String, String>{
                  for (final task in allTasks) task.assigneeId: task.assigneeName,
                };
                final tasks = _filteredTasks(allTasks);

                final openCount = allTasks
                    .where(
                      (task) =>
                          task.status != TaskStatus.done &&
                          task.status != TaskStatus.cancelled,
                    )
                    .length;
                final inProgressCount = allTasks
                    .where((task) => task.status == TaskStatus.inProgress)
                    .length;
                final overdueCount = allTasks
                    .where(
                      (task) =>
                          DateTime.now().isAfter(task.dueDate) &&
                          task.status != TaskStatus.done &&
                          task.status != TaskStatus.cancelled,
                    )
                    .length;
                final doneCount = allTasks
                    .where((task) => task.status == TaskStatus.done)
                    .length;

                return ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 24 : 16,
                    vertical: 16,
                  ),
                  children: [
                    // Summary metric cards
                    if (isDesktop)
                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              label: 'المهام المفتوحة',
                              value: '$openCount',
                              icon: Icons.pending_actions,
                              color: ZaWolfColors.warning,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MetricCard(
                              label: 'قيد التنفيذ',
                              value: '$inProgressCount',
                              icon: Icons.play_circle_outline,
                              color: ZaWolfColors.primaryCyan,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MetricCard(
                              label: 'مهام متأخرة',
                              value: '$overdueCount',
                              icon: Icons.warning_amber_rounded,
                              color: ZaWolfColors.error,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MetricCard(
                              label: 'مكتملة',
                              value: '$doneCount',
                              icon: Icons.check_circle_outline,
                              color: ZaWolfColors.success,
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              label: 'مفتوحة',
                              value: '$openCount',
                              icon: Icons.pending_actions,
                              color: ZaWolfColors.warning,
                              compact: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MetricCard(
                              label: 'قيد التنفيذ',
                              value: '$inProgressCount',
                              icon: Icons.play_circle_outline,
                              color: ZaWolfColors.primaryCyan,
                              compact: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MetricCard(
                              label: 'متأخرة',
                              value: '$overdueCount',
                              icon: Icons.warning_amber_rounded,
                              color: ZaWolfColors.error,
                              compact: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MetricCard(
                              label: 'مكتملة',
                              value: '$doneCount',
                              icon: Icons.check_circle_outline,
                              color: ZaWolfColors.success,
                              compact: true,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),

                    // Filter toolbar
                    if (isDesktop)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: ZaWolfColors.surface01,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ZaWolfColors.surface03),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _searchController,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.search, size: 20),
                                  hintText: 'بحث بالموظف أو عنوان المهمة أو الوصف',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                initialValue: assignees.containsKey(_assigneeFilter)
                                    ? _assigneeFilter
                                    : 'all',
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.person_search, size: 20),
                                  labelText: 'الموظف المسؤول',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: 'all',
                                    child: Text('جميع الموظفين'),
                                  ),
                                  ...assignees.entries.map(
                                    (entry) => DropdownMenuItem(
                                      value: entry.key,
                                      child: Text(
                                        entry.value,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (value) =>
                                    setState(() => _assigneeFilter = value ?? 'all'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(value: 'open', label: Text('مفتوحة')),
                                ButtonSegment(value: 'in_progress', label: Text('جارية')),
                                ButtonSegment(value: 'late', label: Text('متأخرة')),
                                ButtonSegment(value: 'done', label: Text('مكتملة')),
                                ButtonSegment(value: 'all', label: Text('الكل')),
                              ],
                              selected: {_filter},
                              showSelectedIcon: false,
                              onSelectionChanged: (value) {
                                setState(() => _filter = value.first);
                              },
                            ),
                            const SizedBox(width: 12),
                            FilledButton.icon(
                              onPressed: () => _showCreateTaskSheet(context, reviewer),
                              style: FilledButton.styleFrom(
                                backgroundColor: ZaWolfColors.primaryCyan,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text(
                                'مهمة جديدة',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search, size: 20),
                                hintText: 'بحث بالموظف أو المهمة',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: assignees.containsKey(_assigneeFilter)
                                  ? _assigneeFilter
                                  : 'all',
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.person_search, size: 18),
                                labelText: 'الموظف',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: 'all',
                                  child: Text('الكل'),
                                ),
                                ...assignees.entries.map(
                                  (entry) => DropdownMenuItem(
                                    value: entry.key,
                                    child: Text(
                                      entry.value,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _assigneeFilter = value ?? 'all'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'open', label: Text('مفتوحة')),
                            ButtonSegment(value: 'in_progress', label: Text('جارية')),
                            ButtonSegment(value: 'late', label: Text('متأخرة')),
                            ButtonSegment(value: 'done', label: Text('مكتملة')),
                            ButtonSegment(value: 'all', label: Text('الكل')),
                          ],
                          selected: {_filter},
                          showSelectedIcon: false,
                          onSelectionChanged: (value) {
                            setState(() => _filter = value.first);
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Empty state or task list/grid
                    if (tasks.isEmpty)
                      WolfCard(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.task_alt,
                                size: 48,
                                color: ZaWolfColors.textMuted,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'لا توجد مهام في هذا التصنيف',
                                style: theme.textTheme.titleMedium,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (isDesktop)
                      _buildDesktopTaskGrid(
                        context,
                        reviewer,
                        tasks,
                        constraints.maxWidth,
                      )
                    else
                      ...tasks.map(
                        (task) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ManagerTaskCard(
                            task: task,
                            onReview: () =>
                                _showReviewSheet(context, reviewer, task),
                            onCancel: () => _taskService.cancelTask(
                              taskId: task.taskId,
                              reviewer: reviewer,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildDesktopTaskGrid(
    BuildContext context,
    UserModel reviewer,
    List<EmployeeTaskModel> tasks,
    double maxWidth,
  ) {
    final columnCount = maxWidth >= 1350 ? 3 : 2;
    final columns = List.generate(
      columnCount,
      (_) => <EmployeeTaskModel>[],
    );

    for (var i = 0; i < tasks.length; i++) {
      columns[i % columnCount].add(tasks[i]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var colIdx = 0; colIdx < columnCount; colIdx++) ...[
          if (colIdx > 0) const SizedBox(width: 14),
          Expanded(
            child: Column(
              children: columns[colIdx].map(
                (task) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _ManagerTaskCard(
                    task: task,
                    onReview: () => _showReviewSheet(context, reviewer, task),
                    onCancel: () => _taskService.cancelTask(
                      taskId: task.taskId,
                      reviewer: reviewer,
                    ),
                  ),
                ),
              ).toList(),
            ),
          ),
        ],
      ],
    );
  }

  List<EmployeeTaskModel> _filteredTasks(List<EmployeeTaskModel> tasks) {
    final now = DateTime.now();
    final query = _searchController.text.trim().toLowerCase();
    final scoped = tasks.where((task) {
      if (_assigneeFilter != 'all' && task.assigneeId != _assigneeFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      return task.title.toLowerCase().contains(query) ||
          task.assigneeName.toLowerCase().contains(query) ||
          task.description.toLowerCase().contains(query);
    }).toList();

    switch (_filter) {
      case 'in_progress':
        return scoped
            .where(
              (task) =>
                  task.status == TaskStatus.inProgress &&
                  task.status != TaskStatus.cancelled,
            )
            .toList();
      case 'late':
        return scoped
            .where(
              (task) =>
                  now.isAfter(task.dueDate) &&
                  task.status != TaskStatus.done &&
                  task.status != TaskStatus.cancelled,
            )
            .toList();
      case 'done':
        return scoped.where((task) => task.status == TaskStatus.done).toList();
      case 'all':
        final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return scoped.where((task) {
          final isFutureKpiTask =
              task.dueDate.isAfter(endOfToday) &&
              (task.source == 'sales_analytics_api' ||
                  task.progressMode == 'cumulative_daily' ||
                  task.periodKey.isNotEmpty);
          return !isFutureKpiTask;
        }).toList();
      default: // 'open'
        final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return scoped.where((task) {
          final isFutureKpiTask =
              task.dueDate.isAfter(endOfToday) &&
              (task.source == 'sales_analytics_api' ||
                  task.progressMode == 'cumulative_daily' ||
                  task.periodKey.isNotEmpty);
          return !isFutureKpiTask &&
              task.status != TaskStatus.done &&
              task.status != TaskStatus.cancelled;
        }).toList();
    }
  }

  void _showCreateTaskSheet(BuildContext context, UserModel reviewer) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZaWolfColors.surface01,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: _CreateTaskSheet(reviewer: reviewer, taskService: _taskService),
        ),
      ),
    );
  }

  void _showReviewSheet(
    BuildContext context,
    UserModel reviewer,
    EmployeeTaskModel task,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZaWolfColors.surface01,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: _ReviewTaskSheet(
            reviewer: reviewer,
            task: task,
            taskService: _taskService,
          ),
        ),
      ),
    );
  }
}

class _ManagerTaskCard extends StatelessWidget {
  final EmployeeTaskModel task;
  final VoidCallback onReview;
  final VoidCallback onCancel;

  const _ManagerTaskCard({
    required this.task,
    required this.onReview,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverdue =
        DateTime.now().isAfter(task.dueDate) && task.status != TaskStatus.done;
    final dueText = DateFormat('yyyy/MM/dd - hh:mm a').format(task.dueDate);

    Color statusColor;
    String statusLabel;
    if (isOverdue) {
      statusColor = ZaWolfColors.error;
      statusLabel = 'متأخرة';
    } else if (task.status == TaskStatus.done) {
      statusColor = ZaWolfColors.success;
      statusLabel = 'مكتملة';
    } else if (task.status == TaskStatus.inProgress) {
      statusColor = ZaWolfColors.primaryCyan;
      statusLabel = 'قيد التنفيذ';
    } else if (task.status == TaskStatus.cancelled) {
      statusColor = ZaWolfColors.textMuted;
      statusLabel = 'ملغاة';
    } else {
      statusColor = ZaWolfColors.warning;
      statusLabel = 'جديدة';
    }

    Color priorityColor;
    if (task.priority == TaskPriority.urgent) {
      priorityColor = ZaWolfColors.error;
    } else if (task.priority == TaskPriority.high) {
      priorityColor = ZaWolfColors.warning;
    } else {
      priorityColor = ZaWolfColors.primaryCyan;
    }

    return WolfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Title & Badges
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _Chip(text: statusLabel, color: statusColor),
              const SizedBox(width: 6),
              _Chip(
                text: TaskPriority.arabicLabel(task.priority),
                color: priorityColor,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Assignee & Department row
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: ZaWolfColors.primaryCyan.withValues(alpha: 0.15),
                child: Text(
                  task.assigneeName.isNotEmpty ? task.assigneeName[0] : '?',
                  style: const TextStyle(
                    color: ZaWolfColors.primaryCyan,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${task.assigneeName} · ${task.department}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: ZaWolfColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Description
          if (task.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              task.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: ZaWolfColors.textMuted,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Attachment link
          if (task.attachmentUrl != null && task.attachmentUrl!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: ZaWolfColors.surface02,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: ZaWolfColors.surface03),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.link,
                    color: ZaWolfColors.primaryCyan,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'مرفق الموظف:',
                    style: TextStyle(
                      color: ZaWolfColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      task.attachmentUrl!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ZaWolfColors.primaryCyan,
                        decoration: TextDecoration.underline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1, color: ZaWolfColors.surface03),
          const SizedBox(height: 10),

          // Due date, Quality, & Actions
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: isOverdue ? ZaWolfColors.error : ZaWolfColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                dueText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isOverdue ? ZaWolfColors.error : ZaWolfColors.textMuted,
                  fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (task.qualityScore != null) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: ZaWolfColors.perfGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: ZaWolfColors.perfGold.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: ZaWolfColors.perfGold,
                        size: 14,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${task.qualityScore}/100',
                        style: const TextStyle(
                          color: ZaWolfColors.perfGold,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              if (task.status != TaskStatus.cancelled)
                TextButton.icon(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: ZaWolfColors.textMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.close, size: 14),
                  label: const Text('إلغاء', style: TextStyle(fontSize: 12)),
                ),
              if (task.status == TaskStatus.done)
                FilledButton.icon(
                  onPressed: onReview,
                  style: FilledButton.styleFrom(
                    backgroundColor: ZaWolfColors.perfGold.withValues(alpha: 0.2),
                    foregroundColor: ZaWolfColors.perfGold,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  icon: const Icon(Icons.star_rate, size: 14),
                  label: const Text('تقييم', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreateTaskSheet extends StatefulWidget {
  final UserModel reviewer;
  final TaskService taskService;

  const _CreateTaskSheet({required this.reviewer, required this.taskService});

  @override
  State<_CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends State<_CreateTaskSheet> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  late final Future<List<UserModel>> _employeesFuture;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  String _priority = TaskPriority.medium;
  UserModel? _selectedEmployee;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _employeesFuture = widget.taskService.loadAssignableEmployees(
      widget.reviewer,
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, inset + 16),
      child: FutureBuilder<List<UserModel>>(
        future: _employeesFuture,
        builder: (context, snapshot) {
          final employees = snapshot.data ?? [];
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'مهمة جديدة',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: ZaWolfColors.textMuted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<UserModel>(
                  initialValue: _selectedEmployee,
                  decoration: const InputDecoration(
                    labelText: 'الموظف المسند إليه',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  items: employees
                      .map(
                        (user) => DropdownMenuItem(
                          value: user,
                          child: Text(
                            '${user.displayName} · ${user.department}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedEmployee = value),
                ),
                const SizedBox(height: 12),
                WolfInputField(
                  controller: _title,
                  labelText: 'عنوان المهمة',
                  prefixIcon: Icons.task_alt,
                ),
                const SizedBox(height: 12),
                WolfInputField(
                  controller: _description,
                  labelText: 'تفاصيل ومطلوب المهمة',
                  prefixIcon: Icons.notes,
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _priority,
                  decoration: const InputDecoration(
                    labelText: 'مستوى الأولوية',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: TaskPriority.low,
                      child: Text('منخفضة'),
                    ),
                    DropdownMenuItem(
                      value: TaskPriority.medium,
                      child: Text('متوسطة'),
                    ),
                    DropdownMenuItem(
                      value: TaskPriority.high,
                      child: Text('عالية'),
                    ),
                    DropdownMenuItem(
                      value: TaskPriority.urgent,
                      child: Text('عاجلة'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _priority = value);
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('تاريخ ووقت الاستحقاق'),
                  subtitle: Text(
                    DateFormat('yyyy/MM/dd - hh:mm a').format(_dueDate),
                    style: const TextStyle(color: ZaWolfColors.primaryCyan),
                  ),
                  trailing: const Icon(
                    Icons.calendar_today,
                    color: ZaWolfColors.primaryCyan,
                  ),
                  onTap: _pickDueDate,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: ZaWolfColors.primaryCyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: const Text(
                    'إنشاء المهمة',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueDate),
    );
    if (time == null) return;
    setState(() {
      _dueDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    final employee = _selectedEmployee;
    if (employee == null || _title.text.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر الموظف واكتب عنواناً واضحاً للمهمة.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.taskService.createTask(
        creator: widget.reviewer,
        assignee: employee,
        title: _title.text,
        description: _description.text,
        dueDate: _dueDate,
        priority: _priority,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ReviewTaskSheet extends StatefulWidget {
  final UserModel reviewer;
  final EmployeeTaskModel task;
  final TaskService taskService;

  const _ReviewTaskSheet({
    required this.reviewer,
    required this.task,
    required this.taskService,
  });

  @override
  State<_ReviewTaskSheet> createState() => _ReviewTaskSheetState();
}

class _ReviewTaskSheetState extends State<_ReviewTaskSheet> {
  final _comment = TextEditingController();
  double _score = 85;
  bool _saving = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, inset + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تقييم جودة التنفيذ',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: ZaWolfColors.textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${_score.round()}/100',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: ZaWolfColors.perfGold,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          Slider(
            value: _score,
            min: 0,
            max: 100,
            divisions: 20,
            activeColor: ZaWolfColors.perfGold,
            label: '${_score.round()}',
            onChanged: (value) => setState(() => _score = value),
          ),
          const SizedBox(height: 12),
          WolfInputField(
            controller: _comment,
            labelText: 'ملاحظات أو تعليق المدير',
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _saveReview,
            style: FilledButton.styleFrom(
              backgroundColor: ZaWolfColors.perfGold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Icon(Icons.save),
            label: const Text(
              'حفظ التقييم',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveReview() async {
    setState(() => _saving = true);
    try {
      await widget.taskService.reviewTask(
        taskId: widget.task.taskId,
        reviewer: widget.reviewer,
        qualityScore: _score.round(),
        comment: _comment.text,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ZaWolfColors.error,
          content: Text(
            'فشل حفظ التقييم: ${e.toString().replaceAll('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool compact;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: compact ? 10 : 14,
        horizontal: compact ? 8 : 16,
      ),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: compact
          ? Column(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: ZaWolfColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;

  const _Chip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
