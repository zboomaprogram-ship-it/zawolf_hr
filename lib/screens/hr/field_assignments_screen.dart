import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../components/wolf_card.dart';
import '../../components/wolf_input_field.dart';
import '../../models/field_assignment_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/field_assignment_service.dart';
import '../../theme/theme.dart';

class FieldAssignmentsScreen extends StatefulWidget {
  const FieldAssignmentsScreen({super.key});

  @override
  State<FieldAssignmentsScreen> createState() => _FieldAssignmentsScreenState();
}

class _FieldAssignmentsScreenState extends State<FieldAssignmentsScreen> {
  final _service = FieldAssignmentService();
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  final _site = TextEditingController();
  UserModel? _employee;
  DateTime _date = DateTime.now();
  TimeOfDay _start = const TimeOfDay(hour: 12, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 17, minute: 0);
  bool _requiresReturn = false;
  bool _requiresCheckout = false;
  bool _saving = false;

  @override
  void dispose() {
    _reason.dispose();
    _site.dispose();
    super.dispose();
  }

  String _time(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ar'),
    );
    if (date != null) setState(() => _date = date);
  }

  Future<void> _pickTime(bool start) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
    );
    if (picked != null)
      setState(() {
        if (start)
          _start = picked;
        else
          _end = picked;
      });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _employee == null) {
      if (_employee == null) _message('اختر الموظف أولاً.', error: true);
      return;
    }
    if (_time(_end).compareTo(_time(_start)) <= 0) {
      _message('وقت نهاية المهمة يجب أن يكون بعد وقت بدايتها.', error: true);
      return;
    }
    final currentUser = Provider.of<AuthService>(
      context,
      listen: false,
    ).currentUser;
    if (currentUser == null) return;
    setState(() => _saving = true);
    try {
      await _service.create(
        employee: _employee!,
        date: _date,
        startTime: _time(_start),
        endTime: _time(_end),
        reason: _reason.text,
        siteName: _site.text,
        requiresReturnToOffice: _requiresReturn,
        requiresCheckout: _requiresCheckout,
        createdBy: currentUser.uid,
      );
      _message('تم تسجيل المهمة الميدانية للموظف.');
      setState(() {
        _reason.clear();
        _site.clear();
      });
    } catch (error) {
      _message('تعذر حفظ المهمة: $error', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String value, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: error ? ZaWolfColors.error : ZaWolfColors.success,
        content: Text(value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('المهام الميدانية', style: theme.textTheme.headlineMedium),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          WolfCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'إضافة مهمة ميدانية بواسطة HR',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'تُستخدم عندما يسمح HR للموظف بالعمل خارج الفرع خلال وقت محدد، مثل انتقال فريق IT لموقع عميل.',
                    style: theme.textTheme.bodySmall,
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('isActive', isEqualTo: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final employees =
                          snapshot.data?.docs
                              .map((doc) => UserModel.fromFirestore(doc))
                              .toList() ??
                          <UserModel>[];
                      return DropdownButtonFormField<UserModel>(
                        value:
                            employees.any((user) => user.uid == _employee?.uid)
                            ? _employee
                            : null,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'الموظف'),
                        items: employees
                            .map(
                              (user) => DropdownMenuItem(
                                value: user,
                                child: Text(
                                  '${user.displayName} - ${user.employeeId}',
                                  overflow: TextOverflow.ellipsis,
                                  textDirection: TextDirection.rtl,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => _employee = value),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month),
                    label: Text(
                      DateFormat('EEEE yyyy/MM/dd', 'ar').format(_date),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickTime(true),
                          icon: const Icon(Icons.login),
                          label: Text('من ${_time(_start)}'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickTime(false),
                          icon: const Icon(Icons.logout),
                          label: Text('إلى ${_time(_end)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  WolfInputField(
                    controller: _site,
                    labelText: 'اسم الموقع الخارجي (اختياري)',
                    prefixIcon: Icons.place_outlined,
                  ),
                  const SizedBox(height: 12),
                  WolfInputField(
                    controller: _reason,
                    labelText: 'سبب المهمة',
                    prefixIcon: Icons.assignment_outlined,
                    maxLines: 3,
                    validator: (value) => (value?.trim().length ?? 0) >= 3
                        ? null
                        : 'اكتب سبباً واضحاً للمهمة',
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _requiresReturn,
                    onChanged: (value) =>
                        setState(() => _requiresReturn = value),
                    title: const Text('يجب أن يعود الموظف إلى الفرع'),
                    subtitle: const Text(
                      'اتركه مغلقاً إذا كان مسموحاً له بالبقاء خارج الفرع حتى نهاية المهمة.',
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _requiresCheckout,
                    onChanged: (value) =>
                        setState(() => _requiresCheckout = value),
                    title: const Text('يتطلب تسجيل انصراف'),
                    subtitle: const Text(
                      'عند إيقافه لن يُنشأ خصم عدم تسجيل الانصراف لهذا اليوم.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_task),
                    label: const Text('حفظ المهمة الميدانية'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'مهام اليوم',
            style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<FieldAssignmentModel>>(
            stream: _service.watchForDate(_date),
            builder: (context, snapshot) {
              final assignments = snapshot.data ?? <FieldAssignmentModel>[];
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (assignments.isEmpty)
                return const WolfCard(
                  child: Text(
                    'لا توجد مهام ميدانية لهذا اليوم.',
                    textDirection: TextDirection.rtl,
                  ),
                );
              final actor = Provider.of<AuthService>(
                context,
                listen: false,
              ).currentUser;
              return Column(
                children: assignments
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: WolfCard(
                          child: ListTile(
                            leading: const Icon(
                              Icons.directions_walk,
                              color: ZaWolfColors.primaryCyan,
                            ),
                            title: Text(
                              item.employeeName,
                              textDirection: TextDirection.rtl,
                            ),
                            subtitle: Text(
                              '${item.startTime} - ${item.endTime} | ${item.siteName.isEmpty ? item.reason : item.siteName}\n${item.requiresCheckout ? 'يتطلب انصراف' : 'لا يتطلب انصراف'}',
                              textDirection: TextDirection.rtl,
                            ),
                            trailing: item.status == 'active'
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.cancel_outlined,
                                      color: ZaWolfColors.error,
                                    ),
                                    tooltip: 'إلغاء المهمة',
                                    onPressed: actor == null
                                        ? null
                                        : () => _service.cancel(
                                            item.assignmentId,
                                            actor.uid,
                                          ),
                                  )
                                : const Text('ملغاة'),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
