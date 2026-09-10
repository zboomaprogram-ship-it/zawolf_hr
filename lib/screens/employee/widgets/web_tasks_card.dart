import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../components/wolf_card.dart';
import '../../../design_system/tokens.dart';
import '../../../models/task_model.dart';
import '../../../services/task_service.dart';
import '../../../theme/theme.dart';

/// Web dashboard card showing employee tasks with execution states and progress.
class WebTasksCard extends StatefulWidget {
  final String userId;
  final Stream<List<EmployeeTaskModel>>? taskStream;

  const WebTasksCard({super.key, required this.userId, this.taskStream});

  @override
  State<WebTasksCard> createState() => _WebTasksCardState();
}

class _WebTasksCardState extends State<WebTasksCard> {
  String _statusFilter = 'all'; // all, in_progress, done, late

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EmployeeTaskModel>>(
      stream: widget.taskStream ?? TaskService().watchMyTasks(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const WolfCard(
            child: SizedBox(
              height: 280,
              child: Center(
                child: CircularProgressIndicator(
                  color: ZaWolfColors.primaryCyan,
                ),
              ),
            ),
          );
        }

        final allTasks = snapshot.data ?? [];
        final filteredTasks =
            allTasks.where((task) {
              if (_statusFilter == 'all') return true;
              if (_statusFilter == 'in_progress') {
                return task.status == TaskStatus.inProgress ||
                    task.status == TaskStatus.newTask;
              }
              if (_statusFilter == 'done') {
                return task.status == TaskStatus.done;
              }
              if (_statusFilter == 'late') {
                return task.status == TaskStatus.late;
              }
              return true;
            }).toList();

        // Sort: active/late first, then recently completed
        filteredTasks.sort((a, b) {
          if (a.status == TaskStatus.late && b.status != TaskStatus.late) {
            return -1;
          }
          if (b.status == TaskStatus.late && a.status != TaskStatus.late) {
            return 1;
          }
          return b.dueDate.compareTo(a.dueDate);
        });

        final totalCount = allTasks.length;
        final inProgressCount =
            allTasks
                .where(
                  (t) =>
                      t.status == TaskStatus.inProgress ||
                      t.status == TaskStatus.newTask,
                )
                .length;
        final doneCount =
            allTasks.where((t) => t.status == TaskStatus.done).length;
        final lateCount =
            allTasks.where((t) => t.status == TaskStatus.late).length;

        return WolfCard(
          padding: const EdgeInsets.all(DsSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ZaWolfColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.checklist_rounded,
                      color: ZaWolfColors.warning,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: DsSpacing.md),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'متابعة تنفيذ المهام (Task Execution)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'مؤشرات وحالات تنفيذ المهام المسندة إليك',
                          style: TextStyle(
                            color: ZaWolfColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => context.go('/employee/tasks'),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('عرض الكل'),
                    style: TextButton.styleFrom(
                      foregroundColor: ZaWolfColors.primaryCyan,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DsSpacing.md),

              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('all', 'الكل ($totalCount)'),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'in_progress',
                      'قيد التنفيذ ($inProgressCount)',
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'late',
                      'متأخرة ($lateCount)',
                      isAlert: lateCount > 0,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip('done', 'مكتملة ($doneCount)'),
                  ],
                ),
              ),
              const SizedBox(height: DsSpacing.md),
              const Divider(height: 1, color: ZaWolfColors.surface03),
              const SizedBox(height: DsSpacing.md),

              // Task items list
              if (filteredTasks.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(
                        Icons.task_alt,
                        size: 40,
                        color: ZaWolfColors.textMuted.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _statusFilter == 'all'
                            ? 'لا توجد مهام مسندة إليك حالياً.'
                            : 'لا توجد مهام في هذا التصنيف.',
                        style: const TextStyle(
                          color: ZaWolfColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount:
                      filteredTasks.length > 5 ? 5 : filteredTasks.length,
                  separatorBuilder:
                      (context, index) => const Divider(
                        height: 16,
                        color: ZaWolfColors.surface02,
                      ),
                  itemBuilder: (context, index) {
                    final task = filteredTasks[index];
                    return _buildTaskRow(context, task);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(
    String filterKey,
    String label, {
    bool isAlert = false,
  }) {
    final isSelected = _statusFilter == filterKey;
    final color =
        isAlert
            ? ZaWolfColors.error
            : (isSelected ? ZaWolfColors.primaryCyan : ZaWolfColors.textMuted);

    return InkWell(
      onTap: () => setState(() => _statusFilter = filterKey),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? (isAlert
                      ? ZaWolfColors.error.withValues(alpha: 0.15)
                      : ZaWolfColors.primaryCyan.withValues(alpha: 0.12))
                  : ZaWolfColors.surface02,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : ZaWolfColors.surface03,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : ZaWolfColors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTaskRow(BuildContext context, EmployeeTaskModel task) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (task.status) {
      case TaskStatus.done:
        statusColor = ZaWolfColors.success;
        statusLabel = 'مكتملة';
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      case TaskStatus.inProgress:
        statusColor = ZaWolfColors.primaryCyan;
        statusLabel = 'قيد التنفيذ';
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case TaskStatus.late:
        statusColor = ZaWolfColors.error;
        statusLabel = 'متأخرة';
        statusIcon = Icons.warning_amber_rounded;
        break;
      default:
        statusColor = ZaWolfColors.warning;
        statusLabel = 'جديدة';
        statusIcon = Icons.fiber_new_rounded;
    }

    final formattedDueDate = DateFormat(
      'dd MMM yyyy',
      'ar',
    ).format(task.dueDate);

    // Execution rate if KPI metrics are tracked on this task
    final hasMetrics =
        task.cumulativeTarget != null && task.cumulativeTarget! > 0;
    final progress =
        hasMetrics
            ? ((task.cumulativeActual ?? 0) / task.cumulativeTarget!).clamp(
              0.0,
              1.0,
            )
            : (task.status == TaskStatus.done ? 1.0 : 0.0);

    return InkWell(
      onTap: () => context.go('/employee/tasks'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status indicator icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: statusColor, size: 18),
            ),
            const SizedBox(width: DsSpacing.md),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            decoration:
                                task.status == TaskStatus.done
                                    ? TextDecoration.lineThrough
                                    : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: DsSpacing.sm),
                      // Priority badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _priorityColor(
                            task.priority,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _priorityColor(
                              task.priority,
                            ).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          TaskPriority.arabicLabel(task.priority),
                          style: TextStyle(
                            color: _priorityColor(task.priority),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (task.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      task.description,
                      style: const TextStyle(
                        color: ZaWolfColors.textMuted,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),

                  // Progress & Due date line
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 13,
                        color:
                            task.status == TaskStatus.late
                                ? ZaWolfColors.error
                                : ZaWolfColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'موعد التسليم: $formattedDueDate',
                        style: TextStyle(
                          color:
                              task.status == TaskStatus.late
                                  ? ZaWolfColors.error
                                  : ZaWolfColors.textMuted,
                          fontSize: 11,
                          fontWeight:
                              task.status == TaskStatus.late
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                        ),
                      ),
                      if (hasMetrics) ...[
                        const SizedBox(width: DsSpacing.md),
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                '${(progress * 100).round()}% تم التنفيذ',
                                style: const TextStyle(
                                  color: ZaWolfColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: ZaWolfColors.surface03,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      statusColor,
                                    ),
                                    minHeight: 4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: DsSpacing.md),

            // Status chip badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case TaskPriority.urgent:
        return ZaWolfColors.error;
      case TaskPriority.high:
        return Colors.orangeAccent;
      case TaskPriority.low:
        return ZaWolfColors.textMuted;
      default:
        return ZaWolfColors.primaryCyan;
    }
  }
}
