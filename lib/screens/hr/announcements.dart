import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../components/wolf_button.dart';
import '../../components/wolf_input_field.dart';
import '../../models/location_model.dart';
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
  final _departmentController = TextEditingController();

  bool _isLoading = false;
  List<LocationModel> _locations = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _employees = [];
  final Set<String> _selectedEmployeeIds = {};

  String _targetGroup = 'all'; // all | managers_only | location | department
  String? _selectedLocationId;
  String? _selectedLocationName;

  @override
  void initState() {
    super.initState();
    _fetchLocations();
    _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    try {
      final snapshot = await _db
          .collection('users')
          .where('isActive', isEqualTo: true)
          .get();
      if (!mounted) return;
      setState(() {
        _employees = snapshot.docs
          ..sort((a, b) {
            final left = a.data()['displayName'] as String? ?? '';
            final right = b.data()['displayName'] as String? ?? '';
            return left.compareTo(right);
          });
      });
    } catch (_) {}
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
                  title: const Text(
                    'اختر الموظفين',
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
                          ..addAll(_employees.map((doc) => doc.id));
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
                  child: ListView.builder(
                    itemCount: _employees.length,
                    itemBuilder: (context, index) {
                      final employee = _employees[index];
                      final data = employee.data();
                      return CheckboxListTile(
                        value: workingSelection.contains(employee.id),
                        title: Text(
                          data['displayName'] as String? ?? 'موظف',
                          textDirection: TextDirection.rtl,
                        ),
                        subtitle: Text(
                          '${data['employeeId'] ?? ''} · ${data['department'] ?? ''}',
                          textDirection: TextDirection.rtl,
                        ),
                        onChanged: (selected) => setSheetState(() {
                          if (selected == true) {
                            workingSelection.add(employee.id);
                          } else {
                            workingSelection.remove(employee.id);
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

  Future<void> _fetchLocations() async {
    try {
      final locSnap = await _db
          .collection('locations')
          .where('isActive', isEqualTo: true)
          .get();
      setState(() {
        _locations = locSnap.docs
            .map((doc) => LocationModel.fromFirestore(doc))
            .toList();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  Future<void> _publishAnnouncement() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    final deptFilter = _departmentController.text.trim();

    try {
      // The active directory is loaded once for selection. Filtering locally
      // avoids fragile composite indexes and keeps one/many/all identical.
      var users = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
        _employees,
      );
      if (users.isEmpty) {
        await _fetchEmployees();
        users = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
          _employees,
        );
      }
      if (_targetGroup == 'managers_only') {
        users = users.where((doc) => doc.data()['role'] == 'manager').toList();
      } else if (_targetGroup == 'location' && _selectedLocationId != null) {
        users = users
            .where((doc) => doc.data()['locationId'] == _selectedLocationId)
            .toList();
      }

      if (_targetGroup == 'selected') {
        if (_selectedEmployeeIds.isEmpty) {
          throw Exception('اختر موظفاً واحداً على الأقل.');
        }
        users = users
            .where((doc) => _selectedEmployeeIds.contains(doc.id))
            .toList();
      }

      // Filter by department client side
      if (_targetGroup == 'department' && deptFilter.isNotEmpty) {
        users = users.where((doc) {
          final data = doc.data();
          final userDept = data['department'] as String? ?? '';
          return userDept.toLowerCase() == deptFilter.toLowerCase();
        }).toList();
      }

      if (users.isEmpty) {
        throw Exception('لا يوجد موظفون مسجلون يطابقون الفئة المستهدفة.');
      }

      // Write to global announcements history for archival/future views
      final globalAnnRef = _db.collection('announcements').doc();
      await globalAnnRef.set({
        'announcementId': globalAnnRef.id,
        'title': title,
        'body': body,
        'targetGroup': _targetGroup,
        if (_targetGroup == 'selected')
          'targetUserIds': _selectedEmployeeIds.toList(),
        'recipientCount': users.length,
        if (_targetGroup == 'location')
          'targetLocationName': _selectedLocationName,
        if (_targetGroup == 'department') 'targetDepartment': deptFilter,
        'createdBy': FirebaseAuth.instance.currentUser?.uid ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Each recipient needs two writes. Chunking keeps every Firestore batch
      // comfortably below the 500-operation limit.
      const recipientsPerBatch = 200;
      for (
        var offset = 0;
        offset < users.length;
        offset += recipientsPerBatch
      ) {
        final end = (offset + recipientsPerBatch).clamp(0, users.length);
        final batch = _db.batch();
        for (final userDoc in users.sublist(offset, end)) {
          final userId = userDoc.id;
          final notifRef = _db
              .collection('notifications')
              .doc(userId)
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
          batch.update(_db.collection('users').doc(userId), {
            'unreadNotifications': FieldValue.increment(1),
          });
        }
        await batch.commit();
      }

      _titleController.clear();
      _bodyController.clear();
      _departmentController.clear();

      if (mounted) {
        String successMsg = 'تم نشر وبث الإعلان للفئة المستهدفة بنجاح. 📢';
        if (_targetGroup == 'all') {
          successMsg = 'تم نشر وبث الإعلان العام لجميع الموظفين بنجاح. 📢';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZaWolfColors.success,
            content: Text(
              successMsg,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZaWolfColors.error,
            content: Text(
              'خطأ أثناء نشر الإعلان: ${e.toString().replaceAll('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('بث إعلان إداري', style: theme.textTheme.headlineMedium),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'نشر إشعار إداري مستهدف',
                style: theme.textTheme.titleLarge!.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 4),
              Text(
                'يمكنك نشر الإعلان وبثه لجميع الموظفين، أو لفرع محدد، أو إدارة معينة، أو المدراء فقط.',
                style: theme.textTheme.bodyMedium,
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 24),

              OutlinedButton.icon(
                onPressed: () => context.go('/polls'),
                icon: const Icon(Icons.assessment_outlined),
                label: const Text('إنشاء تصويت وعرض النتائج'),
              ),
              const SizedBox(height: 20),

              // Target Selector Dropdown
              DropdownButtonFormField<String>(
                initialValue: _targetGroup,
                decoration: const InputDecoration(
                  labelText: 'الفئة المستهدفة بالإعلان',
                  prefixIcon: Icon(
                    Icons.group,
                    color: ZaWolfColors.primaryCyan,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text('جميع الموظفين (الكل)'),
                  ),
                  DropdownMenuItem(
                    value: 'selected',
                    child: Text('موظف واحد أو عدة موظفين'),
                  ),
                  DropdownMenuItem(
                    value: 'managers_only',
                    child: Text('المدراء المباشرين فقط'),
                  ),
                  DropdownMenuItem(
                    value: 'location',
                    child: Text('فرع أو موقع محدد'),
                  ),
                  DropdownMenuItem(
                    value: 'department',
                    child: Text('إدارة أو قسم محدد'),
                  ),
                ],
                onChanged: (val) {
                  setState(() {
                    _targetGroup = val ?? 'all';
                  });
                },
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

              // Conditional Location Dropdown
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
                  items: _locations.map((loc) {
                    return DropdownMenuItem(
                      value: loc.locationId,
                      child: Text(loc.name),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedLocationId = val;
                      _selectedLocationName = _locations
                          .firstWhere((l) => l.locationId == val)
                          .name;
                    });
                  },
                  validator: (val) =>
                      val == null ? 'يرجى اختيار الفرع المستهدف' : null,
                ),
                const SizedBox(height: 16),
              ],

              // Conditional Department Input
              if (_targetGroup == 'department') ...[
                WolfInputField(
                  controller: _departmentController,
                  labelText: 'اسم القسم / الإدارة',
                  englishLabel: 'Department Name',
                  hintText: 'مثال: المبيعات / التقنية',
                  validator: (val) => val == null || val.isEmpty
                      ? 'يرجى كتابة اسم القسم المستهدف'
                      : null,
                ),
                const SizedBox(height: 16),
              ],

              // Title
              WolfInputField(
                controller: _titleController,
                labelText: 'عنوان الإعلان',
                englishLabel: 'Announcement Title',
                hintText: 'مثال: إجازة عيد الأضحى المبارك',
                validator: (val) => val == null || val.isEmpty
                    ? 'يرجى كتابة عنوان الإعلان'
                    : null,
              ),
              const SizedBox(height: 20),

              // Body
              WolfInputField(
                controller: _bodyController,
                labelText: 'محتوى الإعلان التفصيلي',
                englishLabel: 'Announcement Body',
                hintText: 'اكتب تفاصيل الإعلان هنا للموظفين...',
                maxLines: 5,
                validator: (val) => val == null || val.isEmpty
                    ? 'يرجى كتابة تفاصيل محتوى الإعلان'
                    : null,
              ),
              const SizedBox(height: 32),

              // Publish Actions
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
