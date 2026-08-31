import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';

import '../../domain/entities/company_os_attachment_reference.dart';
import '../../domain/entities/operational_request_category.dart';
import '../../domain/entities/unified_operational_request.dart';
import '../../domain/repositories/company_os_attachment_repository.dart';
import '../../domain/repositories/operational_request_repository.dart';
import '../cubit/operational_request_detail_cubit.dart';
import '../cubit/operational_request_submit_cubit.dart';
import '../widgets/approval_journey.dart';

class OperationalRequestFormPage extends StatefulWidget {
  const OperationalRequestFormPage({
    super.key,
    required this.repository,
    this.attachmentRepository,
    this.initialCategory,
  });
  final OperationalRequestRepository repository;
  final CompanyOsAttachmentRepository? attachmentRepository;

  /// Keeps financial and technical requests separate in the employee journey
  /// without changing the persisted request type or approval workflow.
  final OperationalRequestCategory? initialCategory;

  @override
  State<OperationalRequestFormPage> createState() =>
      _OperationalRequestFormPageState();
}

class _OperationalRequestFormPageState
    extends State<OperationalRequestFormPage> {
  final reason = TextEditingController();
  final amount = TextEditingController();
  late String type;
  OperationalRequestCategory? _selectedCategory;
  final List<CompanyOsAttachmentReference> _attachments = [];
  bool _uploadingAttachment = false;

  static const _technicalTypes = <String, String>{
    'access': 'طلب صلاحية أو وصول',
    'asset_purchase': 'شراء أصل تقني',
    'repair_maintenance': 'إصلاح أو صيانة',
    'software_license': 'ترخيص برنامج',
  };
  static const _financialTypes = <String, String>{
    'reimbursement': 'استرداد مصروف',
    'custody': 'عهدة مالية',
    'payment': 'طلب دفع',
    'other_expense': 'مصروف آخر',
  };
  static const _costBearingTypes = <String>{
    'reimbursement',
    'custody',
    'payment',
    'other_expense',
    'asset_purchase',
    'repair_maintenance',
    'software_license',
  };

  Map<String, String> _typesFor(OperationalRequestCategory? category) =>
      switch (category) {
        OperationalRequestCategory.technical => _technicalTypes,
        OperationalRequestCategory.financial => _financialTypes,
        null => {..._technicalTypes, ..._financialTypes},
      };

  Map<String, String> get _requestTypes => _typesFor(_selectedCategory);
  bool get _requiresAmount => _costBearingTypes.contains(type);

  String get _title => switch (_selectedCategory) {
    OperationalRequestCategory.technical => 'خدمات تقنية وتشغيلية',
    OperationalRequestCategory.financial => 'مصروفات ومدفوعات الشركة',
    null => 'طلب خدمة الشركة',
  };

  @override
  void initState() {
    super.initState();
    _selectedCategory =
        widget.initialCategory ?? OperationalRequestCategory.technical;
    type = _requestTypes.keys.first;
  }

  void _selectCategory(OperationalRequestCategory category) {
    if (_selectedCategory == category) return;
    setState(() {
      _selectedCategory = category;
      type = _requestTypes.keys.first;
      amount.clear();
    });
  }

  void _selectType(String? value) {
    if (value == null || value == type) return;
    setState(() {
      type = value;
      if (!_requiresAmount) amount.clear();
    });
  }

  String _contentTypeFor(PlatformFile file) {
    final extension = (file.extension ?? '').toLowerCase();
    return switch (extension) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      _ => 'application/octet-stream',
    };
  }

  Future<void> _addAttachments() async {
    final repository = widget.attachmentRepository;
    if (repository == null || _uploadingAttachment) return;
    final selection = await FilePicker.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.any,
    );
    if (selection == null || !mounted) return;
    final files = selection.files;
    if (files.any(
      (file) =>
          file.bytes == null ||
          file.bytes!.isEmpty ||
          file.size > 10 * 1024 * 1024,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اختر ملفات صالحة بحجم لا يتجاوز 10 ميغابايت للملف.'),
        ),
      );
      return;
    }
    if (_attachments.length + files.length > 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يمكن إرفاق عشرة ملفات كحد أقصى.')),
      );
      return;
    }
    setState(() => _uploadingAttachment = true);
    try {
      final uploaded = <CompanyOsAttachmentReference>[];
      for (final file in files) {
        uploaded.add(
          await repository.upload(
            ownerUid: '',
            displayName: file.name,
            contentType: _contentTypeFor(file),
            bytes: file.bytes!,
          ),
        );
      }
      if (!mounted) return;
      setState(() => _attachments.addAll(uploaded));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم رفع ${uploaded.length} مرفق إلى ملفات الشركة.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر رفع المرفق. تحقق من الاتصال ثم أعد المحاولة.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _uploadingAttachment = false);
    }
  }

  @override
  void dispose() {
    reason.dispose();
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => OperationalRequestSubmitCubit(widget.repository),
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(_title)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.initialCategory == null) ...[
              const Text(
                'اختر مسار الطلب',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('خدمات تقنية وتشغيلية'),
                    avatar: const Icon(Icons.build_outlined, size: 18),
                    selected:
                        _selectedCategory ==
                        OperationalRequestCategory.technical,
                    onSelected: (_) =>
                        _selectCategory(OperationalRequestCategory.technical),
                  ),
                  ChoiceChip(
                    label: const Text('مصروفات ومدفوعات الشركة'),
                    avatar: const Icon(Icons.payments_outlined, size: 18),
                    selected:
                        _selectedCategory ==
                        OperationalRequestCategory.financial,
                    onSelected: (_) =>
                        _selectCategory(OperationalRequestCategory.financial),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'نوع الطلب'),
              items: _requestTypes.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _selectType,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reason,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'سبب العمل'),
            ),
            const SizedBox(height: 16),
            if (_requiresAmount) ...[
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'المبلغ المطلوب',
                  helperText:
                      'هذا النوع من الطلبات يتطلب مبلغاً للمراجعة المالية.',
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed:
                  _uploadingAttachment || widget.attachmentRepository == null
                  ? null
                  : _addAttachments,
              icon: _uploadingAttachment
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.attach_file_outlined),
              label: Text(
                _uploadingAttachment
                    ? 'جارٍ رفع المرفقات…'
                    : 'إرفاق ملفات داعمة',
              ),
            ),
            if (_attachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _attachments
                    .map(
                      (attachment) => InputChip(
                        label: Text(attachment.displayName),
                        onDeleted: () =>
                            setState(() => _attachments.remove(attachment)),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
            const SizedBox(height: 24),
            BlocConsumer<
              OperationalRequestSubmitCubit,
              OperationalRequestSubmitState
            >(
              listener: (context, state) {
                final message = switch (state) {
                  OperationalRequestSubmitted(:final message) => message,
                  OperationalRequestSubmitFailure(:final message) => message,
                  _ => null,
                };
                if (message != null) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text(message)));
                }
              },
              builder: (context, state) => FilledButton(
                onPressed:
                    state is OperationalRequestSubmitting ||
                        _uploadingAttachment
                    ? null
                    : () {
                        final requestedAmount = num.tryParse(amount.text);
                        if (_requiresAmount && requestedAmount == null) {
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(
                                content: Text('أدخل مبلغاً صحيحاً للطلب.'),
                              ),
                            );
                          return;
                        }
                        context.read<OperationalRequestSubmitCubit>().submit(
                          requestType: type,
                          businessReason: reason.text,
                          executionDate: DateTime.now(),
                          amount: _requiresAmount ? requestedAmount : null,
                          currency: _requiresAmount ? 'EGP' : null,
                          attachments: _attachments,
                        );
                      },
                child: Text(
                  state is OperationalRequestSubmitting
                      ? 'جارٍ الحفظ…'
                      : 'إرسال الطلب',
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class OperationalRequestDetailPage extends StatelessWidget {
  const OperationalRequestDetailPage({
    super.key,
    required this.repository,
    required this.requestId,
    this.canDecide = false,
  });
  final OperationalRequestRepository repository;
  final String requestId;
  final bool canDecide;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => OperationalRequestDetailCubit(repository, requestId)..load(),
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الطلب')),
        body:
            BlocBuilder<
              OperationalRequestDetailCubit,
              OperationalRequestDetailState
            >(
              builder: (context, state) => switch (state) {
                OperationalRequestDetailLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
                OperationalRequestDetailFailure(:final message) => Center(
                  child: Text(message),
                ),
                OperationalRequestDetailReady(:final request) => ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(request.businessReason),
                    const SizedBox(height: 16),
                    if (request.approvalPlan case final plan?)
                      ApprovalJourney(plan: plan),
                    if (canDecide) ...[
                      const SizedBox(height: 24),
                      _StageActions(request: request),
                    ],
                  ],
                ),
              },
            ),
      ),
    ),
  );
}

class _StageActions extends StatelessWidget {
  const _StageActions({required this.request});
  final UnifiedOperationalRequest request;

  @override
  Widget build(BuildContext context) {
    ApprovalStage? pending;
    for (final stage
        in request.approvalPlan?.stages ?? const <ApprovalStage>[]) {
      if (stage.status == 'pending') {
        pending = stage;
        break;
      }
    }
    if (pending == null) return const SizedBox.shrink();
    final cubit = context.read<OperationalRequestDetailCubit>();
    if (pending.type == ApprovalStageType.payment) {
      return FilledButton.icon(
        onPressed: () async {
          final reference = await _askForText(
            context,
            title: 'تأكيد تنفيذ الصرف',
            label: 'مرجع عملية الصرف',
          );
          if (reference != null) await cubit.payment(reference);
        },
        icon: const Icon(Icons.payments_outlined),
        label: const Text('تأكيد تنفيذ الصرف'),
      );
    }
    if (pending.type == ApprovalStageType.closure) {
      final access =
          request.requestType == 'access' || request.requestType == 'it_access';
      return FilledButton.icon(
        onPressed: () async {
          final note = await _askForText(
            context,
            title: access ? 'تأكيد منح الصلاحية' : 'إغلاق الطلب',
            label: 'ملاحظة التنفيذ',
          );
          if (note != null) {
            await cubit.completeClosure(note, accessProvisioning: access);
          }
        },
        icon: Icon(
          access ? Icons.admin_panel_settings_outlined : Icons.task_alt,
        ),
        label: Text(access ? 'تأكيد منح الصلاحية' : 'إغلاق الطلب'),
      );
    }
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: () => cubit.decide(approved: true, reason: 'موافق'),
            child: const Text('موافقة'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: () => cubit.decide(approved: false, reason: 'مرفوض'),
            child: const Text('رفض'),
          ),
        ),
      ],
    );
  }

  Future<String?> _askForText(
    BuildContext context, {
    required String title,
    required String label,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}
