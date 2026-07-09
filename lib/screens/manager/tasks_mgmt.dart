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

class TasksManagementScreen extends StatefulWidget {
  const TasksManagementScreen({super.key});

  @override
  State<TasksManagementScreen> createState() => _TasksManagementScreenState();
}

class _TasksManagementScreenState extends State<TasksManagementScreen> {
  final TaskService _taskService = TaskService();
  String _filter = 'open';

  @override
  Widget build(BuildContext context) {
    final reviewer = context.watch<AuthService>().currentUser;
    final theme = Theme.of(context);

    if (reviewer == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('إدارة المهام', style: theme.textTheme.headlineMedium),
        actions: [
          IconButton(
            tooltip: 'إضافة مهمة',
            onPressed: () => _showCreateTaskSheet(context, reviewer),
            icon: const Icon(Icons.add_task, color: ZaWolfColors.primaryCyan),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
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
          final tasks = _filteredTasks(allTasks);
          final overdue = allTasks
              .where(
                (task) =>
                    DateTime.now().isAfter(task.dueDate) &&
                    task.status != TaskStatus.done &&
                    task.status != TaskStatus.cancelled,
              )
              .length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      label: 'مفتوحة',
                      value: allTasks
                          .where(
                            (task) =>
                                task.status != TaskStatus.done &&
                                task.status != TaskStatus.cancelled,
                          )
                          .length
                          .toString(),
                      color: ZaWolfColors.warning,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Metric(
                      label: 'متأخرة',
                      value: '$overdue',
                      color: ZaWolfColors.error,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Metric(
                      label: 'مكتملة',
                      value: allTasks
                          .where((task) => task.status == TaskStatus.done)
                          .length
                          .toString(),
                      color: ZaWolfColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'open', label: Text('مفتوحة')),
                  ButtonSegment(value: 'late', label: Text('متأخرة')),
                  ButtonSegment(value: 'done', label: Text('مكتملة')),
                  ButtonSegment(value: 'all', label: Text('الكل')),
                ],
                selected: {_filter},
                onSelectionChanged: (value) {
                  setState(() => _filter = value.first);
                },
              ),
              const SizedBox(height: 16),
              if (tasks.isEmpty)
                WolfCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Text(
                      'لا توجد مهام في هذا التصنيف',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                ...tasks.map(
                  (task) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ManagerTaskCard(
                      task: task,
                      onReview: () => _showReviewSheet(context, reviewer, task),
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
  }

  List<EmployeeTaskModel> _filteredTasks(List<EmployeeTaskModel> tasks) {
    final now = DateTime.now();
    switch (_filter) {
      case 'late':
        return tasks
            .where(
              (task) =>
                  now.isAfter(task.dueDate) &&
                  task.status != TaskStatus.done &&
                  task.status != TaskStatus.cancelled,
            )
            .toList();
      case 'done':
        return tasks.where((task) => task.status == TaskStatus.done).toList();
      case 'all':
        return tasks;
      default:
        return tasks
            .where(
              (task) =>
                  task.status != TaskStatus.done &&
                  task.status != TaskStatus.cancelled,
            )
            .toList();
    }
  }

  void _showCreateTaskSheet(BuildContext context, UserModel reviewer) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZaWolfColors.surface01,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (context) =>
          _CreateTaskSheet(reviewer: reviewer, taskService: _taskService),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (context) => _ReviewTaskSheet(
        reviewer: reviewer,
        task: task,
        taskService: _taskService,
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

    return WolfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            task.title,
            style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 6),
          Text(
            '${task.assigneeName} · ${task.department}',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.right,
          ),
          if (task.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(task.description, textDirection: TextDirection.rtl),
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
                const Icon(Icons.link, color: ZaWolfColors.primaryCyan, size: 16),
                const SizedBox(width: 4),
                Text(
                  'المرفق من الموظف:',
                  style: theme.textTheme.bodySmall,
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              _Chip(
                text: isOverdue
                    ? 'متأخرة'
                    : TaskStatus.arabicLabel(task.status),
                color: isOverdue
                    ? ZaWolfColors.error
                    : ZaWolfColors.primaryCyan,
              ),
              _Chip(
                text: TaskPriority.arabicLabel(task.priority),
                color: task.priority == TaskPriority.urgent
                    ? ZaWolfColors.error
                    : ZaWolfColors.warning,
              ),
              _Chip(text: dueText, color: ZaWolfColors.textSecondary),
              if (task.qualityScore != null)
                _Chip(
                  text: 'جودة ${task.qualityScore}/100',
                  color: ZaWolfColors.perfGold,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: task.status == TaskStatus.cancelled
                      ? null
                      : onCancel,
                  icon: const Icon(Icons.close),
                  label: const Text('إلغاء'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: task.status == TaskStatus.done ? onReview : null,
                  icon: const Icon(Icons.star_rate),
                  label: const Text('تقييم'),
                ),
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
                Text(
                  'مهمة جديدة',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<UserModel>(
                  initialValue: _selectedEmployee,
                  decoration: const InputDecoration(labelText: 'الموظف'),
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
                  labelText: 'الوصف',
                  prefixIcon: Icons.notes,
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _priority,
                  decoration: const InputDecoration(labelText: 'الأولوية'),
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
                  title: const Text('آخر موعد'),
                  subtitle: Text(
                    DateFormat('yyyy/MM/dd - hh:mm a').format(_dueDate),
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _pickDueDate,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('حفظ المهمة'),
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
        const SnackBar(content: Text('اختر الموظف واكتب عنواناً واضحاً.')),
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
          Text(
            'تقييم جودة التنفيذ',
            style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 14),
          Text(
            '${_score.round()}/100',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: ZaWolfColors.perfGold,
            ),
            textAlign: TextAlign.center,
          ),
          Slider(
            value: _score,
            min: 0,
            max: 100,
            divisions: 20,
            label: '${_score.round()}',
            onChanged: (value) => setState(() => _score = value),
          ),
          const SizedBox(height: 12),
          WolfInputField(
            controller: _comment,
            labelText: 'تعليق المدير',
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _saveReview,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('حفظ التقييم'),
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

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZaWolfColors.surface03),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(color: color),
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
