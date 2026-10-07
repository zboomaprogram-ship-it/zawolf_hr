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
                                : Icons.assignment,
                        color: item.isActive ? Colors.blue.shade800 : Colors.grey,
                      ),
                    ),
                    title: Text(
                      item.nameAr,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('التصنيف: ${_categoryLabel(item.category)} | الحقول: ${item.fields.length} | مراحل الاعتماد: ${item.approvalSteps.length}'),
                        if (item.subtypes.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              spacing: 6,
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
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _openEditDialog(context, item),
                        ),
                        IconButton(
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
  late String _category;
  late bool _isActive;
  late List<String> _subtypes;
  late List<CustomRequestField> _fields;
  late List<ApprovalChainStep> _approvalSteps;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.nameAr ?? '');
    _descController = TextEditingController(text: widget.existing?.descriptionAr ?? '');
    _category = widget.existing?.category ?? 'general';
    _isActive = widget.existing?.isActive ?? true;
    _subtypes = List<String>.from(widget.existing?.subtypes ?? []);
    _fields = List<CustomRequestField>.from(widget.existing?.fields ?? []);
    _approvalSteps = List<ApprovalChainStep>.from(widget.existing?.approvalSteps ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          width: 800,
          height: 700,
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
                      final updated = CustomRequestType(
                        id: widget.existing?.id ?? '',
                        nameAr: _nameController.text.trim(),
                        category: _category,
                        descriptionAr: _descController.text.trim(),
                        isActive: _isActive,
                        subtypes: _subtypes,
                        fields: _fields,
                        approvalSteps: _approvalSteps,
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

  Widget _buildSubtypesSection() {
    final subCtrl = TextEditingController();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('الأنواع الفرعية المندرجة (Subtypes - مثل: إجازة حج، زواج، حداد...):', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _subtypes.map((st) => Chip(
            label: Text(st),
            onDeleted: () => setState(() => _subtypes.remove(st)),
          )).toList(),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: subCtrl,
                decoration: const InputDecoration(hintText: 'أضف نوع فرعي جديد (اضغط إضافة)'),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.green),
              onPressed: () {
                final txt = subCtrl.text.trim();
                if (txt.isNotEmpty && !_subtypes.contains(txt)) {
                  setState(() => _subtypes.add(txt));
                  subCtrl.clear();
                }
              },
            ),
          ],
        ),
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
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    child: Text('${idx + 1}', style: const TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: s.approverType,
                      items: const [
                        DropdownMenuItem(value: 'direct_manager', child: Text('المدير المباشر (Direct Manager)')),
                        DropdownMenuItem(value: 'department_pool', child: Text('أي موظف في قسم محدد (Pool)')),
                        DropdownMenuItem(value: 'coo', child: Text('المدير التنفيذي للعمليات (COO)')),
                        DropdownMenuItem(value: 'ceo', child: Text('الرئيس التنفيذي (CEO)')),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _approvalSteps[idx] = ApprovalChainStep(
                            stepId: s.stepId,
                            order: idx + 1,
                            approverType: val ?? 'direct_manager',
                            labelAr: s.labelAr,
                            department: s.department,
                          );
                        });
                      },
                    ),
                  ),
                  if (s.approverType == 'department_pool') ...[
                    const SizedBox(width: 8),
                    Expanded(
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
                              labelAr: s.labelAr,
                              department: dept,
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
            ),
          );
        }),
      ],
    );
  }
}
