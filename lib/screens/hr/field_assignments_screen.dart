import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../components/wolf_card.dart';
import '../../components/wolf_input_field.dart';
import '../../features/request_approval_routing/data/request_approval_routing_gateway.dart';
import '../../models/employee_role.dart';
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
  final _routingGateway = RequestApprovalRoutingGateway();
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  final _site = TextEditingController();
  List<UserModel> _employees = <UserModel>[];
  DateTime _date = DateTime.now();
  TimeOfDay _start = const TimeOfDay(hour: 12, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 17, minute: 0);
  bool _requiresReturn = false;
  bool _requiresCheckout = false;
  bool _saving = false;
  List<UserModel> _approvers = <UserModel>[];

  @override
  void dispose() {
    _reason.dispose();
    _site.dispose();
    super.dispose();
  }

  String _searchable(UserModel user) {
    final raw =
        '${user.displayName} ${user.employeeId} '
        '${user.department} ${user.email}';
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه');
  }

  String _normaliseQuery(String query) => query
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه');

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
    if (picked != null) {
      setState(() {
        if (start) {
          _start = picked;
        } else {
          _end = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _employees.isEmpty) {
      if (_employees.isEmpty) {
        _message('اختر موظفاً واحداً على الأقل.', error: true);
      }
      return;
    }
    if (_approvers.isEmpty) {
      _message('اختر مسؤول موافقة واحداً على الأقل.', error: true);
      return;
    }
    if (_time(_end).compareTo(_time(_start)) <= 0) {
      _message('وقت نهاية المهمة يجب أن يكون بعد وقت بدايتها.', error: true);
      return;
    }
    final currentUser =
        Provider.of<AuthService>(context, listen: false).currentUser;
    if (currentUser == null) return;
    setState(() => _saving = true);
    try {
      await _routingGateway.createFieldMission(
        employeeUids: _employees.map((employee) => employee.uid).toList(),
        approvers:
            _approvers
                .map((user) => {'id': user.uid, 'labelAr': user.displayName})
                .toList(),
        missionDate: DateFormat('yyyy-MM-dd').format(_date),
        startTime: _time(_start),
        endTime: _time(_end),
        reason: _reason.text,
        siteName: _site.text,
        requiresReturnToOffice: _requiresReturn,
        requiresCheckout: _requiresCheckout,
      );
      _message('تم إنشاء مأمورية مرتبطة لكل موظف وإشعارهم والمسؤول الأول.');
      setState(() {
        _reason.clear();
        _site.clear();
        _approvers = <UserModel>[];
        _employees = <UserModel>[];
      });
    } catch (error) {
      _message('تعذر حفظ المهمة: $error', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _chooseApprovers() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .where('isActive', isEqualTo: true)
            .get();
    final candidates =
        snapshot.docs
            .where((doc) {
              final user = UserModel.fromFirestore(doc);
              final scope = '${user.department} ${user.position}'.toLowerCase();
              final isAccounting =
                  doc.data()['isAdvanceAccountsApprover'] == true ||
                  scope.contains('account') ||
                  scope.contains('finance') ||
                  scope.contains('حساب') ||
                  scope.contains('مالي');
              return EmployeeRole.canActAsApprovalManager(user.role) ||
                  isAccounting;
            })
            .map(UserModel.fromFirestore)
            .where(
              (user) => !_employees.any((selected) => selected.uid == user.uid),
            )
            .toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));
    if (!mounted) return;
    var selected = List<UserModel>.from(_approvers);
    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('مسار الموافقات (بالترتيب)'),
                  content: SizedBox(
                    width: 520,
                    child: ListView(
                      shrinkWrap: true,
                      children:
                          candidates.map((user) {
                            final index = selected.indexWhere(
                              (item) => item.uid == user.uid,
                            );
                            return CheckboxListTile(
                              value: index >= 0,
                              title: Text(
                                '${user.displayName} — ${user.employeeId}',
                              ),
                              subtitle:
                                  index >= 0
                                      ? Text('المرحلة ${index + 1}')
                                      : null,
                              onChanged:
                                  (checked) => setDialogState(() {
                                    if (checked == true &&
                                        index < 0 &&
                                        selected.length < 4) {
                                      selected.add(user);
                                    } else if (checked != true && index >= 0) {
                                      selected.removeAt(index);
                                    }
                                  }),
                            );
                          }).toList(),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('إلغاء'),
                    ),
                    FilledButton(
                      onPressed: () {
                        setState(() => _approvers = selected);
                        Navigator.pop(dialogContext);
                      },
                      child: const Text('حفظ المسار'),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _chooseEmployees(List<UserModel> candidates) async {
    var selected = List<UserModel>.from(_employees);
    var query = '';
    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('الموظفون المشمولون بالمأمورية'),
                  content: SizedBox(
                    width: 520,
                    height: 480,
                    child: Column(
                      children: [
                        TextField(
                          autofocus: true,
                          textDirection: TextDirection.rtl,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText:
                                'ابحث بالاسم أو الكود أو القسم أو البريد الإلكتروني',
                          ),
                          onChanged:
                              (value) => setDialogState(
                                () => query = _normaliseQuery(value),
                              ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final filtered = candidates
                                  .where((user) {
                                    return query.isEmpty ||
                                        _searchable(user).contains(query);
                                  })
                                  .toList(growable: false);
                              if (filtered.isEmpty) {
                                return const Center(
                                  child: Text('لا توجد نتائج مطابقة.'),
                                );
                              }
                              return ListView(
                                children: filtered
                                    .map((user) {
                                      final selectedNow = selected.any(
                                        (item) => item.uid == user.uid,
                                      );
                                      return CheckboxListTile(
                                        value: selectedNow,
                                        title: Text(
                                          '${user.displayName} — ${user.employeeId}',
                                        ),
                                        subtitle: Text(
                                          '${user.department}${user.email.isEmpty ? '' : ' • ${user.email}'}',
                                          textDirection: TextDirection.rtl,
                                        ),
                                        onChanged:
                                            (checked) => setDialogState(() {
                                              if (checked == true &&
                                                  !selectedNow) {
                                                selected.add(user);
                                              } else if (checked != true) {
                                                selected.removeWhere(
                                                  (item) =>
                                                      item.uid == user.uid,
                                                );
                                              }
                                            }),
                                      );
                                    })
                                    .toList(growable: false),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('إلغاء'),
                    ),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _employees = selected;
                          // A mission recipient cannot also approve their own
                          // mission. Keep an already-configured route valid when HR
                          // changes the employee selection.
                          _approvers.removeWhere(
                            (approver) => selected.any(
                              (employee) => employee.uid == approver.uid,
                            ),
                          );
                        });
                        Navigator.pop(dialogContext);
                      },
                      child: const Text('حفظ الاختيار'),
                    ),
                  ],
                ),
          ),
    );
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
                    stream:
                        FirebaseFirestore.instance
                            .collection('users')
                            .where('isActive', isEqualTo: true)
                            .snapshots(),
                    builder: (context, snapshot) {
                      final employees =
                          snapshot.data?.docs
                              .map((doc) => UserModel.fromFirestore(doc))
                              .toList() ??
                          <UserModel>[];
                      return OutlinedButton.icon(
                        onPressed: () => _chooseEmployees(employees),
                        icon: const Icon(Icons.groups_outlined),
                        label: Text(
                          _employees.isEmpty
                              ? 'اختر الموظفين المشمولين بالمأمورية'
                              : '${_employees.length} موظف: ${_employees.map((user) => user.displayName).join('، ')}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.rtl,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _chooseApprovers,
                    icon: const Icon(Icons.account_tree_outlined),
                    label: Text(
                      _approvers.isEmpty
                          ? 'اختر مسار الموافقات (1–4)'
                          : 'مسار الموافقات: ${_approvers.map((user) => user.displayName).join(' ← ')}',
                      overflow: TextOverflow.ellipsis,
                    ),
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
                    validator:
                        (value) =>
                            (value?.trim().length ?? 0) >= 3
                                ? null
                                : 'اكتب سبباً واضحاً للمهمة',
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _requiresReturn,
                    onChanged:
                        (value) => setState(() => _requiresReturn = value),
                    title: const Text('يجب أن يعود الموظف إلى الفرع'),
                    subtitle: const Text(
                      'اتركه مغلقاً إذا كان مسموحاً له بالبقاء خارج الفرع حتى نهاية المهمة.',
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _requiresCheckout,
                    onChanged:
                        (value) => setState(() => _requiresCheckout = value),
                    title: const Text('يتطلب تسجيل انصراف'),
                    subtitle: const Text(
                      'عند إيقافه لن يُنشأ خصم عدم تسجيل الانصراف لهذا اليوم.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon:
                        _saving
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
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (assignments.isEmpty) {
                return const WolfCard(
                  child: Text(
                    'لا توجد مهام ميدانية لهذا اليوم.',
                    textDirection: TextDirection.rtl,
                  ),
                );
              }
              final actor =
                  Provider.of<AuthService>(context, listen: false).currentUser;
              return Column(
                children:
                    assignments
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
                                trailing:
                                    item.status == 'active'
                                        ? IconButton(
                                          icon: const Icon(
                                            Icons.cancel_outlined,
                                            color: ZaWolfColors.error,
                                          ),
                                          tooltip: 'إلغاء المهمة',
                                          onPressed:
                                              actor == null
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
