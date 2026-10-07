import 'package:flutter/material.dart';
import '../domain/hiring_request_repository.dart';

class HiringRequestScreen extends StatefulWidget {
  const HiringRequestScreen({required this.repository, super.key});
  final HiringRequestRepository repository;
  @override
  State<HiringRequestScreen> createState() => _HiringRequestScreenState();
}

class _HiringRequestScreenState extends State<HiringRequestScreen> {
  late Future<List<HiringRequest>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.list();
  }

  void _reload() => setState(() => _future = widget.repository.list());

  Future<void> _decide(HiringRequest row, bool approved) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.repository.decide(id: row.id, approved: approved);
      _reload();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<T?> _showSearchablePicker<T>({
    required BuildContext context,
    required String title,
    required String searchHint,
    required List<T> items,
    required String Function(T) itemLabel,
    String Function(T)? itemSubtitle,
    IconData itemIcon = Icons.check_circle_outline,
  }) async {
    return showDialog<T>(
      context: context,
      builder: (dialogCtx) {
        String query = '';
        return StatefulBuilder(
          builder: (ctx, setPickerState) {
            final filtered = items.where((it) {
              final q = query.trim().toLowerCase();
              if (q.isEmpty) return true;
              final label = itemLabel(it).toLowerCase();
              final sub =
                  itemSubtitle != null ? itemSubtitle(it).toLowerCase() : '';
              return label.contains(q) || sub.contains(q);
            }).toList();

            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: Row(
                  children: [
                    Icon(itemIcon, size: 20),
                    const SizedBox(width: 8),
                    Text(title, style: const TextStyle(fontSize: 16)),
                  ],
                ),
                content: SizedBox(
                  width: 440,
                  height: 480,
                  child: Column(
                    children: [
                      TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: searchHint,
                          prefixIcon: const Icon(Icons.search, size: 20),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (val) => setPickerState(() => query = val),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(
                                child: Text(
                                  'لا توجد نتائج مطابقة للبحث.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, idx) {
                                  final item = filtered[idx];
                                  return ListTile(
                                    dense: true,
                                    leading: Icon(itemIcon, size: 18),
                                    title: Text(
                                      itemLabel(item),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: itemSubtitle != null
                                        ? Text(itemSubtitle(item))
                                        : null,
                                    onTap: () =>
                                        Navigator.of(dialogCtx).pop(item),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    child: const Text('إلغاء'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openCreateDialog(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    List<HiringManagerOption> managers = [];
    List<String> jobTitles = [];
    List<HiringEmployeeOption> employees = [];

    try {
      final results = await Future.wait([
        widget.repository.getManagers(),
        widget.repository.getJobTitles(),
        widget.repository.getEmployees(),
      ]);
      managers = results[0] as List<HiringManagerOption>;
      jobTitles = results[1] as List<String>;
      employees = results[2] as List<HiringEmployeeOption>;
    } catch (_) {}

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    final nameCtrl = TextEditingController();
    final jobTitleCtrl = TextEditingController();
    final salaryCtrl = TextEditingController();
    HiringManagerOption? selectedManager;
    HiringEmployeeOption? selectedExistingEmployee;
    String currency = 'EGP';
    DateTime assignmentDate = DateTime.now().add(const Duration(days: 1));
    bool isSubmitting = false;

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final dateStr =
              '${assignmentDate.year}-${assignmentDate.month.toString().padLeft(2, '0')}-${assignmentDate.day.toString().padLeft(2, '0')}';
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Row(
                children: const [
                  Icon(Icons.person_add_rounded),
                  SizedBox(width: 8),
                  Text('طلب تعيين جديد'),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Candidate / Employee Name Field with optional search
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'اسم المرشح / الموظف *',
                          hintText: 'اكتب اسم المرشح أو اختر من القائمة...',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: const Icon(Icons.person_outline),
                          suffixIcon: employees.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.search, size: 20),
                                  tooltip: 'اختيار من الموظفين الحاليين',
                                  onPressed: isSubmitting
                                      ? null
                                      : () async {
                                          final picked =
                                              await _showSearchablePicker<
                                                  HiringEmployeeOption>(
                                            context: context,
                                            title:
                                                'اختيار من الموظفين الحاليين',
                                            searchHint:
                                                'ابحث بالاسم أو الكود أو المسمى...',
                                            items: employees,
                                            itemLabel: (e) => e.name,
                                            itemSubtitle: (e) =>
                                                '${e.employeeId} • ${e.department} (${e.jobTitle})'
                                                    .trim(),
                                            itemIcon: Icons.badge_outlined,
                                          );
                                          if (picked != null) {
                                            setDialogState(() {
                                              selectedExistingEmployee = picked;
                                              nameCtrl.text = picked.name;
                                              if (jobTitleCtrl.text.isEmpty &&
                                                  picked.jobTitle.isNotEmpty) {
                                                jobTitleCtrl.text =
                                                    picked.jobTitle;
                                              }
                                            });
                                          }
                                        },
                                )
                              : null,
                        ),
                        onChanged: (val) {
                          if (selectedExistingEmployee != null &&
                              val != selectedExistingEmployee!.name) {
                            setDialogState(
                                () => selectedExistingEmployee = null);
                          }
                        },
                      ),
                      if (selectedExistingEmployee != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.link,
                                  size: 14, color: Colors.blue),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'مرتبط بحساب: ${selectedExistingEmployee!.name} (${selectedExistingEmployee!.employeeId})',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.blue),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              InkWell(
                                onTap: () => setDialogState(
                                    () => selectedExistingEmployee = null),
                                child: const Icon(Icons.close,
                                  size: 14, color: Colors.blue),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Job Title Field with Searchable Dropdown
                      TextField(
                        controller: jobTitleCtrl,
                        decoration: InputDecoration(
                          labelText: 'المسمى الوظيفي *',
                          hintText: 'اختر من القائمة أو اكتب مسمى جديد...',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: const Icon(Icons.work_outline),
                          suffixIcon: IconButton(
                            icon: const Icon(
                                Icons.arrow_drop_down_circle_outlined,
                                size: 20),
                            tooltip: 'اختيار من قائمة المسميات الوظيفية',
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    final picked =
                                        await _showSearchablePicker<String>(
                                      context: context,
                                      title: 'اختر المسمى الوظيفي',
                                      searchHint: 'ابحث عن مسمى وظيفي...',
                                      items: jobTitles,
                                      itemLabel: (t) => t,
                                      itemIcon: Icons.work_outline,
                                    );
                                    if (picked != null) {
                                      setDialogState(() {
                                        jobTitleCtrl.text = picked;
                                      });
                                    }
                                  },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Direct Manager: Searchable Dropdown
                      InkWell(
                        onTap: isSubmitting
                            ? null
                            : () async {
                                final picked =
                                    await _showSearchablePicker<
                                        HiringManagerOption>(
                                  context: context,
                                  title: 'اختر المدير المباشر',
                                  searchHint:
                                      'ابحث باسم المدير أو الكود أو القسم...',
                                  items: managers,
                                  itemLabel: (m) => m.name,
                                  itemSubtitle: (m) {
                                    final parts = <String>[];
                                    if (m.employeeId.isNotEmpty) {
                                      parts.add(m.employeeId);
                                    }
                                    if (m.department.isNotEmpty) {
                                      parts.add(m.department);
                                    }
                                    return parts.join(' • ');
                                  },
                                  itemIcon: Icons.supervisor_account,
                                );
                                if (picked != null) {
                                  setDialogState(() {
                                    selectedManager = picked;
                                  });
                                }
                              },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'المدير المباشر *',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            prefixIcon:
                                const Icon(Icons.supervisor_account_outlined),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (selectedManager != null)
                                  IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: isSubmitting
                                        ? null
                                        : () => setDialogState(
                                            () => selectedManager = null),
                                  ),
                                const Icon(Icons.arrow_drop_down),
                                const SizedBox(width: 8),
                              ],
                            ),
                          ),
                          child: selectedManager != null
                              ? Text(
                                  '${selectedManager!.name} (${selectedManager!.department.isNotEmpty ? selectedManager!.department : selectedManager!.employeeId})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                )
                              : const Text(
                                  'اضغط للبحث واختيار المدير المباشر...',
                                  style: TextStyle(color: Colors.grey),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Salary & Currency
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: salaryCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'الراتب الأساسي الشهري *',
                                border: OutlineInputBorder(),
                                isDense: true,
                                prefixIcon: Icon(Icons.attach_money),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              initialValue: currency,
                              decoration: const InputDecoration(
                                labelText: 'العملة',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'EGP',
                                  child: Text('ج.م (EGP)'),
                                ),
                                DropdownMenuItem(
                                  value: 'USD',
                                  child: Text('USD (\$)'),
                                ),
                                DropdownMenuItem(
                                  value: 'SAR',
                                  child: Text('ريال (SAR)'),
                                ),
                                DropdownMenuItem(
                                  value: 'AED',
                                  child: Text('درهم (AED)'),
                                ),
                              ],
                              onChanged: isSubmitting
                                  ? null
                                  : (val) {
                                      if (val != null) {
                                        setDialogState(() => currency = val);
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Assignment Date
                      OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text('تاريخ بدء العمل: $dateStr'),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: assignmentDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                  locale: const Locale('ar'),
                                );
                                if (picked != null) {
                                  setDialogState(
                                    () => assignmentDate = picked,
                                  );
                                }
                              },
                      ),
                      const SizedBox(height: 14),

                      // Approval Route Box
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Row(
                              children: [
                                Icon(Icons.route,
                                    size: 16, color: Colors.blue),
                                SizedBox(width: 6),
                                Text(
                                  'مسار الموافقات الإلزامي للطلب:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 6),
                            Text(
                              '1. الرئيس التنفيذي (CEO) ➔ 2. مدير تقنية المعلومات (IT) ➔ 3. مدير الحسابات والمالية',
                              style: TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSubmitting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                FilledButton.icon(
                  icon: isSubmitting
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, size: 16),
                  label: const Text('إرسال الطلب'),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          final title = jobTitleCtrl.text.trim();
                          final manager = selectedManager;
                          final salary =
                              double.tryParse(salaryCtrl.text.trim()) ?? 0.0;

                          if (name.isEmpty ||
                              title.isEmpty ||
                              manager == null) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'يرجى ملء جميع الحقول المطلوبة واختيار المدير المباشر.',
                                ),
                              ),
                            );
                            return;
                          }
                          if (salary <= 0) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('أدخل راتباً أساسياً صحيحاً.'),
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);
                          try {
                            await widget.repository.create(
                              name: name,
                              jobTitle: title,
                              managerId: manager.id,
                              managerName: manager.name,
                              salary: salary,
                              currency: currency,
                              assignmentDate: assignmentDate,
                              existingEmployeeUid:
                                  selectedExistingEmployee?.id,
                            );
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            _reload();
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'تم إنشاء طلب تعيين $name بنجاح وإرساله للمسار.',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('$e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                ),
              ],
            ),
          );
        },
      ),
    );

    nameCtrl.dispose();
    jobTitleCtrl.dispose();
    salaryCtrl.dispose();
  }

  String _translateStatus(String status) {
    switch (status) {
      case 'pending_ceo':
        return 'بانتظار موافقة الرئيس التنفيذي';
      case 'pending_it':
        return 'بانتظار موافقة مدير تقنية المعلومات';
      case 'pending_accounts':
        return 'بانتظار موافقة مدير الحسابات';
      case 'approved':
        return 'تمت الموافقة النهائية';
      case 'rejected':
        return 'مرفوض';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: const Text('طلبات التعيين')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openCreateDialog(context),
            label: const Text('طلب تعيين جديد'),
            icon: const Icon(Icons.person_add),
          ),
          body: FutureBuilder<List<HiringRequest>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('${snapshot.error}'));
              }
              final rows = snapshot.data ?? const <HiringRequest>[];
              if (rows.isEmpty) {
                return const Center(
                  child: Text('لا توجد طلبات تعيين مسجلة.'),
                );
              }
              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final isApproved = row.status == 'approved';
                    final isRejected = row.status == 'rejected';
                    final statusColor = isApproved
                        ? Colors.green
                        : isRejected
                            ? Colors.red
                            : Colors.orange;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: statusColor.withValues(alpha: 0.15),
                          child: Icon(
                            isApproved
                                ? Icons.check
                                : isRejected
                                    ? Icons.close
                                    : Icons.hourglass_top,
                            color: statusColor,
                          ),
                        ),
                        title: Text(
                          row.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text('المسمى الوظيفي: ${row.jobTitle}'),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _translateStatus(row.status),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (row.currentApproverName.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'بانتظار: ${row.currentApproverName}',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<bool>(
                          onSelected: (approved) => _decide(row, approved),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: true, child: Text('موافقة')),
                            PopupMenuItem(value: false, child: Text('رفض')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      );
}
