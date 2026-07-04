import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../models/employee_role.dart';
import '../../models/user_model.dart';
import '../../models/location_model.dart';
import '../../theme/theme.dart';
import '../../components/wolf_card.dart';
import '../../components/wolf_button.dart';
import '../../components/wolf_input_field.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String _searchQuery = '';
  bool _bulkImporting = false;

  void _showAddEmployeeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const AddEmployeeDialog();
      },
    );
  }

  Future<void> _importEmployeesCsv() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    setState(() => _bulkImporting = true);
    try {
      final csvText = utf8.decode(result.files.single.bytes!);
      final rows = const CsvToListConverter(eol: '\n').convert(csvText);
      if (rows.length < 2) {
        throw Exception('الملف لا يحتوي على بيانات موظفين.');
      }

      final headers = rows.first.map((cell) => '$cell'.trim()).toList();
      String value(List<dynamic> row, String key) {
        final index = headers.indexOf(key);
        if (index < 0 || index >= row.length) return '';
        return '${row[index]}'.trim();
      }

      int created = 0;
      for (final row in rows.skip(1)) {
        if (row.every((cell) => '$cell'.trim().isEmpty)) continue;
        final locationId = value(row, 'locationId');
        final locationName = value(row, 'locationName');
        final monthlySalary =
            double.tryParse(value(row, 'baseMonthlySalary')) ?? 0;
        await authService.createEmployeeAccount(
          email: value(row, 'email'),
          displayName: value(row, 'displayName'),
          role: value(row, 'role').isEmpty
              ? EmployeeRole.employee
              : value(row, 'role'),
          employeeId: value(row, 'employeeId'),
          department: value(row, 'department'),
          position: value(row, 'position'),
          locationId: locationId,
          locationName: locationName,
          baseMonthlySalary: monthlySalary,
          salaryCurrency: value(row, 'salaryCurrency').isEmpty
              ? 'EGP'
              : value(row, 'salaryCurrency'),
          managerId: value(row, 'managerId').isEmpty
              ? null
              : value(row, 'managerId'),
          managerName: value(row, 'managerName').isEmpty
              ? null
              : value(row, 'managerName'),
        );
        created++;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم إنشاء $created حساب. كلمة المرور: ZW@0000')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ZaWolfColors.error,
          content: Text('فشل رفع الملف: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _bulkImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'إدارة شؤون الموظفين',
          style: theme.textTheme.headlineMedium,
        ),
        actions: [
          IconButton(
            tooltip: 'رفع ملف CSV',
            onPressed: _bulkImporting ? null : _importEmployeesCsv,
            icon: _bulkImporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ZaWolfColors.primaryCyan,
        onPressed: _showAddEmployeeDialog,
        icon: const Icon(
          Icons.person_add_outlined,
          color: ZaWolfColors.background,
        ),
        label: Text(
          'تسجيل موظف',
          style: theme.textTheme.titleMedium!.copyWith(
            color: ZaWolfColors.background,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Input Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: WolfInputField(
              labelText: 'البحث عن موظف',
              englishLabel: 'Search Staff',
              hintText: 'اكتب اسم الموظف أو الكود الموظف...',
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
            ),
          ),

          // Real-time Employee List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: ZaWolfColors.primaryCyan,
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                // Filter client side for searches
                final employees = docs
                    .map((doc) => UserModel.fromFirestore(doc))
                    .where((user) {
                      if (_searchQuery.isEmpty) return true;
                      return user.displayName.toLowerCase().contains(
                            _searchQuery,
                          ) ||
                          user.employeeId.toLowerCase().contains(
                            _searchQuery,
                          ) ||
                          user.email.toLowerCase().contains(_searchQuery);
                    })
                    .toList();

                if (employees.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.people_outline,
                          color: ZaWolfColors.textMuted,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا يوجد موظفون مسجلون يطابقون البحث.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: employees.length,
                  itemBuilder: (context, index) {
                    final emp = employees[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      key: ValueKey(emp.uid),
                      child: WolfCard(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Role Badge Tag and Deactivation Switch
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getRoleColor(
                                          emp.role,
                                        ).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _translateRole(emp.role),
                                        style: TextStyle(
                                          color: _getRoleColor(emp.role),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        color: ZaWolfColors.primaryCyan,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) =>
                                              EditEmployeeDialog(employee: emp),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: ZaWolfColors.error,
                                        size: 20,
                                      ),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            backgroundColor:
                                                ZaWolfColors.surface01,
                                            title: const Text(
                                              'حذف الحساب؟',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                            content: Text(
                                              'هل تريد بالتأكيد حذف حساب الموظف ${emp.displayName} بشكل نهائي؟\n\nتنبيه: سيتم مسح بياناته من التطبيق، ولكن يجب عليك حذف بريده الإلكتروني يدوياً من Firebase Console.',
                                              style: const TextStyle(
                                                color:
                                                    ZaWolfColors.textSecondary,
                                              ),
                                              textDirection: TextDirection.rtl,
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text(
                                                  'إلغاء',
                                                  style: TextStyle(
                                                    color: ZaWolfColors
                                                        .textSecondary,
                                                  ),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                child: const Text(
                                                  'حذف',
                                                  style: TextStyle(
                                                    color: ZaWolfColors.error,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await _db
                                              .collection('users')
                                              .doc(emp.uid)
                                              .delete();
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        backgroundColor: ZaWolfColors.surface01,
                                        title: Text(
                                          emp.isActive
                                              ? 'تعطيل الحساب؟'
                                              : 'تفعيل الحساب؟',
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                        content: Text(
                                          emp.isActive
                                              ? 'هل تريد بالتأكيد تعطيل حساب الموظف ${emp.displayName}؟ لن يتمكن من تسجيل الدخول.'
                                              : 'هل تريد تفعيل حساب الموظف ${emp.displayName}؟',
                                          style: const TextStyle(
                                            color: ZaWolfColors.textSecondary,
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text(
                                              'إلغاء',
                                              style: TextStyle(
                                                color:
                                                    ZaWolfColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: Text(
                                              emp.isActive ? 'تعطيل' : 'تفعيل',
                                              style: TextStyle(
                                                color: emp.isActive
                                                    ? ZaWolfColors.error
                                                    : ZaWolfColors.success,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await _db
                                          .collection('users')
                                          .doc(emp.uid)
                                          .update({'isActive': !emp.isActive});
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: emp.isActive
                                          ? ZaWolfColors.success.withValues(
                                              alpha: 0.1,
                                            )
                                          : ZaWolfColors.error.withValues(
                                              alpha: 0.1,
                                            ),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: emp.isActive
                                            ? ZaWolfColors.success.withValues(
                                                alpha: 0.3,
                                              )
                                            : ZaWolfColors.error.withValues(
                                                alpha: 0.3,
                                              ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          emp.isActive
                                              ? Icons.check_circle_outline
                                              : Icons.block_outlined,
                                          size: 12,
                                          color: emp.isActive
                                              ? ZaWolfColors.success
                                              : ZaWolfColors.error,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          emp.isActive ? 'نشط' : 'معطل',
                                          style: TextStyle(
                                            color: emp.isActive
                                                ? ZaWolfColors.success
                                                : ZaWolfColors.error,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Name & Branch Information
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          emp.displayName,
                                          style: theme.textTheme.titleMedium!
                                              .copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        Text(
                                          'كود: ${emp.employeeId} · ${emp.position} · ${emp.locationName}',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                        Text(
                                          'الأذونات المستخدمة: ${emp.permissionBalance.usedThisMonth}',
                                          style: theme.textTheme.bodySmall!
                                              .copyWith(
                                                color: ZaWolfColors.textMuted,
                                                fontSize: 10,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  CircleAvatar(
                                    backgroundColor: ZaWolfColors.surface02,
                                    child: Text(
                                      emp.displayName.substring(0, 1),
                                      style: const TextStyle(
                                        color: ZaWolfColors.primaryCyan,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case EmployeeRole.superAdmin:
        return ZaWolfColors.primaryCyan;
      case 'hr_admin':
        return ZaWolfColors.error;
      case 'manager':
        return ZaWolfColors.warning;
      default:
        return ZaWolfColors.primaryCyan;
    }
  }

  String _translateRole(String role) {
    return EmployeeRole.arabicLabel(role);
  }
}

class AddEmployeeDialog extends StatefulWidget {
  const AddEmployeeDialog({super.key});

  @override
  State<AddEmployeeDialog> createState() => _AddEmployeeDialogState();
}

class _AddEmployeeDialogState extends State<AddEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _departmentController = TextEditingController();
  final _codeController = TextEditingController();
  final _salaryController = TextEditingController(text: '0');

  String _selectedRole = 'employee';
  String? _selectedLocationId;
  String? _selectedLocationName;
  String? _selectedManagerId;
  String? _selectedManagerName;

  bool _isLoading = false;
  List<LocationModel> _locations = [];
  List<UserModel> _managers = [];

  @override
  void initState() {
    super.initState();
    _fetchLocationsAndManagers();
  }

  Future<void> _fetchLocationsAndManagers() async {
    try {
      final locSnap = await _db
          .collection('locations')
          .where('isActive', isEqualTo: true)
          .get();
      final mgrSnap = await _db
          .collection('users')
          .where('role', isEqualTo: 'manager')
          .get();

      setState(() {
        _locations = locSnap.docs
            .map((doc) => LocationModel.fromFirestore(doc))
            .toList();
        _managers = mgrSnap.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .toList();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _jobTitleController.dispose();
    _departmentController.dispose();
    _codeController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLocationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار فرع الموظف.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      final newEmp = await authService.createEmployeeAccount(
        email: _emailController.text.trim(),
        displayName: _nameController.text.trim(),
        employeeId: _codeController.text.trim(),
        department: _departmentController.text.trim(),
        position: _jobTitleController.text.trim(),
        role: _selectedRole,
        locationId: _selectedLocationId!,
        locationName: _selectedLocationName!,
        baseMonthlySalary: double.tryParse(_salaryController.text) ?? 0,
        managerId: _selectedManagerId,
        managerName: _selectedManagerName,
      );

      if (mounted) {
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: ZaWolfColors.surface01,
            title: const Text(
              'تم إنشاء الحساب بنجاح ✅',
              textDirection: TextDirection.rtl,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'الاسم: ${newEmp.displayName}',
                  textDirection: TextDirection.rtl,
                ),
                Text(
                  'البريد الإلكتروني: ${newEmp.email}',
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ZaWolfColors.primaryCyan.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: ZaWolfColors.primaryCyan.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'كلمة المرور المؤقتة',
                        style: TextStyle(
                          color: ZaWolfColors.primaryCyan,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        newEmp.initialPassword ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontFamily: 'JetBrains Mono',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'فشل التسجيل: $e';
        if (e.toString().contains('email-already-in-use')) {
          errorMessage =
              'هذا البريد الإلكتروني مسجل بالفعل.\n\nإذا قمت بحذف هذا الموظف سابقاً، فيجب عليك أيضاً حذف حسابه يدوياً من لوحة تحكم Firebase (Authentication) لتتمكن من إعادة استخدام البريد الإلكتروني.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage, textDirection: TextDirection.rtl),
            duration: const Duration(seconds: 8),
            backgroundColor: ZaWolfColors.error,
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

    return Dialog(
      backgroundColor: ZaWolfColors.surface01,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'تسجيل حساب موظف جديد',
                      style: theme.textTheme.headlineMedium!.copyWith(
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: ZaWolfColors.textSecondary,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(color: ZaWolfColors.surface02),
                const SizedBox(height: 12),

                // Full Name
                WolfInputField(
                  controller: _nameController,
                  labelText: 'الاسم الكامل',
                  englishLabel: 'Full Name',
                  hintText: 'أحمد محمد علي',
                  validator: (val) =>
                      val == null || val.isEmpty ? 'حقل الاسم مطلوب' : null,
                ),
                const SizedBox(height: 16),

                // Email
                WolfInputField(
                  controller: _emailController,
                  labelText: 'البريد الإلكتروني',
                  englishLabel: 'Email Address',
                  hintText: 'employee@zawolf.ai',
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) => val == null || val.isEmpty
                      ? 'البريد الإلكتروني مطلوب'
                      : null,
                ),
                const SizedBox(height: 16),

                // Employee ID Code
                WolfInputField(
                  controller: _codeController,
                  labelText: 'الكود التعريفي (ID)',
                  englishLabel: 'Employee Code',
                  hintText: 'ZW-1002',
                  validator: (val) =>
                      val == null || val.isEmpty ? 'كود الموظف مطلوب' : null,
                ),
                const SizedBox(height: 16),

                // Job Title
                WolfInputField(
                  controller: _jobTitleController,
                  labelText: 'المسمى الوظيفي',
                  englishLabel: 'Job Title',
                  hintText: 'مهندس برمجيات أول',
                  validator: (val) => val == null || val.isEmpty
                      ? 'المسمى الوظيفي مطلوب'
                      : null,
                ),
                const SizedBox(height: 16),

                // Department
                WolfInputField(
                  controller: _departmentController,
                  labelText: 'القسم الرئيسي',
                  englishLabel: 'Department',
                  hintText: 'تطوير البرمجيات',
                  validator: (val) =>
                      val == null || val.isEmpty ? 'القسم مطلوب' : null,
                ),
                const SizedBox(height: 16),

                WolfInputField(
                  controller: _salaryController,
                  labelText: 'الراتب الشهري الأساسي',
                  englishLabel: 'Base Monthly Salary',
                  hintText: 'مثال: 12000',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'الراتب مطلوب لحساب الخصومات';
                    }
                    if (double.tryParse(val) == null) {
                      return 'قيمة الراتب غير صالحة';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Role Selector Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedRole,
                  dropdownColor: ZaWolfColors.surface01,
                  decoration: const InputDecoration(
                    labelText: 'الدور الصلاحيات (Role)',
                    labelStyle: TextStyle(color: ZaWolfColors.primaryCyan),
                  ),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(
                      value: 'employee',
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text('موظف (Employee)'),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'manager',
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text('مدير قسم (Manager)'),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'hr_admin',
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text('مسؤول HR (HR Admin)'),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'super_admin',
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text('مالك النظام (Super Admin)'),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedRole = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Branch Location Selector
                DropdownButtonFormField<String>(
                  initialValue: _selectedLocationId,
                  dropdownColor: ZaWolfColors.surface01,
                  decoration: const InputDecoration(
                    labelText: 'فرع العمل الجغرافي',
                    labelStyle: TextStyle(color: ZaWolfColors.primaryCyan),
                  ),
                  style: const TextStyle(color: Colors.white),
                  items: _locations.map((loc) {
                    return DropdownMenuItem(
                      value: loc.locationId,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(loc.name),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      final selected = _locations.firstWhere(
                        (element) => element.locationId == val,
                      );
                      setState(() {
                        _selectedLocationId = val;
                        _selectedLocationName = selected.name;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Manager Selector Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedManagerId,
                  dropdownColor: ZaWolfColors.surface01,
                  decoration: const InputDecoration(
                    labelText: 'المدير المباشر (اختياري)',
                    labelStyle: TextStyle(color: ZaWolfColors.primaryCyan),
                  ),
                  style: const TextStyle(color: Colors.white),
                  items: _managers.map((mgr) {
                    return DropdownMenuItem(
                      value: mgr.uid,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(mgr.displayName),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      final selected = _managers.firstWhere(
                        (element) => element.uid == val,
                      );
                      setState(() {
                        _selectedManagerId = val;
                        _selectedManagerName = selected.displayName;
                      });
                    } else {
                      setState(() {
                        _selectedManagerId = null;
                        _selectedManagerName = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 24),

                // Form Submit Buttons
                Row(
                  children: [
                    Expanded(
                      child: WolfButton(
                        onPressed: () => Navigator.pop(context),
                        text: 'إلغاء',
                        secondaryText: 'CANCEL',
                        variant: WolfButtonVariant.outline,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: WolfButton(
                        onPressed: _submit,
                        text: 'إنشاء الحساب',
                        secondaryText: 'CREATE USER',
                        loading: _isLoading,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EditEmployeeDialog extends StatefulWidget {
  final UserModel employee;
  const EditEmployeeDialog({super.key, required this.employee});

  @override
  State<EditEmployeeDialog> createState() => _EditEmployeeDialogState();
}

class _EditEmployeeDialogState extends State<EditEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  late final TextEditingController _nameController;
  late final TextEditingController _jobTitleController;
  late final TextEditingController _departmentController;
  late final TextEditingController _codeController;
  late final TextEditingController _salaryController;

  late String _selectedRole;
  String? _selectedLocationId;
  String? _selectedLocationName;
  String? _selectedManagerId;
  String? _selectedManagerName;

  bool _isLoading = false;
  List<LocationModel> _locations = [];
  List<UserModel> _managers = [];

  @override
  void initState() {
    super.initState();
    final emp = widget.employee;
    _nameController = TextEditingController(text: emp.displayName);
    _jobTitleController = TextEditingController(text: emp.position);
    _departmentController = TextEditingController(text: emp.department);
    _codeController = TextEditingController(text: emp.employeeId);
    _salaryController = TextEditingController(
      text: emp.baseMonthlySalary.toStringAsFixed(2),
    );

    _selectedRole = emp.role;
    _selectedLocationId = emp.locationId;
    _selectedLocationName = emp.locationName;
    _selectedManagerId = emp.managerId;
    _selectedManagerName = emp.managerName;

    _fetchLocationsAndManagers();
  }

  Future<void> _fetchLocationsAndManagers() async {
    try {
      final locSnap = await _db
          .collection('locations')
          .where('isActive', isEqualTo: true)
          .get();
      final mgrSnap = await _db
          .collection('users')
          .where('role', isEqualTo: 'manager')
          .get();

      setState(() {
        _locations = locSnap.docs
            .map((doc) => LocationModel.fromFirestore(doc))
            .toList();
        _managers = mgrSnap.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .toList();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _jobTitleController.dispose();
    _departmentController.dispose();
    _codeController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLocationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار فرع الموظف.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final updateData = {
        'displayName': _nameController.text.trim(),
        'employeeId': _codeController.text.trim(),
        'department': _departmentController.text.trim(),
        'position': _jobTitleController.text.trim(),
        'role': _selectedRole,
        'locationId': _selectedLocationId!,
        'locationName': _selectedLocationName!,
        'baseMonthlySalary': double.tryParse(_salaryController.text) ?? 0,
        'salaryCurrency': widget.employee.salaryCurrency,
        'managerId': _selectedManagerId,
        'managerName': _selectedManagerName,
      };

      await _db.collection('users').doc(widget.employee.uid).update(updateData);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم التحديث بنجاح')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل التحديث: $e')));
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

    return Dialog(
      backgroundColor: ZaWolfColors.surface01,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'تعديل بيانات الموظف',
                      style: theme.textTheme.headlineMedium!.copyWith(
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: ZaWolfColors.textSecondary,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(color: ZaWolfColors.surface02),
                const SizedBox(height: 12),

                WolfInputField(
                  controller: _nameController,
                  labelText: 'الاسم الكامل',
                  validator: (val) =>
                      val == null || val.isEmpty ? 'حقل الاسم مطلوب' : null,
                ),
                const SizedBox(height: 16),

                WolfInputField(
                  controller: _codeController,
                  labelText: 'الكود التعريفي (ID)',
                  validator: (val) =>
                      val == null || val.isEmpty ? 'كود الموظف مطلوب' : null,
                ),
                const SizedBox(height: 16),

                WolfInputField(
                  controller: _jobTitleController,
                  labelText: 'المسمى الوظيفي',
                  validator: (val) => val == null || val.isEmpty
                      ? 'المسمى الوظيفي مطلوب'
                      : null,
                ),
                const SizedBox(height: 16),

                WolfInputField(
                  controller: _departmentController,
                  labelText: 'القسم الرئيسي',
                  validator: (val) =>
                      val == null || val.isEmpty ? 'القسم مطلوب' : null,
                ),
                const SizedBox(height: 16),

                WolfInputField(
                  controller: _salaryController,
                  labelText: 'الراتب الشهري الأساسي',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'الراتب مطلوب لحساب الخصومات';
                    }
                    if (double.tryParse(val) == null) {
                      return 'قيمة الراتب غير صالحة';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: _selectedRole,
                  dropdownColor: ZaWolfColors.surface01,
                  decoration: const InputDecoration(
                    labelText: 'الدور الصلاحيات (Role)',
                    labelStyle: TextStyle(color: ZaWolfColors.primaryCyan),
                  ),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(
                      value: 'employee',
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text('موظف'),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'manager',
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text('مدير قسم'),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'hr_admin',
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text('مسؤول HR'),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'super_admin',
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text('مالك النظام'),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedRole = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue:
                      _locations.any((l) => l.locationId == _selectedLocationId)
                      ? _selectedLocationId
                      : null,
                  dropdownColor: ZaWolfColors.surface01,
                  decoration: const InputDecoration(
                    labelText: 'فرع العمل الجغرافي',
                    labelStyle: TextStyle(color: ZaWolfColors.primaryCyan),
                  ),
                  style: const TextStyle(color: Colors.white),
                  items: _locations
                      .map(
                        (loc) => DropdownMenuItem(
                          value: loc.locationId,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(loc.name),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      final selected = _locations.firstWhere(
                        (e) => e.locationId == val,
                      );
                      setState(() {
                        _selectedLocationId = val;
                        _selectedLocationName = selected.name;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue:
                      _managers.any((m) => m.uid == _selectedManagerId)
                      ? _selectedManagerId
                      : null,
                  dropdownColor: ZaWolfColors.surface01,
                  decoration: const InputDecoration(
                    labelText: 'المدير المباشر (اختياري)',
                    labelStyle: TextStyle(color: ZaWolfColors.primaryCyan),
                  ),
                  style: const TextStyle(color: Colors.white),
                  items: _managers
                      .map(
                        (mgr) => DropdownMenuItem(
                          value: mgr.uid,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(mgr.displayName),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      if (val != null) {
                        final selected = _managers.firstWhere(
                          (e) => e.uid == val,
                        );
                        _selectedManagerId = val;
                        _selectedManagerName = selected.displayName;
                      } else {
                        _selectedManagerId = null;
                        _selectedManagerName = null;
                      }
                    });
                  },
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: WolfButton(
                        onPressed: () => Navigator.pop(context),
                        text: 'إلغاء',
                        secondaryText: 'CANCEL',
                        variant: WolfButtonVariant.outline,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: WolfButton(
                        onPressed: _submit,
                        text: 'حفظ التغييرات',
                        secondaryText: 'SAVE',
                        loading: _isLoading,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
