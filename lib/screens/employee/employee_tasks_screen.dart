import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../components/wolf_card.dart';
import '../../models/task_model.dart';
import '../../services/auth_service.dart';
import '../../services/task_service.dart';
import '../../theme/theme.dart';

class EmployeeTasksScreen extends StatefulWidget {
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
        body: Center(
          child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('مهامي', style: theme.textTheme.headlineMedium),
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
            final isFutureKpiTask = task.dueDate.isAfter(endOfToday) &&
                (task.source == 'sales_analytics_api' ||
                    task.progressMode == 'cumulative_daily');
            final matchesStatus = switch (_statusFilter) {
              'open' =>
                !isFutureKpiTask &&
                task.status != TaskStatus.done &&
                    task.status != TaskStatus.cancelled,
              'done' => task.status == TaskStatus.done,
              'late' =>
                task.status == TaskStatus.late ||
                    (DateTime.now().isAfter(task.dueDate) &&
                        task.status != TaskStatus.done &&
                        task.status != TaskStatus.cancelled),
              _ => true,
            };
            return matchesSearch && matchesStatus;
          }).toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate));

          return RefreshIndicator(
            color: ZaWolfColors.primaryCyan,
            onRefresh: () async {},
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SummaryTile(
                        label: 'مفتوحة',
                        value: '$openTasks',
                        color: ZaWolfColors.warning,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryTile(
                        label: 'مكتملة',
                        value: '$doneTasks',
                        color: ZaWolfColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 16),
                if (filteredTasks.isEmpty)
                  WolfCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.task_alt,
                            size: 42,
                            color: ZaWolfColors.textMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            tasks.isEmpty
                                ? 'لا توجد مهام مسندة حالياً'
                                : 'لا توجد مهام تطابق الفلتر',
                            style: theme.textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
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
      builder: (ctx) => AlertDialog(
        backgroundColor: ZaWolfColors.surface01,
        title: const Text('إتمام المهمة', textDirection: TextDirection.rtl),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'هل تريد إرفاق رابط للمهمة؟ (جوجل درايف / دروب بوكس / الخ)',
              textDirection: TextDirection.rtl,
              style: TextStyle(color: ZaWolfColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: linkController,
              textDirection: TextDirection.ltr,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'https://...',
                labelText: 'رابط المرفق (اختياري)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
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
            child: const Text('تأكيد الإتمام'),
          ),
        ],
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
          Text(
            task.title,
            style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              _Chip(
                text: TaskPriority.arabicLabel(task.priority),
                color: _priorityColor(task.priority),
              ),
              _Chip(
                text: isOverdue
                    ? 'متأخرة'
                    : TaskStatus.arabicLabel(task.status),
                color: statusColor,
              ),
            ],
          ),
          if (task.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              task.description,
              style: theme.textTheme.bodyMedium,
              textDirection: TextDirection.rtl,
            ),
          ],
          if (task.source == 'sales_analytics_api' &&
              task.targetValue != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ZaWolfColors.primaryCyan.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: ZaWolfColors.primaryCyan.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                'هدف المرحلة ${task.milestoneNumber}: '
                '${task.targetValue!.toStringAsFixed(1)} ${task.targetUnit}',
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: ZaWolfColors.primaryCyan,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'آخر موعد: $dueText',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isOverdue ? ZaWolfColors.error : ZaWolfColors.textMuted,
            ),
            textDirection: TextDirection.rtl,
          ),
          if (task.qualityScore != null) ...[
            const SizedBox(height: 8),
            Text(
              'تقييم الجودة: ${task.qualityScore}/100',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: ZaWolfColors.perfGold,
              ),
              textDirection: TextDirection.rtl,
            ),
          ],
          if (task.attachmentUrl != null && task.attachmentUrl!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
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
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.link,
                  color: ZaWolfColors.primaryCyan,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  'المرفق:',
                  style: theme.textTheme.bodySmall,
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ],
          if (task.status != TaskStatus.done &&
              task.status != TaskStatus.cancelled) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: task.status == TaskStatus.inProgress
                        ? null
                        : onStart,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('بدء التنفيذ'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onDone,
                    icon: const Icon(Icons.check),
                    label: const Text('تم التنفيذ'),
                  ),
                ),
              ],
            ),
          ],
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
  final Color color;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZaWolfColors.surface03),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(label, style: theme.textTheme.bodySmall),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
