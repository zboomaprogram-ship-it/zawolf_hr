import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../components/wolf_button.dart';
import '../../components/wolf_input_field.dart';
import '../../models/employee_role.dart';
import '../../models/location_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/managed_employee_service.dart';
import '../../theme/theme.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  bool _initialized = false;
  bool _isLoading = false;
  bool _isLoadingAudience = true;
  UserModel? _actor;
  List<LocationModel> _locations = [];
  List<UserModel> _employees = [];
  List<String> _departments = [];
  final Set<String> _selectedEmployeeIds = {};
  final Set<String> _selectedDepartments = {};

  String _targetGroup = 'all';
  String? _selectedLocationId;
  String? _selectedLocationName;

  bool get _isScopedSender =>
      _actor?.role == EmployeeRole.manager ||
      _actor?.role == EmployeeRole.teamLeader;

  bool get _canPublish =>
      _actor != null && (EmployeeRole.isHr(_actor!.role) || _isScopedSender);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _actor = context.read<AuthService>().currentUser;
    _targetGroup = _isScopedSender ? 'team' : 'all';
    _loadAudience();
  }

  Future<void> _loadAudience() async {
    final actor = _actor;
    if (actor == null) {
      if (mounted) setState(() => _isLoadingAudience = false);
      return;
    }

    try {
      final employeeFuture = _isScopedSender
          ? ManagedEmployeeService().loadForReviewer(actor)
          : _fetchAllActiveEmployees();
      final results = await Future.wait<Object>([
        employeeFuture,
        if (!_isScopedSender) _fetchActiveLocations(),
        if (!_isScopedSender) _fetchDepartmentNames(),
      ]);
      final employees = results.first as List<UserModel>;
      final departmentNames = <String>{
        ...employees
            .map((employee) => employee.department.trim())
            .where((name) => name.isNotEmpty),
        if (!_isScopedSender) ...(results.last as List<String>),
      }.toList()..sort();

      if (!mounted) return;
      setState(() {
        _employees = employees;
        _departments = departmentNames;
        if (!_isScopedSender) {
          _locations = results[1] as List<LocationModel>;
        }
        _isLoadingAudience = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoadingAudience = false);
      _showError('تعذر تحميل الفئات المستهدفة. أعد المحاولة.');
    }
  }

  Future<List<UserModel>> _fetchAllActiveEmployees() async {
    final snapshot = await _db
        .collection('users')
        .where('isActive', isEqualTo: true)
        .get();
    final employees = snapshot.docs.map(UserModel.fromFirestore).toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    return employees;
  }

  Future<List<LocationModel>> _fetchActiveLocations() async {
    final snapshot = await _db
        .collection('locations')
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs.map(LocationModel.fromFirestore).toList();
  }

  Future<List<String>> _fetchDepartmentNames() async {
    final snapshot = await _db.collection('departments').orderBy('name').get();
    return snapshot.docs
        .map((doc) => (doc.data()['name'] as String? ?? '').trim())
        .where((name) => name.isNotEmpty)
        .toList();
  }

  Future<void> _selectEmployees() async {
    final workingSelection = Set<String>.from(_selectedEmployeeIds);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.78,
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    _isScopedSender ? 'اختر من فريقك' : 'اختر الموظفين',
                    textDirection: TextDirection.rtl,
                  ),
                  subtitle: Text(
                    'تم اختيار ${workingSelection.length}',
                    textDirection: TextDirection.rtl,
                  ),
                  trailing: TextButton(
                    onPressed: () => setSheetState(() {
                      if (workingSelection.length == _employees.length) {
                        workingSelection.clear();
                      } else {
                        workingSelection
                          ..clear()
                          ..addAll(_employees.map((employee) => employee.uid));
                      }
                    }),
                    child: Text(
                      workingSelection.length == _employees.length
                          ? 'إلغاء الكل'
                          : 'تحديد الكل',
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _employees.isEmpty
                      ? const Center(child: Text('لا يوجد موظفون مسندون إليك'))
                      : ListView.builder(
                          itemCount: _employees.length,
                          itemBuilder: (context, index) {
                            final employee = _employees[index];
                            return CheckboxListTile(
                              value: workingSelection.contains(employee.uid),
                              title: Text(
                                employee.displayName,
                                textDirection: TextDirection.rtl,
                              ),
                              subtitle: Text(
                                '${employee.employeeId} · ${employee.department}',
                                textDirection: TextDirection.rtl,
                              ),
                              onChanged: (selected) => setSheetState(() {
                                if (selected == true) {
                                  workingSelection.add(employee.uid);
                                } else {
                                  workingSelection.remove(employee.uid);
                                }
                              }),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedEmployeeIds
                          ..clear()
                          ..addAll(workingSelection);
                      });
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('تأكيد الاختيار'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectDepartments() async {
    final workingSelection = Set<String>.from(_selectedDepartments);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.72,
            child: Column(
              children: [
                ListTile(
                  title: const Text(
                    'اختر الأقسام والإدارات',
                    textDirection: TextDirection.rtl,
                  ),
                  subtitle: Text(
                    'تم اختيار ${workingSelection.length}',
                    textDirection: TextDirection.rtl,
                  ),
                  trailing: TextButton(
                    onPressed: () => setSheetState(() {
                      if (workingSelection.length == _departments.length) {
                        workingSelection.clear();
                      } else {
                        workingSelection
                          ..clear()
                          ..addAll(_departments);
                      }
                    }),
                    child: Text(
                      workingSelection.length == _departments.length
                          ? 'إلغاء الكل'
                          : 'تحديد الكل',
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _departments.isEmpty
                      ? const Center(child: Text('لا توجد أقسام مسجلة'))
                      : ListView.builder(
                          itemCount: _departments.length,
                          itemBuilder: (context, index) {
                            final department = _departments[index];
                            return CheckboxListTile(
                              value: workingSelection.contains(department),
                              title: Text(
                                department,
                                textDirection: TextDirection.rtl,
                              ),
                              onChanged: (selected) => setSheetState(() {
                                if (selected == true) {
                                  workingSelection.add(department);
                                } else {
                                  workingSelection.remove(department);
                                }
                              }),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedDepartments
                          ..clear()
                          ..addAll(workingSelection);
                      });
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('تأكيد الأقسام'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _targetItems() {
    if (_isScopedSender) {
      return [
        DropdownMenuItem(
          value: 'team',
          child: Text(
            _actor?.role == EmployeeRole.teamLeader
                ? 'جميع أعضاء فريقي'
                : 'جميع الموظفين المسندين إليّ',
          ),
        ),
        const DropdownMenuItem(
          value: 'selected',
          child: Text('اختيار موظف أو أكثر من فريقي'),
        ),
      ];
    }
    return const [
      DropdownMenuItem(value: 'all', child: Text('جميع الموظفين (الكل)')),
      DropdownMenuItem(
        value: 'selected',
        child: Text('موظف واحد أو عدة موظفين'),
      ),
      DropdownMenuItem(
        value: 'managers_only',
        child: Text('المدراء المباشرين فقط'),
      ),
      DropdownMenuItem(value: 'location', child: Text('فرع أو موقع محدد')),
      DropdownMenuItem(value: 'department', child: Text('قسم أو عدة أقسام')),
    ];
  }

  List<UserModel> _resolveRecipients() {
    var users = List<UserModel>.from(_employees);
    if (_targetGroup == 'managers_only') {
      users = users
          .where(
            (user) =>
                user.role == EmployeeRole.manager ||
                user.role == EmployeeRole.teamLeader,
          )
          .toList();
    } else if (_targetGroup == 'location' && _selectedLocationId != null) {
      users = users
          .where((user) => user.locationId == _selectedLocationId)
          .toList();
    } else if (_targetGroup == 'selected') {
      if (_selectedEmployeeIds.isEmpty) {
        throw Exception('اختر موظفاً واحداً على الأقل.');
      }
      users = users
          .where((user) => _selectedEmployeeIds.contains(user.uid))
          .toList();
    } else if (_targetGroup == 'department') {
      if (_selectedDepartments.isEmpty) {
        throw Exception('اختر قسماً واحداً على الأقل.');
      }
      final normalized = _selectedDepartments
          .map((name) => name.trim().toLowerCase())
          .toSet();
      users = users
          .where(
            (user) => normalized.contains(user.department.trim().toLowerCase()),
          )
          .toList();
    }
    return users;
  }

  Future<void> _publishAnnouncement() async {
    if (!_canPublish) {
      _showError('لا تملك صلاحية إرسال الإعلانات.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      if (_employees.isEmpty) await _loadAudience();
      final users = _resolveRecipients();
      if (users.isEmpty) {
        throw Exception('لا يوجد موظفون يطابقون الفئة المستهدفة.');
      }

      final actor = _actor!;
      final title = _titleController.text.trim();
      final body = _bodyController.text.trim();
      final recipientIds = users.map((user) => user.uid).toList();
      final globalAnnRef = _db.collection('announcements').doc();

      await globalAnnRef.set({
        'announcementId': globalAnnRef.id,
        'title': title,
        'body': body,
        'targetGroup': _targetGroup,
        'targetUserIds': recipientIds,
        'recipientCount': recipientIds.length,
        'audienceScope': _isScopedSender ? 'assigned_team' : 'organization',
        if (_targetGroup == 'location')
          'targetLocationName': _selectedLocationName,
        if (_targetGroup == 'department')
          'targetDepartments': _selectedDepartments.toList(),
        'createdBy': actor.uid,
        'createdByName': actor.displayName,
        'createdByRole': actor.role,
        'createdAt': FieldValue.serverTimestamp(),
      });

      const recipientsPerBatch = 200;
      for (
        var offset = 0;
        offset < users.length;
        offset += recipientsPerBatch
      ) {
        final end = (offset + recipientsPerBatch).clamp(0, users.length);
        final batch = _db.batch();
        for (final user in users.sublist(offset, end)) {
          final notifRef = _db
              .collection('notifications')
              .doc(user.uid)
              .collection('items')
              .doc();
          batch.set(notifRef, {
            'notificationId': notifRef.id,
            'type': 'hr_announcement',
            'title': 'إعلان إداري: $title',
            'body': body,
            'data': {
              'announcementId': globalAnnRef.id,
              'route': '/notifications',
            },
            'isRead': false,
            'pushSent': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
          batch.update(_db.collection('users').doc(user.uid), {
            'unreadNotifications': FieldValue.increment(1),
          });
        }
        await batch.commit();
      }

      _titleController.clear();
      _bodyController.clear();
      setState(() {
        _selectedEmployeeIds.clear();
        _selectedDepartments.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: ZaWolfColors.success,
            content: Text(
              'تم إرسال الإعلان للفئة المحددة بنجاح.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (error) {
      _showError(
        'خطأ أثناء نشر الإعلان: '
        '${error.toString().replaceAll('Exception: ', '')}',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: ZaWolfColors.error, content: Text(message)),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scopedLabel = _actor?.role == EmployeeRole.teamLeader
        ? 'إعلان للفريق'
        : 'إعلان للموظفين المسندين إليك';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isScopedSender ? scopedLabel : 'بث إعلان إداري',
          style: theme.textTheme.headlineMedium,
        ),
      ),
      body: _isLoadingAudience
          ? const Center(child: CircularProgressIndicator())
          : !_canPublish
          ? const Center(child: Text('لا تملك صلاحية الوصول لهذه الصفحة.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _isScopedSender
                          ? 'أرسل إعلاناً لجميع أعضاء فريقك أو لأعضاء محددين.'
                          : 'أرسل إعلاناً لجميع الموظفين أو اختر عدة أقسام أو موظفين.',
                      style: theme.textTheme.bodyMedium,
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 20),
                    if (!_isScopedSender) ...[
                      OutlinedButton.icon(
                        onPressed: () => context.go('/polls'),
                        icon: const Icon(Icons.assessment_outlined),
                        label: const Text('إنشاء تصويت وعرض النتائج'),
                      ),
                      const SizedBox(height: 20),
                    ],
                    DropdownButtonFormField<String>(
                      initialValue: _targetGroup,
                      decoration: const InputDecoration(
                        labelText: 'الفئة المستهدفة بالإعلان',
                        prefixIcon: Icon(
                          Icons.group,
                          color: ZaWolfColors.primaryCyan,
                        ),
                      ),
                      items: _targetItems(),
                      onChanged: (value) =>
                          setState(() => _targetGroup = value ?? _targetGroup),
                    ),
                    const SizedBox(height: 16),
                    if (_targetGroup == 'selected') ...[
                      OutlinedButton.icon(
                        onPressed: _selectEmployees,
                        icon: const Icon(Icons.people_alt_outlined),
                        label: Text(
                          _selectedEmployeeIds.isEmpty
                              ? 'اختيار الموظفين'
                              : 'المحددون: ${_selectedEmployeeIds.length}',
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_targetGroup == 'location') ...[
                      DropdownButtonFormField<String>(
                        initialValue: _selectedLocationId,
                        decoration: const InputDecoration(
                          labelText: 'اختر الفرع المستهدف',
                          prefixIcon: Icon(
                            Icons.location_on,
                            color: ZaWolfColors.primaryCyan,
                          ),
                        ),
                        items: _locations
                            .map(
                              (location) => DropdownMenuItem(
                                value: location.locationId,
                                child: Text(location.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedLocationId = value;
                            _selectedLocationName = _locations
                                .firstWhere(
                                  (location) => location.locationId == value,
                                )
                                .name;
                          });
                        },
                        validator: (value) =>
                            value == null ? 'يرجى اختيار الفرع المستهدف' : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_targetGroup == 'department') ...[
                      OutlinedButton.icon(
                        onPressed: _selectDepartments,
                        icon: const Icon(Icons.domain_outlined),
                        label: Text(
                          _selectedDepartments.isEmpty
                              ? 'اختيار قسم أو عدة أقسام'
                              : 'الأقسام المحددة: ${_selectedDepartments.length}',
                        ),
                      ),
                      if (_selectedDepartments.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedDepartments
                              .map(
                                (department) => InputChip(
                                  label: Text(department),
                                  onDeleted: () => setState(
                                    () =>
                                        _selectedDepartments.remove(department),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                    WolfInputField(
                      controller: _titleController,
                      labelText: 'عنوان الإعلان',
                      englishLabel: 'Announcement Title',
                      hintText: 'مثال: اجتماع الفريق الأسبوعي',
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'يرجى كتابة عنوان الإعلان'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    WolfInputField(
                      controller: _bodyController,
                      labelText: 'محتوى الإعلان التفصيلي',
                      englishLabel: 'Announcement Body',
                      hintText: 'اكتب تفاصيل الإعلان هنا...',
                      maxLines: 5,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'يرجى كتابة تفاصيل الإعلان'
                          : null,
                    ),
                    const SizedBox(height: 32),
                    WolfButton(
                      onPressed: _publishAnnouncement,
                      text: 'نشر وبث الإعلان الآن',
                      secondaryText: 'BROADCAST ANNOUNCEMENT',
                      loading: _isLoading,
                      height: 56,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
