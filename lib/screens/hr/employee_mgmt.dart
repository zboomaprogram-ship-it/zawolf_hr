import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/auth_service.dart';
import '../../services/attendance_security_service.dart';
import '../../services/sheets_export_service.dart';
import '../../models/employee_role.dart';
import '../../models/user_model.dart';
import '../../models/location_model.dart';
import '../../theme/theme.dart';
import '../../components/wolf_card.dart';
import '../../components/wolf_button.dart';
import '../../components/wolf_input_field.dart';
import '../../components/dynamic_dropdown.dart';
import '../../services/department_service.dart';
import '../../services/job_title_service.dart';

List<DropdownMenuItem<String>> _roleMenuItems({
  required bool canUseSuperAdmin,
  required bool includeEnglish,
}) {
  final items = <DropdownMenuItem<String>>[
    DropdownMenuItem(
      value: EmployeeRole.employee,
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(includeEnglish ? 'موظف (Employee)' : 'موظف'),
      ),
    ),
    DropdownMenuItem(
      value: EmployeeRole.manager,
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(includeEnglish ? 'مدير قسم (Manager)' : 'مدير قسم'),
      ),
    ),
    DropdownMenuItem(
      value: EmployeeRole.hrAdmin,
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(includeEnglish ? 'مسؤول HR (HR Admin)' : 'مسؤول HR'),
      ),
    ),
  ];

  if (canUseSuperAdmin) {
    items.add(
      DropdownMenuItem(
        value: EmployeeRole.superAdmin,
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(
            includeEnglish ? 'مالك النظام (Super Admin)' : 'مالك النظام',
          ),
        ),
      ),
    );
  }

  return items;
}

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String _searchQuery = '';
  String? _filterRole;
  String? _filterDepartment;
  String? _filterLocation;
  String? _filterJobTitle;
  bool _bulkImporting = false;
  int _importProgress = 0;
  int _importTotal = 0;

  void _showAddEmployeeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const AddEmployeeDialog();
      },
    );
  }

  void _showBulkImportSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ZaWolfColors.surface01,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: ZaWolfColors.surface03,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'استيراد جماعي للموظفين',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'قم بتحميل النموذج ← تعبئته في Google Sheets ← ثم ارفعه هنا.',
                    style: TextStyle(
                      color: ZaWolfColors.textSecondary,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 20),

                  // Step 1: Download Template
                  WolfCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: WolfButton(
                            onPressed: () => _downloadTemplate(),
                            text: 'تحميل النموذج',
                            secondaryText: 'CSV TEMPLATE',
                            height: 42,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '① حمّل النموذج',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'افتحه في Google Sheets واملأ بيانات الموظفين',
                                style: TextStyle(
                                  color: ZaWolfColors.textMuted,
                                  fontSize: 11,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Step 2: Upload CSV
                  WolfCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: WolfButton(
                            onPressed: _bulkImporting
                                ? null
                                : () async {
                                    final nav = Navigator.of(context);
                                    await _importEmployeesCsv(setSheetState);
                                    if (mounted) nav.pop();
                                  },
                            text: 'رفع الملف',
                            secondaryText: 'UPLOAD CSV',
                            variant: WolfButtonVariant.teal,
                            height: 42,
                            loading: _bulkImporting,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '② ارفع الملف المعبأ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'سيتم إنشاء حسابات تلقائياً بكلمة مرور: ZW@0000',
                                style: TextStyle(
                                  color: ZaWolfColors.textMuted,
                                  fontSize: 11,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Progress indicator
                  if (_bulkImporting) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: _importTotal > 0
                          ? _importProgress / _importTotal
                          : null,
                      backgroundColor: ZaWolfColors.surface02,
                      valueColor: const AlwaysStoppedAnimation(
                        ZaWolfColors.primaryCyan,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'جاري الإنشاء: $_importProgress / $_importTotal',
                      style: const TextStyle(
                        color: ZaWolfColors.primaryCyan,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Info
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ZaWolfColors.primaryCyan.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: ZaWolfColors.primaryCyan.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'الأعمدة المطلوبة: email, displayName, employeeId\nاختياري: role, department, position, locationId, locationName, baseMonthlySalary, salaryCurrency, managerId, managerName',
                            style: TextStyle(
                              color: ZaWolfColors.textSecondary,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.info_outline,
                          color: ZaWolfColors.primaryCyan,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _downloadTemplate() async {
    try {
      final template = SheetsExportService().generateImportTemplate();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/employee_template.csv');
      await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(template)]);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: 'employee_template',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ZaWolfColors.error,
          content: Text('فشل تحميل النموذج: $e'),
        ),
      );
    }
  }

  Future<void> _importEmployeesCsv(StateSetter setSheetState) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    setState(() => _bulkImporting = true);
    setSheetState(() {});
    try {
      final csvText = utf8.decode(result.files.single.bytes!);
      final rows = const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(csvText);
      if (rows.length < 2) {
        throw Exception('الملف لا يحتوي على بيانات موظفين.');
      }

      final headers = rows.first
          .map((cell) => '$cell'.replaceFirst('\ufeff', '').trim())
          .toList();
      for (final requiredHeader in ['email', 'displayName', 'employeeId']) {
        if (!headers.contains(requiredHeader)) {
          throw Exception(
            'النموذج لا يحتوي على العمود المطلوب: $requiredHeader',
          );
        }
      }
      String value(List<dynamic> row, String key) {
        final index = headers.indexOf(key);
        if (index < 0 || index >= row.length) return '';
        return '${row[index]}'.trim();
      }

      final dataRows = rows
          .skip(1)
          .where((row) => !row.every((cell) => '$cell'.trim().isEmpty))
          .toList();
      setState(() {
        _importTotal = dataRows.length;
        _importProgress = 0;
      });
      setSheetState(() {});

      int created = 0;
      for (var i = 0; i < dataRows.length; i++) {
        final row = dataRows[i];
        final rowNumber = i + 2;
        final email = value(row, 'email');
        final displayName = value(row, 'displayName');
        final employeeId = value(row, 'employeeId');
        if (email.isEmpty || displayName.isEmpty || employeeId.isEmpty) {
          throw Exception(
            'الصف $rowNumber ناقص: email, displayName, employeeId مطلوبة.',
          );
        }
        final role = value(row, 'role').isEmpty
            ? EmployeeRole.employee
            : value(row, 'role');
        const allowedRoles = [
          EmployeeRole.employee,
          EmployeeRole.manager,
          EmployeeRole.hrAdmin,
          EmployeeRole.superAdmin,
        ];
        if (!allowedRoles.contains(role)) {
          throw Exception('الصف $rowNumber يحتوي على دور غير صحيح: $role');
        }
        if (role == EmployeeRole.superAdmin &&
            authService.currentUser?.role != EmployeeRole.superAdmin) {
          throw Exception(
            'لا يمكن لمسؤول HR إنشاء حساب مالك النظام من الاستيراد.',
          );
        }
        final locationId = value(row, 'locationId');
        final locationName = value(row, 'locationName');
        final monthlySalary =
            double.tryParse(value(row, 'baseMonthlySalary')) ?? 0;
        await authService.createEmployeeAccount(
          email: email,
          displayName: displayName,
          role: role,
          employeeId: employeeId,
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
        setState(() => _importProgress = created);
        setSheetState(() {});
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم إنشاء $created حساب بنجاح. كلمة المرور الافتراضية: ZW@0000',
          ),
        ),
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
      if (mounted) {
        setState(() {
          _bulkImporting = false;
          _importProgress = 0;
          _importTotal = 0;
        });
      }
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
            tooltip: 'استيراد جماعي',
            onPressed: _showBulkImportSheet,
            icon: const Icon(Icons.upload_file),
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

          // Filters Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    label:
                        'الدور: ${_filterRole != null ? _translateRole(_filterRole!) : "الكل"}',
                    onTap: _showRoleFilterSheet,
                    isActive: _filterRole != null,
                    onClear: () => setState(() => _filterRole = null),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: 'القسم: ${_filterDepartment ?? "الكل"}',
                    onTap: _showDepartmentFilterSheet,
                    isActive: _filterDepartment != null,
                    onClear: () => setState(() => _filterDepartment = null),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: 'المسمى: ${_filterJobTitle ?? "الكل"}',
                    onTap: _showJobTitleFilterSheet,
                    isActive: _filterJobTitle != null,
                    onClear: () => setState(() => _filterJobTitle = null),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label:
                        'الفرع: ${_filterLocation != null ? "محدد" : "الكل"}',
                    onTap: _showLocationFilterSheet,
                    isActive: _filterLocation != null,
                    onClear: () => setState(() => _filterLocation = null),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

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
                      if (_filterRole != null &&
                          _filterRole!.isNotEmpty &&
                          user.role != _filterRole) {
                        return false;
                      }
                      if (_filterDepartment != null &&
                          _filterDepartment!.isNotEmpty &&
                          user.department != _filterDepartment) {
                        return false;
                      }
                      if (_filterLocation != null &&
                          _filterLocation!.isNotEmpty &&
                          user.locationId != _filterLocation) {
                        return false;
                      }
                      if (_filterJobTitle != null &&
                          _filterJobTitle!.isNotEmpty &&
                          user.position != _filterJobTitle) {
                        return false;
                      }

                      if (_searchQuery.isEmpty) return true;

                      final q = _searchQuery;
                      return user.displayName.toLowerCase().contains(q) ||
                          user.employeeId.toLowerCase().contains(q) ||
                          user.email.toLowerCase().contains(q) ||
                          user.role.toLowerCase().contains(q) ||
                          user.department.toLowerCase().contains(q) ||
                          user.locationName.toLowerCase().contains(q) ||
                          user.position.toLowerCase().contains(q);
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
                    final roleColor = _getRoleColor(emp.role);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      key: ValueKey(emp.uid),
                      child: WolfCard(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) =>
                                EditEmployeeDialog(employee: emp),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Header: Avatar + Name + Role Badge ──
                            Row(
                              children: [
                                // Role badge (left)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: roleColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _translateRole(emp.role),
                                    style: TextStyle(
                                      color: roleColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                // Name + Position (right)
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        emp.displayName,
                                        style: theme.textTheme.titleMedium!
                                            .copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (emp.position.isNotEmpty)
                                        Text(
                                          emp.position,
                                          style: const TextStyle(
                                            color: ZaWolfColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Avatar (far right)
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: roleColor.withValues(
                                    alpha: 0.15,
                                  ),
                                  child: Text(
                                    emp.displayName.isNotEmpty
                                        ? emp.displayName[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color: roleColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // ── Divider ──
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Divider(
                                color: ZaWolfColors.surface03.withValues(
                                  alpha: 0.6,
                                ),
                                height: 1,
                              ),
                            ),

                            // ── Info Grid ──
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoItem(
                                    icon: Icons.badge_outlined,
                                    label: 'الكود',
                                    value: emp.employeeId,
                                  ),
                                ),
                                Expanded(
                                  child: _buildInfoItem(
                                    icon: Icons.business_outlined,
                                    label: 'القسم',
                                    value: emp.department.isNotEmpty
                                        ? emp.department
                                        : '—',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoItem(
                                    icon: Icons.location_on_outlined,
                                    label: 'الفرع',
                                    value: emp.locationName.isNotEmpty
                                        ? emp.locationName
                                        : '—',
                                  ),
                                ),
                                Expanded(
                                  child: _buildInfoItem(
                                    icon: Icons.person_outline,
                                    label: 'المدير',
                                    value: emp.managerName ?? '—',
                                  ),
                                ),
                              ],
                            ),

                            // ── Divider ──
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Divider(
                                color: ZaWolfColors.surface03.withValues(
                                  alpha: 0.6,
                                ),
                                height: 1,
                              ),
                            ),

                            // ── Footer: Status + Actions ──
                            Row(
                              children: [
                                // Status badge
                                InkWell(
                                  onTap: () => _toggleActiveStatus(emp),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
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
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                // Edit button
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: 'تعديل',
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
                                const SizedBox(width: 16),
                                // Delete button
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: 'حذف',
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: ZaWolfColors.error,
                                    size: 20,
                                  ),
                                  onPressed: () => _confirmDeleteEmployee(emp),
                                ),
                              ],
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

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: ZaWolfColors.textMuted,
                  fontSize: 10,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Icon(icon, color: ZaWolfColors.primaryCyan, size: 16),
      ],
    );
  }

  Future<void> _toggleActiveStatus(UserModel emp) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ZaWolfColors.surface01,
        title: Text(
          emp.isActive ? 'تعطيل الحساب؟' : 'تفعيل الحساب؟',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          emp.isActive
              ? 'هل تريد بالتأكيد تعطيل حساب الموظف ${emp.displayName}؟ لن يتمكن من تسجيل الدخول.'
              : 'هل تريد تفعيل حساب الموظف ${emp.displayName}؟',
          style: const TextStyle(color: ZaWolfColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: ZaWolfColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              emp.isActive ? 'تعطيل' : 'تفعيل',
              style: TextStyle(
                color: emp.isActive ? ZaWolfColors.error : ZaWolfColors.success,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _db.collection('users').doc(emp.uid).update({
        'isActive': !emp.isActive,
      });
    }
  }

  Future<void> _confirmDeleteEmployee(UserModel emp) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ZaWolfColors.surface01,
        title: const Text('حذف الحساب؟', style: TextStyle(color: Colors.white)),
        content: Text(
          'هل تريد بالتأكيد حذف حساب الموظف ${emp.displayName} بشكل نهائي؟\n\nتنبيه: سيتم مسح بياناته من التطبيق، ولكن يجب عليك حذف بريده الإلكتروني يدوياً من Firebase Console.',
          style: const TextStyle(color: ZaWolfColors.textSecondary),
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: ZaWolfColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'حذف',
              style: TextStyle(color: ZaWolfColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _db.collection('users').doc(emp.uid).delete();
    }
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

  Widget _buildFilterChip({
    required String label,
    required VoidCallback onTap,
    required bool isActive,
    required VoidCallback onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? ZaWolfColors.primaryCyan.withValues(alpha: 0.15)
              : ZaWolfColors.surface01,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? ZaWolfColors.primaryCyan : ZaWolfColors.surface02,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? ZaWolfColors.primaryCyan
                    : ZaWolfColors.textSecondary,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: const Icon(
                  Icons.close,
                  size: 14,
                  color: ZaWolfColors.primaryCyan,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showRoleFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ZaWolfColors.surface01,
      builder: (context) {
        return ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('الكل', style: TextStyle(color: Colors.white)),
              onTap: () {
                setState(() => _filterRole = null);
                Navigator.pop(context);
              },
            ),
            ...[
              EmployeeRole.employee,
              EmployeeRole.manager,
              EmployeeRole.hrAdmin,
              EmployeeRole.superAdmin,
            ].map((role) {
              return ListTile(
                title: Text(
                  _translateRole(role),
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  setState(() => _filterRole = role);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        );
      },
    );
  }

  void _showDepartmentFilterSheet() async {
    final snap = await _db.collection('departments').get();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: ZaWolfColors.surface01,
      builder: (context) {
        return ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('الكل', style: TextStyle(color: Colors.white)),
              onTap: () {
                setState(() => _filterDepartment = null);
                Navigator.pop(context);
              },
            ),
            ...snap.docs.map((doc) {
              final dept = doc.data()['name'] as String;
              return ListTile(
                title: Text(dept, style: const TextStyle(color: Colors.white)),
                onTap: () {
                  setState(() => _filterDepartment = dept);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        );
      },
    );
  }

  void _showJobTitleFilterSheet() async {
    final snap = await _db.collection('job_titles').get();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: ZaWolfColors.surface01,
      builder: (context) {
        return ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('الكل', style: TextStyle(color: Colors.white)),
              onTap: () {
                setState(() => _filterJobTitle = null);
                Navigator.pop(context);
              },
            ),
            ...snap.docs.map((doc) {
              final title = doc.data()['name'] as String;
              return ListTile(
                title: Text(title, style: const TextStyle(color: Colors.white)),
                onTap: () {
                  setState(() => _filterJobTitle = title);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        );
      },
    );
  }

  void _showLocationFilterSheet() async {
    final snap = await _db
        .collection('locations')
        .where('isActive', isEqualTo: true)
        .get();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: ZaWolfColors.surface01,
      builder: (context) {
        return ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('الكل', style: TextStyle(color: Colors.white)),
              onTap: () {
                setState(() => _filterLocation = null);
                Navigator.pop(context);
              },
            ),
            ...snap.docs.map((doc) {
              final loc = LocationModel.fromFirestore(doc);
              return ListTile(
                title: Text(
                  loc.name,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  setState(() => _filterLocation = loc.locationId);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        );
      },
    );
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
  final _codeController = TextEditingController();
  final _salaryController = TextEditingController(text: '0');
  final _daysOffController = TextEditingController(text: '21');

  String _selectedRole = 'employee';
  String? _selectedDepartment;
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
    _codeController.dispose();
    _salaryController.dispose();
    _daysOffController.dispose();
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
        department: _selectedDepartment ?? 'General',
        position: _jobTitleController.text.trim(),
        role: _selectedRole,
        locationId: _selectedLocationId!,
        locationName: _selectedLocationName!,
        baseMonthlySalary: double.tryParse(_salaryController.text) ?? 0,
        daysOffBalance: int.tryParse(_daysOffController.text) ?? 21,
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
    final canUseSuperAdmin =
        Provider.of<AuthService>(context, listen: false).currentUser?.role ==
        EmployeeRole.superAdmin;

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
                DynamicDropdown(
                  label: 'المسمى الوظيفي',
                  actionLabel: 'مسمى جديد',
                  dialogTitle: 'إضافة مسمى وظيفي جديد',
                  initialValue: _jobTitleController.text.isNotEmpty
                      ? _jobTitleController.text
                      : null,
                  onChanged: (val) {
                    if (val != null) _jobTitleController.text = val;
                  },
                  stream: JobTitleService.instance.watchJobTitles(),
                  onAdd: JobTitleService.instance.addJobTitle,
                  onInit: JobTitleService.instance.bootstrapJobTitlesIfNeeded,
                ),
                const SizedBox(height: 16),

                // Department
                DynamicDropdown(
                  label: 'القسم / الإدارة',
                  actionLabel: 'قسم جديد',
                  dialogTitle: 'إضافة قسم جديد',
                  initialValue: _selectedDepartment,
                  onChanged: (val) {
                    _selectedDepartment = val;
                  },
                  stream: DepartmentService.instance.watchDepartments(),
                  onAdd: DepartmentService.instance.addDepartment,
                  onInit:
                      DepartmentService.instance.bootstrapDepartmentsIfNeeded,
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

                // Days Off Limit
                WolfInputField(
                  controller: _daysOffController,
                  labelText: 'رصيد العطلات (بالأيام)',
                  englishLabel: 'Days Off Balance',
                  hintText: '21',
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'الرصيد مطلوب';
                    }
                    if (int.tryParse(val) == null) return 'قيمة غير صالحة';
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
                  items: _roleMenuItems(
                    canUseSuperAdmin: canUseSuperAdmin,
                    includeEnglish: true,
                  ),
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
  late final TextEditingController _codeController;
  late final TextEditingController _salaryController;
  late final TextEditingController _daysOffController;

  String? _selectedDepartment;
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
    _codeController = TextEditingController(text: emp.employeeId);
    _salaryController = TextEditingController(
      text: emp.baseMonthlySalary.toStringAsFixed(0),
    );
    _daysOffController = TextEditingController(
      text: emp.leaveBalance.daysOff.toString(),
    );
    _selectedDepartment = emp.department;

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
    _codeController.dispose();
    _salaryController.dispose();
    _daysOffController.dispose();
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
      final canUseSuperAdmin =
          Provider.of<AuthService>(context, listen: false).currentUser?.role ==
          EmployeeRole.superAdmin;
      final effectiveRole =
          !canUseSuperAdmin && _selectedRole == EmployeeRole.superAdmin
          ? EmployeeRole.employee
          : _selectedRole;
      final updateData = {
        'displayName': _nameController.text.trim(),
        'employeeId': _codeController.text.trim(),
        'department': _selectedDepartment ?? widget.employee.department,
        'position': _jobTitleController.text.trim(),
        'role': effectiveRole,
        'locationId': _selectedLocationId!,
        'locationName': _selectedLocationName!,
        'baseMonthlySalary': double.tryParse(_salaryController.text) ?? 0,
        'salaryCurrency': widget.employee.salaryCurrency,
        'leaveBalance.daysOff':
            int.tryParse(_daysOffController.text) ??
            widget.employee.leaveBalance.daysOff,
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

  Future<void> _resetAttendanceDevice() async {
    final deviceId = widget.employee.registeredAttendanceDeviceId;
    if (deviceId == null || deviceId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد جهاز حضور مسجل لهذا الحساب.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ZaWolfColors.surface01,
        title: const Text(
          'إعادة ضبط جهاز الحضور',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'سيتم فك ربط جهاز ${widget.employee.displayName} الحالي، وبعدها يمكنه تسجيل الحضور من جهاز جديد بعد التحقق بالبصمة.',
          style: const TextStyle(color: ZaWolfColors.textSecondary),
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final batch = _db.batch();
      final userRef = _db.collection('users').doc(widget.employee.uid);
      final deviceRef = _db
          .collection('attendanceDevices')
          .doc(AttendanceSecurityService.deviceDocumentId(deviceId));

      batch.update(userRef, {
        'registeredAttendanceDeviceId': FieldValue.delete(),
        'registeredAttendanceDeviceLabel': FieldValue.delete(),
        'registeredAttendanceDeviceAt': FieldValue.delete(),
      });
      batch.delete(deviceRef);
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إعادة ضبط جهاز الحضور بنجاح.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل إعادة الضبط: $e')));
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
    final canUseSuperAdmin =
        Provider.of<AuthService>(context, listen: false).currentUser?.role ==
        EmployeeRole.superAdmin;
    final selectedRole =
        !canUseSuperAdmin && _selectedRole == EmployeeRole.superAdmin
        ? EmployeeRole.employee
        : _selectedRole;

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

                DynamicDropdown(
                  label: 'المسمى الوظيفي',
                  actionLabel: 'مسمى جديد',
                  dialogTitle: 'إضافة مسمى وظيفي جديد',
                  initialValue: _jobTitleController.text.isNotEmpty
                      ? _jobTitleController.text
                      : null,
                  onChanged: (val) {
                    if (val != null) _jobTitleController.text = val;
                  },
                  stream: JobTitleService.instance.watchJobTitles(),
                  onAdd: JobTitleService.instance.addJobTitle,
                  onInit: JobTitleService.instance.bootstrapJobTitlesIfNeeded,
                ),
                const SizedBox(height: 16),

                DynamicDropdown(
                  label: 'القسم / الإدارة',
                  actionLabel: 'قسم جديد',
                  dialogTitle: 'إضافة قسم جديد',
                  initialValue:
                      _selectedDepartment ?? widget.employee.department,
                  onChanged: (val) {
                    _selectedDepartment = val;
                  },
                  stream: DepartmentService.instance.watchDepartments(),
                  onAdd: DepartmentService.instance.addDepartment,
                  onInit:
                      DepartmentService.instance.bootstrapDepartmentsIfNeeded,
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

                WolfInputField(
                  controller: _daysOffController,
                  labelText: 'رصيد العطلات (بالأيام)',
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'الرصيد مطلوب';
                    }
                    if (int.tryParse(val) == null) return 'قيمة غير صالحة';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  dropdownColor: ZaWolfColors.surface01,
                  decoration: const InputDecoration(
                    labelText: 'الدور الصلاحيات (Role)',
                    labelStyle: TextStyle(color: ZaWolfColors.primaryCyan),
                  ),
                  style: const TextStyle(color: Colors.white),
                  items: _roleMenuItems(
                    canUseSuperAdmin: canUseSuperAdmin,
                    includeEnglish: false,
                  ),
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

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ZaWolfColors.surface02.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ZaWolfColors.surface02),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'جهاز الحضور المسجل',
                        style: theme.textTheme.titleMedium!.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.employee.registeredAttendanceDeviceLabel ??
                            'لم يتم ربط جهاز بعد',
                        style: const TextStyle(
                          color: ZaWolfColors.textSecondary,
                        ),
                      ),
                      if (widget.employee.registeredAttendanceDeviceId !=
                          null) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.employee.registeredAttendanceDeviceId!,
                          style: const TextStyle(
                            color: ZaWolfColors.textMuted,
                            fontSize: 12,
                          ),
                          textDirection: TextDirection.ltr,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed:
                              widget.employee.registeredAttendanceDeviceId ==
                                  null
                              ? null
                              : _resetAttendanceDevice,
                          icon: const Icon(Icons.phonelink_erase),
                          label: const Text('إعادة ضبط الجهاز'),
                          style: TextButton.styleFrom(
                            foregroundColor: ZaWolfColors.primaryCyan,
                          ),
                        ),
                      ),
                    ],
                  ),
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
