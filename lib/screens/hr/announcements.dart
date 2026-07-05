import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  String _targetGroup = 'all'; // all | managers_only | location | department
  String? _selectedLocationId;
  String? _selectedLocationName;

  @override
  void initState() {
    super.initState();
    _fetchLocations();
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
      // 1. Fetch users from Firestore based on target selections
      Query query = _db.collection('users');
      if (_targetGroup == 'managers_only') {
        query = query.where('role', isEqualTo: 'manager');
      } else if (_targetGroup == 'location' && _selectedLocationId != null) {
        query = query.where('locationId', isEqualTo: _selectedLocationId);
      }

      final usersSnap = await query.get();
      var users = usersSnap.docs;

      // Filter by department client side
      if (_targetGroup == 'department' && deptFilter.isNotEmpty) {
        users = users.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final userDept = data['department'] as String? ?? '';
          return userDept.toLowerCase() == deptFilter.toLowerCase();
        }).toList();
      }

      if (users.isEmpty) {
        throw Exception('لا يوجد موظفون مسجلون يطابقون الفئة المستهدفة.');
      }

      final batch = _db.batch();

      // 2. Loop and generate notification item for every target user
      for (var userDoc in users) {
        final userId = userDoc.id;

        final notifRef = _db
            .collection('notifications')
            .doc(userId)
            .collection('items')
            .doc();

        batch.set(notifRef, {
          'notificationId': notifRef.id,
          'type': 'hr_announcement',
          'title': '📢 إعلان إداري: $title',
          'body': body,
          'data': {},
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Increment unread count
        final userRef = _db.collection('users').doc(userId);
        batch.update(userRef, {'unreadNotifications': FieldValue.increment(1)});
      }

      // Write to global announcements history for archival/future views
      final globalAnnRef = _db.collection('announcements').doc();
      batch.set(globalAnnRef, {
        'announcementId': globalAnnRef.id,
        'title': title,
        'body': body,
        'targetGroup': _targetGroup,
        if (_targetGroup == 'location')
          'targetLocationName': _selectedLocationName,
        if (_targetGroup == 'department') 'targetDepartment': deptFilter,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

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
