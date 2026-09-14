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

  Future<void> _openCreateDialog(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final nameCtrl = TextEditingController();
    final jobTitleCtrl = TextEditingController();
    final managerNameCtrl = TextEditingController();
    final managerIdCtrl = TextEditingController();
    final salaryCtrl = TextEditingController();
    String currency = 'EGP';
    DateTime assignmentDate = DateTime.now().add(const Duration(days: 1));
    bool isSubmitting = false;

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
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'اسم المرشح / الموظف *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: jobTitleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'المسمى الوظيفي *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: managerNameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'اسم المدير المباشر *',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: managerIdCtrl,
                              decoration: const InputDecoration(
                                labelText: 'معرف المدير (ID) *',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
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
                              onChanged:
                                  isSubmitting
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
                      OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text('تاريخ بدء العمل: $dateStr'),
                        onPressed:
                            isSubmitting
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
                  icon:
                      isSubmitting
                          ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.send_rounded, size: 16),
                  label: const Text('إرسال الطلب'),
                  onPressed:
                      isSubmitting
                          ? null
                          : () async {
                            final name = nameCtrl.text.trim();
                            final title = jobTitleCtrl.text.trim();
                            final mName = managerNameCtrl.text.trim();
                            final mId = managerIdCtrl.text.trim();
                            final salary =
                                double.tryParse(salaryCtrl.text.trim()) ?? 0.0;

                            if (name.isEmpty ||
                                title.isEmpty ||
                                mName.isEmpty ||
                                mId.isEmpty) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'يرجى ملء جميع الحقول المطلوبة.',
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
                                managerId: mId,
                                managerName: mName,
                                salary: salary,
                                currency: currency,
                                assignmentDate: assignmentDate,
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
                                    backgroundColor: Colors.redAccent,
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
    managerNameCtrl.dispose();
    managerIdCtrl.dispose();
    salaryCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('طلبات التعيين')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateDialog(context),
        label: const Text('طلب تعيين'),
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
              child: Text('لا توجد طلبات تعيين تحتاج إجراء.'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                return Card(
                  child: ListTile(
                    title: Text(row.name),
                    subtitle: Text(
                      '${row.jobTitle}\n${row.status}${row.currentApproverName.isEmpty ? '' : ' • بانتظار ${row.currentApproverName}'}',
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<bool>(
                      onSelected: (approved) => _decide(row, approved),
                      itemBuilder:
                          (_) => const [
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
