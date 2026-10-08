import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/custom_request_template.dart';
import '../../domain/repositories/custom_request_template_repository.dart';
import '../cubit/request_chains_settings_cubit.dart';

class ApprovalChainsSettingsPage extends StatelessWidget {
  const ApprovalChainsSettingsPage({required this.repository, super.key});

  final CustomRequestTemplateRepository repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RequestChainsSettingsCubit(repository: repository)..loadRequestTypes(),
      child: const _ApprovalChainsSettingsView(),
    );
  }
}

class _ApprovalChainsSettingsView extends StatefulWidget {
  const _ApprovalChainsSettingsView();

  @override
  State<_ApprovalChainsSettingsView> createState() => _ApprovalChainsSettingsViewState();
}

class _ApprovalChainsSettingsViewState extends State<_ApprovalChainsSettingsView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات الطلبات ومسارات الاعتماد (Dynamic Request Engine)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () => context.read<RequestChainsSettingsCubit>().loadRequestTypes(),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'إضافة نوع طلب جديد',
            onPressed: () => _openEditDialog(context, null),
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: BlocConsumer<RequestChainsSettingsCubit, RequestChainsSettingsState>(
          listener: (context, state) {
            if (state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.errorMessage!), backgroundColor: Colors.red),
              );
            }
            if (state.successMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.successMessage!), backgroundColor: Colors.green),
              );
            }
          },
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.requestTypes.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.rule_folder_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('لا توجد أنواع طلبات مخصصة حتى الآن.'),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _openEditDialog(context, null),
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة أول نوع طلب'),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.requestTypes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = state.requestTypes[index];
                return Card(
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: item.isActive ? Colors.blue.shade100 : Colors.grey.shade200,
                      child: Icon(
                        item.category == 'leave'
                            ? Icons.beach_access
                            : item.category == 'permission'
                                ? Icons.timer
                                : item.category == 'financial'
                                    ? Icons.account_balance_wallet
                                    : item.category == 'administrative'
                                        ? Icons.business_center
                                        : Icons.assignment,
                        color: item.isActive ? Colors.blue.shade800 : Colors.grey,
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          item.nameAr,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        if (item.id.startsWith('core_')) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              'طلب أساسي بالنظام',
                              style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('التصنيف: ${_categoryLabel(item.category)} | الحقول: ${item.fields.length} | مراحل الاعتماد: ${item.approvalSteps.length}'),
                        if (item.approvalSteps.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.route, size: 16, color: Colors.teal),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'مسار الاعتماد: ${item.approvalSteps.map((s) => s.labelAr.isNotEmpty ? s.labelAr : s.approverType).join(' ⬅️ ')}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.teal,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (item.subtypes.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: item.subtypes.map((st) => Chip(
                                label: Text(st, style: const TextStyle(fontSize: 11)),
                                visualDensity: VisualDensity.compact,
                              )).toList(),
                            ),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'تعديل الطلب ومسار الاعتماد',
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _openEditDialog(context, item),
                        ),
                        if (!item.id.startsWith('core_'))
                          IconButton(
                            tooltip: 'حذف',
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _confirmDelete(context, item),
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
    );
  }

  String _categoryLabel(String cat) => switch (cat) {
        'leave' => 'إجازة',
        'permission' => 'إذن',
        'financial' => 'مالي / سلفة',
        'administrative' => 'إداري',
        _ => 'عام',
      };

  void _confirmDelete(BuildContext context, CustomRequestType item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف نوع الطلب'),
        content: Text('هل أنت متأكد من حذف نوع الطلب "${item.nameAr}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<RequestChainsSettingsCubit>().deleteRequestType(item.id);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openEditDialog(BuildContext parentContext, CustomRequestType? existing) {
    showDialog(
      context: parentContext,
      builder: (ctx) => _EditRequestTypeDialog(
        existing: existing,
        onSave: (savedType) {
          parentContext.read<RequestChainsSettingsCubit>().saveRequestType(savedType);
        },
      ),
    );
  }
}

class _EditRequestTypeDialog extends StatefulWidget {
  final CustomRequestType? existing;
  final ValueChanged<CustomRequestType> onSave;

  const _EditRequestTypeDialog({this.existing, required this.onSave});

  @override
  State<_EditRequestTypeDialog> createState() => _EditRequestTypeDialogState();
}

class _EditRequestTypeDialogState extends State<_EditRequestTypeDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _quotaCountCtrl;
  late TextEditingController _quotaHoursCtrl;
  late String _category;
  late bool _isActive;
  late List<CustomSubtypeConfig> _subtypeConfigs;
  late List<CustomRequestField> _fields;
  late List<ApprovalChainStep> _approvalSteps;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.nameAr ?? '');
    _descController = TextEditingController(text: widget.existing?.descriptionAr ?? '');
    _category = widget.existing?.category ?? 'general';
    _isActive = widget.existing?.isActive ?? true;

    final existingConfigs = widget.existing?.subtypeConfigs;
    if (existingConfigs != null && existingConfigs.isNotEmpty) {
      _subtypeConfigs = List<CustomSubtypeConfig>.from(existingConfigs);
    } else {
      _subtypeConfigs = (widget.existing?.subtypes ?? [])
          .map((st) => CustomSubtypeConfig(nameAr: st))
          .toList();
    }

    _quotaCountCtrl = TextEditingController(
      text: widget.existing?.monthlyQuotaCount?.toString() ?? '',
    );
    _quotaHoursCtrl = TextEditingController(
      text: widget.existing?.monthlyQuotaHours?.toString() ?? '',
    );
    _fields = List<CustomRequestField>.from(widget.existing?.fields ?? []);
    _approvalSteps = List<ApprovalChainStep>.from(widget.existing?.approvalSteps ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _quotaCountCtrl.dispose();
    _quotaHoursCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          width: 860,
          height: 740,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.existing == null ? 'إضافة نوع طلب جديد' : 'تعديل نوع الطلب: ${widget.existing!.nameAr}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _nameController,
                              decoration: const InputDecoration(labelText: 'اسم نوع الطلب (مثل: إجازة خاصة، مأمورية خارجية)'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          DropdownButton<String>(
                            value: _category,
                            items: const [
                              DropdownMenuItem(value: 'leave', child: Text('إجازة')),
                              DropdownMenuItem(value: 'permission', child: Text('إذن')),
                              DropdownMenuItem(value: 'financial', child: Text('مالي')),
                              DropdownMenuItem(value: 'administrative', child: Text('إداري')),
                              DropdownMenuItem(value: 'general', child: Text('عام')),
                            ],
                            onChanged: (val) => setState(() => _category = val ?? 'general'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _descController,
                        decoration: const InputDecoration(labelText: 'الوصف أو التعليمات'),
                      ),
                      const SizedBox(height: 16),

                      if (_category == 'permission') ...[
                        _buildPermissionQuotaSection(),
                        const Divider(height: 32),
                      ],

                      _buildSubtypesSection(),
                      const Divider(height: 32),

                      _buildFieldsSection(),
                      const Divider(height: 32),

                      _buildApprovalStepsSection(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (_nameController.text.trim().isEmpty) return;
                      final countQuota = int.tryParse(_quotaCountCtrl.text.trim());
                      final hoursQuota = double.tryParse(_quotaHoursCtrl.text.trim());
                      final updated = CustomRequestType(
                        id: widget.existing?.id ?? '',
                        nameAr: _nameController.text.trim(),
                        category: _category,
                        descriptionAr: _descController.text.trim(),
                        isActive: _isActive,
                        subtypes: _subtypeConfigs.map((c) => c.nameAr).toList(),
                        subtypeConfigs: _subtypeConfigs,
                        fields: _fields,
                        approvalSteps: _approvalSteps,
                        monthlyQuotaCount: countQuota,
                        monthlyQuotaHours: hoursQuota,
                        updatedAt: DateTime.now(),
                      );
                      widget.onSave(updated);
                      Navigator.pop(context);
                    },
                    child: const Text('حفظ الإعدادات'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionQuotaSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timer, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                'التحكم في حصة وساعات الأذونات الشهرية:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quotaCountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'الحد الأقصى لعدد مرات الإذن شهرياً',
                    hintText: 'مثال: 2',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _quotaHoursCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'الحد الأقصى لإجمالي ساعات الإذن شهرياً',
                    hintText: 'مثال: 4.0',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _quotaKeyLabel(String key) => switch (key) {
        'casual' => 'عارضة',
        'permissions' => 'أذونات',
        'none' => 'بدون خصم',
        _ => 'سنوية / اعتيادية',
      };

  void _openSubtypeConfigDialog(CustomSubtypeConfig? existing, int? index) {
    final nameCtrl = TextEditingController(text: existing?.nameAr ?? '');
    bool deducts = existing?.deductsFromQuota ?? true;
    String quotaKey = existing?.quotaKey ?? (_category == 'permission' ? 'permissions' : 'daysOff');
    bool reqAttach = existing?.requiresAttachment ?? false;
    final maxDaysCtrl = TextEditingController(text: existing?.maxDays?.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(existing == null ? 'إضافة نوع فرعي جديد' : 'تعديل النوع الفرعي'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'اسم النوع الفرعي (مثل: إجازة حج، إذن صباحي)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('يخصم من الرصيد'),
                      subtitle: const Text('هل يتم احتساب هذا النوع وخصمه من الرصيد الدوري؟'),
                      value: deducts,
                      onChanged: (val) => setDlgState(() => deducts = val),
                    ),
                    if (deducts) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: quotaKey,
                        decoration: const InputDecoration(
                          labelText: 'نوع الرصيد المرتبط بالخصم',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'daysOff', child: Text('رصيد الإجازات السنوية / الاعتيادية')),
                          DropdownMenuItem(value: 'casual', child: Text('رصيد الإجازات العارضة')),
                          DropdownMenuItem(value: 'permissions', child: Text('رصيد ساعات الأذونات')),
                          DropdownMenuItem(value: 'none', child: Text('رصيد مخصص / آخر')),
                        ],
                        onChanged: (val) => setDlgState(() => quotaKey = val ?? 'daysOff'),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('مرفق إلزامي (مستند / تقرير)'),
                      subtitle: const Text('إلزام الموظف برفع مستند لإتمام الطلب'),
                      value: reqAttach,
                      onChanged: (val) => setDlgState(() => reqAttach = val),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: maxDaysCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'الحد الأقصى للأيام المسموحة (اختياري)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final maxDays = int.tryParse(maxDaysCtrl.text.trim());
                  final cfg = CustomSubtypeConfig(
                    nameAr: name,
                    deductsFromQuota: deducts,
                    quotaKey: quotaKey,
                    requiresAttachment: reqAttach,
                    maxDays: maxDays,
                  );
                  setState(() {
                    if (index != null && index >= 0 && index < _subtypeConfigs.length) {
                      _subtypeConfigs[index] = cfg;
                    } else {
                      _subtypeConfigs.add(cfg);
                    }
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubtypesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'الأنواع الفرعية والخصائص (Subtypes & Quotas):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('إضافة نوع فرعي جديد'),
              onPressed: () => _openSubtypeConfigDialog(null, null),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_subtypeConfigs.isEmpty)
          const Text('لا توجد أنواع فرعية مضافة بعد. اضغط "إضافة نوع فرعي" للبدء.')
        else
          ..._subtypeConfigs.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                dense: true,
                title: Text(item.nameAr, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(item.deductsFromQuota ? Icons.remove_circle : Icons.do_not_disturb_on, size: 14),
                      label: Text(
                        item.deductsFromQuota ? 'يخصم: ${_quotaKeyLabel(item.quotaKey)}' : 'لا يخصم من الرصيد',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    if (item.requiresAttachment)
                      const Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(Icons.attach_file, size: 14),
                        label: Text('مرفق إلزامي', style: TextStyle(fontSize: 10)),
                      ),
                    if (item.maxDays != null)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(Icons.calendar_today, size: 14),
                        label: Text('الحد: ${item.maxDays} يوم', style: TextStyle(fontSize: 10)),
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                      tooltip: 'تعديل الخصائص',
                      onPressed: () => _openSubtypeConfigDialog(item, idx),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                      tooltip: 'حذف',
                      onPressed: () => setState(() => _subtypeConfigs.removeAt(idx)),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildFieldsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('حقول النموذج (Form Fields):', style: TextStyle(fontWeight: FontWeight.bold)),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('إضافة حقل'),
              onPressed: () {
                setState(() {
                  _fields.add(CustomRequestField(
                    key: 'field_${DateTime.now().millisecondsSinceEpoch}',
                    labelAr: 'حقل جديد',
                    type: 'text',
                  ));
                });
              },
            ),
          ],
        ),
        if (_fields.isEmpty) const Text('لا توجد حقول إضافية محددة. سيتم استخدام الحقول الافتراضية.'),
        ..._fields.asMap().entries.map((entry) {
          final idx = entry.key;
          final f = entry.value;
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      initialValue: f.labelAr,
                      decoration: const InputDecoration(labelText: 'عنوان الحقل'),
                      onChanged: (val) {
                        _fields[idx] = CustomRequestField(
                          key: f.key,
                          labelAr: val,
                          type: f.type,
                          isRequired: f.isRequired,
                          dropdownOptions: f.dropdownOptions,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: f.type,
                    items: const [
                      DropdownMenuItem(value: 'text', child: Text('نص')),
                      DropdownMenuItem(value: 'number', child: Text('رقم')),
                      DropdownMenuItem(value: 'date', child: Text('تاريخ / أيام')),
                      DropdownMenuItem(value: 'checkbox', child: Text('موافقة / نعم-لا')),
                      DropdownMenuItem(value: 'upload', child: Text('مرفق ملف')),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _fields[idx] = CustomRequestField(
                          key: f.key,
                          labelAr: f.labelAr,
                          type: val ?? 'text',
                          isRequired: f.isRequired,
                          dropdownOptions: f.dropdownOptions,
                        );
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      const Text('إلزامي'),
                      Checkbox(
                        value: f.isRequired,
                        onChanged: (val) {
                          setState(() {
                            _fields[idx] = CustomRequestField(
                              key: f.key,
                              labelAr: f.labelAr,
                              type: f.type,
                              isRequired: val ?? false,
                              dropdownOptions: f.dropdownOptions,
                            );
                          });
                        },
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () => setState(() => _fields.removeAt(idx)),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildApprovalStepsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('سلسلة الاعتماد (Approval Chain - مراحل غير محدودة):', style: TextStyle(fontWeight: FontWeight.bold)),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('إضافة مرحلة اعتماد'),
              onPressed: () {
                setState(() {
                  _approvalSteps.add(ApprovalChainStep(
                    stepId: 'step_${DateTime.now().millisecondsSinceEpoch}',
                    order: _approvalSteps.length + 1,
                    approverType: 'direct_manager',
                    labelAr: 'المرحلة ${_approvalSteps.length + 1}',
                  ));
                });
              },
            ),
          ],
        ),
        if (_approvalSteps.isEmpty) const Text('لم يتم تحديد مسار اعتماد مخصص. سيتبع المسار القياسي الافتراضي.'),
        ..._approvalSteps.asMap().entries.map((entry) {
          final idx = entry.key;
          final s = entry.value;
          return Card(
            key: ValueKey(s.stepId),
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        child: Text('${idx + 1}', style: const TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: const ['direct_manager', 'it', 'hr', 'accounting', 'legal', 'department_pool', 'coo', 'ceo'].contains(s.approverType)
                              ? s.approverType
                              : 'direct_manager',
                          items: const [
                            DropdownMenuItem(value: 'direct_manager', child: Text('المدير المباشر (Direct Manager)')),
                            DropdownMenuItem(value: 'it', child: Text('إدارة تقنية المعلومات (IT Department)')),
                            DropdownMenuItem(value: 'hr', child: Text('الموارد البشرية (HR Admin)')),
                            DropdownMenuItem(value: 'accounting', child: Text('الحسابات والمالية (Accounts / Finance)')),
                            DropdownMenuItem(value: 'legal', child: Text('الشؤون القانونية (Legal Department)')),
                            DropdownMenuItem(value: 'coo', child: Text('المدير التنفيذي للعمليات (COO)')),
                            DropdownMenuItem(value: 'ceo', child: Text('الرئيس التنفيذي (CEO)')),
                            DropdownMenuItem(value: 'department_pool', child: Text('أي موظف في قسم مخصص (Pool)')),
                          ],
                          onChanged: (val) {
                            final type = val ?? 'direct_manager';
                            final dept = type == 'it'
                                ? 'it'
                                : type == 'hr'
                                    ? 'hr'
                                    : type == 'accounting'
                                        ? 'accounting'
                                        : type == 'legal'
                                            ? 'legal'
                                            : s.department;
                            final defaultLabel = switch (type) {
                              'it' => 'إدارة تقنية المعلومات (IT)',
                              'hr' => 'الموارد البشرية (HR)',
                              'accounting' => 'الحسابات والمالية',
                              'legal' => 'الشؤون القانونية (Legal)',
                              'coo' => 'المدير التنفيذي للعمليات (COO)',
                              'ceo' => 'الرئيس التنفيذي (CEO)',
                              'department_pool' => 'قسم محدد',
                              _ => 'المدير المباشر',
                            };
                            setState(() {
                              _approvalSteps[idx] = ApprovalChainStep(
                                stepId: s.stepId,
                                order: idx + 1,
                                approverType: type,
                                labelAr: defaultLabel,
                                department: dept,
                                conditionType: s.conditionType,
                                minDays: s.minDays,
                                maxDays: s.maxDays,
                                minAmount: s.minAmount,
                                maxAmount: s.maxAmount,
                                applicableSubtypes: s.applicableSubtypes,
                              );
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          key: ValueKey('label_${s.stepId}_${s.approverType}'),
                          initialValue: s.labelAr,
                          decoration: const InputDecoration(
                            labelText: 'مسمى المرحلة',
                            hintText: 'مثال: تقنية المعلومات (IT)',
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          onChanged: (text) {
                            _approvalSteps[idx] = ApprovalChainStep(
                              stepId: s.stepId,
                              order: s.order,
                              approverType: s.approverType,
                              labelAr: text,
                              department: s.department,
                              specificUserId: s.specificUserId,
                              specificUserName: s.specificUserName,
                              conditionType: s.conditionType,
                              minDays: s.minDays,
                              maxDays: s.maxDays,
                              minAmount: s.minAmount,
                              maxAmount: s.maxAmount,
                              applicableSubtypes: s.applicableSubtypes,
                            );
                          },
                        ),
                      ),
                      if (s.approverType == 'department_pool') ...[
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: s.department ?? 'it',
                            items: const [
                              DropdownMenuItem(value: 'it', child: Text('تقنية المعلومات (IT)')),
                              DropdownMenuItem(value: 'hr', child: Text('الموارد البشرية (HR)')),
                              DropdownMenuItem(value: 'accounting', child: Text('الحسابات (Accounts)')),
                              DropdownMenuItem(value: 'legal', child: Text('الشؤون القانونية (Legal)')),
                            ],
                            onChanged: (dept) {
                              setState(() {
                                _approvalSteps[idx] = ApprovalChainStep(
                                  stepId: s.stepId,
                                  order: idx + 1,
                                  approverType: s.approverType,
                                  labelAr: 'فريق ${dept == "it" ? "تقنية المعلومات" : dept == "hr" ? "الموارد البشرية" : dept == "accounting" ? "الحسابات" : "القانونية"}',
                                  department: dept,
                                  conditionType: s.conditionType,
                                  minDays: s.minDays,
                                  maxDays: s.maxDays,
                                  minAmount: s.minAmount,
                                  maxAmount: s.maxAmount,
                                  applicableSubtypes: s.applicableSubtypes,
                                );
                              });
                            },
                          ),
                        ),
                      ],
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                        onPressed: () => setState(() => _approvalSteps.removeAt(idx)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.tune, size: 16, color: Colors.indigo),
                        const SizedBox(width: 8),
                        const Text('شرط تفعيل المرحلة:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          isDense: true,
                          value: const ['always', 'days_threshold', 'amount_threshold'].contains(s.conditionType)
                              ? s.conditionType
                              : 'always',
                          items: const [
                            DropdownMenuItem(value: 'always', child: Text('دائماً (لجميع الطلبات)')),
                            DropdownMenuItem(value: 'days_threshold', child: Text('إذا كان عدد الأيام ≥')),
                            DropdownMenuItem(value: 'amount_threshold', child: Text('إذا كان المبلغ ≥')),
                          ],
                          onChanged: (cond) {
                            setState(() {
                              _approvalSteps[idx] = ApprovalChainStep(
                                stepId: s.stepId,
                                order: s.order,
                                approverType: s.approverType,
                                labelAr: s.labelAr,
                                department: s.department,
                                specificUserId: s.specificUserId,
                                specificUserName: s.specificUserName,
                                conditionType: cond ?? 'always',
                                minDays: cond == 'days_threshold' ? (s.minDays ?? 3) : null,
                                minAmount: cond == 'amount_threshold' ? (s.minAmount ?? 5000) : null,
                                applicableSubtypes: s.applicableSubtypes,
                              );
                            });
                          },
                        ),
                        if (s.conditionType == 'days_threshold') ...[
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 80,
                            child: TextFormField(
                              key: ValueKey('days_${s.stepId}'),
                              initialValue: s.minDays?.toString() ?? '3',
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(isDense: true, suffixText: 'يوم'),
                              onChanged: (val) {
                                _approvalSteps[idx] = ApprovalChainStep(
                                  stepId: s.stepId,
                                  order: s.order,
                                  approverType: s.approverType,
                                  labelAr: s.labelAr,
                                  department: s.department,
                                  specificUserId: s.specificUserId,
                                  specificUserName: s.specificUserName,
                                  conditionType: s.conditionType,
                                  minDays: int.tryParse(val.trim()),
                                  applicableSubtypes: s.applicableSubtypes,
                                );
                              },
                            ),
                          ),
                        ],
                        if (s.conditionType == 'amount_threshold') ...[
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 100,
                            child: TextFormField(
                              key: ValueKey('amt_${s.stepId}'),
                              initialValue: s.minAmount?.toString() ?? '5000',
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(isDense: true, suffixText: 'ج.م'),
                              onChanged: (val) {
                                _approvalSteps[idx] = ApprovalChainStep(
                                  stepId: s.stepId,
                                  order: s.order,
                                  approverType: s.approverType,
                                  labelAr: s.labelAr,
                                  department: s.department,
                                  specificUserId: s.specificUserId,
                                  specificUserName: s.specificUserName,
                                  conditionType: s.conditionType,
                                  minAmount: double.tryParse(val.trim()),
                                  applicableSubtypes: s.applicableSubtypes,
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
