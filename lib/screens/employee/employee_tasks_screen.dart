import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../components/wolf_card.dart';
import '../../models/task_model.dart';
import '../../services/auth_service.dart';
import '../../services/task_service.dart';
import '../../theme/theme.dart';
import '../../design_system/components/rtl_navigation.dart';
import '../../design_system/components/skeletons.dart' show SkeletonList;

class EmployeeTasksScreen extends StatefulWidget {
  // Legacy fallback retained while work_outcomes_v2 is piloted and reversible.
  const EmployeeTasksScreen({super.key});

  @override
  State<EmployeeTasksScreen> createState() => _EmployeeTasksScreenState();
}

class _EmployeeTasksScreenState extends State<EmployeeTasksScreen> {
  final _searchController = TextEditingController();
  String _statusFilter = 'open';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final taskService = TaskService();
    final theme = Theme.of(context);

    if (user == null) {
      return const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(16),
          child: SkeletonList(itemCount: 4, itemHeight: 96),
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
              title: Text('مهامي اليومية والتشغيلية', style: theme.textTheme.headlineMedium),
            ),
            body: StreamBuilder<List<EmployeeTaskModel>>(
              stream: taskService.watchMyTasks(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
                  );
                }
                final tasks = snapshot.data ?? [];
                final openTasks = tasks
                    .where(
                      (task) =>
                          task.status != TaskStatus.done &&
                          task.status != TaskStatus.cancelled,
                    )
                    .length;
                final inProgressTasks = tasks
                    .where((task) => task.status == TaskStatus.inProgress)
                    .length;
                final lateTasks = tasks
                    .where(
                      (task) =>
                          (task.status == TaskStatus.late ||
                              DateTime.now().isAfter(task.dueDate)) &&
                          task.status != TaskStatus.done &&
                          task.status != TaskStatus.cancelled,
                    )
                    .length;
                final doneTasks = tasks
                    .where((task) => task.status == TaskStatus.done)
                    .length;

                final query = _searchController.text.trim().toLowerCase();
                final now = DateTime.now();
                final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
                final filteredTasks = tasks.where((task) {
                  final matchesSearch =
                      query.isEmpty ||
                      task.title.toLowerCase().contains(query) ||
                      task.description.toLowerCase().contains(query);
                  final isFutureKpiTask =
                      task.dueDate.isAfter(endOfToday) &&
                      (task.source == 'sales_analytics_api' ||
                          task.progressMode == 'cumulative_daily');
                  final matchesStatus = switch (_statusFilter) {
                    'open' =>
                      !isFutureKpiTask &&
                          task.status != TaskStatus.done &&
                          task.status != TaskStatus.cancelled,
                    'in_progress' => task.status == TaskStatus.inProgress,
                    'done' => task.status == TaskStatus.done,
                    'late' =>
                      task.status == TaskStatus.late ||
                          (DateTime.now().isAfter(task.dueDate) &&
                              task.status != TaskStatus.done &&
                              task.status != TaskStatus.cancelled),
                    _ => true,
                  };
                  return matchesSearch && matchesStatus;
                }).toList()
                  ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

                return RefreshIndicator(
                  color: ZaWolfColors.primaryCyan,
                  onRefresh: () async {},
                  child: ListView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 24 : 16,
                      vertical: 16,
                    ),
                    children: [
                      // Metric Tiles
                      if (isDesktop)
                        Row(
                          children: [
                            Expanded(
                              child: _SummaryTile(
                                label: 'مهام مفتوحة',
                                value: '$openTasks',
                                icon: Icons.pending_actions,
                                color: ZaWolfColors.warning,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SummaryTile(
                                label: 'قيد التنفيذ',
                                value: '$inProgressTasks',
                                icon: Icons.play_circle_outline,
                                color: ZaWolfColors.primaryCyan,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SummaryTile(
                                label: 'مهام متأخرة',
                                value: '$lateTasks',
                                icon: Icons.warning_amber_rounded,
                                color: ZaWolfColors.error,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SummaryTile(
                                label: 'مهام مكتملة',
                                value: '$doneTasks',
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
                              child: _SummaryTile(
                                label: 'مفتوحة',
                                value: '$openTasks',
                                icon: Icons.pending_actions,
                                color: ZaWolfColors.warning,
                                compact: true,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _SummaryTile(
                                label: 'جارية',
                                value: '$inProgressTasks',
                                icon: Icons.play_circle_outline,
                                color: ZaWolfColors.primaryCyan,
                                compact: true,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _SummaryTile(
                                label: 'متأخرة',
                                value: '$lateTasks',
                                icon: Icons.warning_amber_rounded,
                                color: ZaWolfColors.error,
                                compact: true,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _SummaryTile(
                                label: 'مكتملة',
                                value: '$doneTasks',
                                icon: Icons.check_circle_outline,
                                color: ZaWolfColors.success,
                                compact: true,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),

                      // Search & Filters
                      if (isDesktop)
                        Container(
                          padding: const EdgeInsets.all(12),
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
                                  textDirection: TextDirection.rtl,
                                  decoration: const InputDecoration(
                                    hintText: 'ابحث في عنوان أو تفاصيل المهمة...',
                                    prefixIcon: Icon(Icons.search, size: 20),
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(value: 'open', label: Text('المفتوحة')),
                                  ButtonSegment(value: 'in_progress', label: Text('قيد التنفيذ')),
                                  ButtonSegment(value: 'late', label: Text('المتأخرة')),
                                  ButtonSegment(value: 'done', label: Text('المكتملة')),
                                  ButtonSegment(value: 'all', label: Text('الكل')),
                                ],
                                selected: {_statusFilter},
                                showSelectedIcon: false,
                                onSelectionChanged: (value) =>
                                    setState(() => _statusFilter = value.first),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          textDirection: TextDirection.rtl,
                          decoration: const InputDecoration(
                            hintText: 'ابحث في عنوان أو وصف المهمة',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'open', label: Text('المفتوحة')),
                              ButtonSegment(value: 'in_progress', label: Text('قيد التنفيذ')),
                              ButtonSegment(value: 'late', label: Text('المتأخرة')),
                              ButtonSegment(value: 'done', label: Text('المكتملة')),
                              ButtonSegment(value: 'all', label: Text('الكل')),
                            ],
                            selected: {_statusFilter},
                            showSelectedIcon: false,
                            onSelectionChanged: (value) =>
                                setState(() => _statusFilter = value.first),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Task List or Responsive Grid
                      if (filteredTasks.isEmpty)
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
                                  tasks.isEmpty
                                      ? 'لا توجد مهام مسندة إليك حالياً'
                                      : 'لا توجد مهام تطابق هذا الفلتر',
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
                          user.uid,
                          filteredTasks,
                          taskService,
                          constraints.maxWidth,
                        )
                      else
                        ...filteredTasks.map(
                          (task) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _EmployeeTaskCard(
                              task: task,
                              onStart: () => taskService.updateMyTaskStatus(
                                taskId: task.taskId,
                                userId: user.uid,
                                status: TaskStatus.inProgress,
                              ),
                              onDone: () => _showCompleteDialog(
                                context: context,
                                taskId: task.taskId,
                                userId: user.uid,
                                taskService: taskService,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
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
    String userId,
    List<EmployeeTaskModel> tasks,
    TaskService taskService,
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
                  child: _EmployeeTaskCard(
                    task: task,
                    onStart: () => taskService.updateMyTaskStatus(
                      taskId: task.taskId,
                      userId: userId,
                      status: TaskStatus.inProgress,
                    ),
                    onDone: () => _showCompleteDialog(
                      context: context,
                      taskId: task.taskId,
                      userId: userId,
                      taskService: taskService,
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

  Future<void> _showCompleteDialog({
    required BuildContext context,
    required String taskId,
    required String userId,
    required TaskService taskService,
  }) async {
    final linkController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: ZaWolfColors.surface01,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('تأكيد إتمام المهمة'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'هل ترغب في إرفاق رابط للعمل المنجز؟ (جوجل درايف / دروب بوكس / رابط نظام)',
                  style: TextStyle(color: ZaWolfColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: linkController,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(color: ZaWolfColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'https://...',
                    labelText: 'رابط المرفق (اختياري)',
                    prefixIcon: Icon(Icons.link),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await taskService.updateMyTaskStatus(
                  taskId: taskId,
                  userId: userId,
                  status: TaskStatus.done,
                  attachmentUrl: linkController.text.trim().isNotEmpty
                      ? linkController.text.trim()
                      : null,
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: ZaWolfColors.success,
                foregroundColor: Colors.black,
              ),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('تأكيد الإتمام', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeTaskCard extends StatelessWidget {
  final EmployeeTaskModel task;
  final VoidCallback onStart;
  final VoidCallback onDone;

  const _EmployeeTaskCard({
    required this.task,
    required this.onStart,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverdue =
        DateTime.now().isAfter(task.dueDate) && task.status != TaskStatus.done;
    final statusColor = _statusColor(task.status, isOverdue);
    final dueText = DateFormat('yyyy/MM/dd - hh:mm a').format(task.dueDate);

    return WolfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: ZaWolfColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _Chip(
                text: isOverdue ? 'متأخرة' : TaskStatus.arabicLabel(task.status),
                color: statusColor,
              ),
              const SizedBox(width: 6),
              _Chip(
                text: TaskPriority.arabicLabel(task.priority),
                color: _priorityColor(task.priority),
              ),
            ],
          ),
          if (task.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              task.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: ZaWolfColors.textSecondary,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (task.source == 'sales_analytics_api' &&
              task.targetValue != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: ZaWolfColors.primaryCyan.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: ZaWolfColors.primaryCyan.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.analytics_outlined, color: ZaWolfColors.primaryCyan, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'هدف المرحلة ${task.milestoneNumber}: '
                      '${task.targetValue!.toStringAsFixed(1)} ${task.targetUnit}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ZaWolfColors.primaryCyan,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                  const Icon(Icons.link, color: ZaWolfColors.primaryCyan, size: 16),
                  const SizedBox(width: 6),
                  const Text('المرفق:', style: TextStyle(color: ZaWolfColors.textMuted, fontSize: 11)),
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
          Row(
            children: [
              Icon(
                Icons.schedule,
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
                    border: Border.all(color: ZaWolfColors.perfGold.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, color: ZaWolfColors.perfGold, size: 14),
                      const SizedBox(width: 2),
                      Text(
                        'جودة ${task.qualityScore}/100',
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
              if (task.status != TaskStatus.done &&
                  task.status != TaskStatus.cancelled) ...[
                if (task.status != TaskStatus.inProgress)
                  OutlinedButton.icon(
                    onPressed: onStart,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.play_arrow, size: 14),
                    label: const Text('بدء التنفيذ', style: TextStyle(fontSize: 12)),
                  ),
                const SizedBox(width: 6),
                FilledButton.icon(
                  onPressed: onDone,
                  style: FilledButton.styleFrom(
                    backgroundColor: ZaWolfColors.success,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  icon: const Icon(Icons.check, size: 14),
                  label: const Text(
                    'تم التنفيذ',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status, bool isOverdue) {
    if (isOverdue) return ZaWolfColors.error;
    switch (status) {
      case TaskStatus.done:
        return ZaWolfColors.success;
      case TaskStatus.inProgress:
        return ZaWolfColors.primaryCyan;
      case TaskStatus.cancelled:
        return ZaWolfColors.textMuted;
      default:
        return ZaWolfColors.warning;
    }
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case TaskPriority.urgent:
        return ZaWolfColors.error;
      case TaskPriority.high:
        return ZaWolfColors.warning;
      case TaskPriority.low:
        return ZaWolfColors.textSecondary;
      default:
        return ZaWolfColors.primaryCyan;
    }
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool compact;

  const _SummaryTile({
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
