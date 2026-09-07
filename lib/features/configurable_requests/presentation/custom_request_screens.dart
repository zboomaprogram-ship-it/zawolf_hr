import 'package:flutter/material.dart';
import '../../../theme/theme.dart';

import '../domain/configurable_requests_repository.dart';

class CustomRequestTypesScreen extends StatefulWidget {
  const CustomRequestTypesScreen({required this.repository, super.key});
  final ConfigurableRequestsRepository repository;
  @override
  State<CustomRequestTypesScreen> createState() =>
      _CustomRequestTypesScreenState();
}

class _CustomRequestTypesScreenState extends State<CustomRequestTypesScreen> {
  var _loading = true;
  List<CustomRequestDirectoryUser> _users = const [];
  List<Map<String, dynamic>> _mySubmittedRequests = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final users = await widget.repository.directory();
      if (mounted && users.isNotEmpty) {
        setState(() => _users = users);
      }
    } catch (_) {}


    try {
      final reqs = await widget.repository.requests(queue: false);
      if (mounted) setState(() => _mySubmittedRequests = reqs);
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _createDirectRequest() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final attachmentController = TextEditingController();
    final selectedApproverIds = <String>[];
    var searchQuery = '';

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: ZaWolfColors.surface01,
            title: Row(
              children: const [
                Icon(Icons.assignment_add, color: ZaWolfColors.primaryCyan),
                SizedBox(width: 10),
                Text(
                  'طلب مخصص جديد',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: 580,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'عنوان الطلب (مطلوب)',
                        hintText: 'مثال: طلب شراء أجهزة لفرع الرياض',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'تفاصيل وشرح الطلب (مطلوب)',
                        hintText: 'اكتب كافة التفاصيل الفنية أو الإدارية المطلوبة...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: attachmentController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'رابط مرفق أو مستند إضافي (اختياري)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'تحديد مسار الموافقات والاعتماد (اختر من 1 إلى 4 مسؤولين):',
                      style: TextStyle(
                        color: ZaWolfColors.primaryCyan,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      onChanged: (val) => setDialogState(() => searchQuery = val.trim()),
                      decoration: const InputDecoration(
                        hintText: 'بحث باسم المسؤول أو القسم...',
                        prefixIcon: Icon(Icons.search, size: 18),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        color: ZaWolfColors.surface02,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: ZaWolfColors.surface03),
                      ),
                      child: Builder(
                        builder: (context) {
                          final filtered = _users.where((u) {
                            if (searchQuery.isEmpty) return true;
                            return u.name.contains(searchQuery) ||
                                u.department.contains(searchQuery);
                          }).toList();

                          if (filtered.isEmpty) {
                            return const Center(
                              child: Text(
                                'لا يوجد مسؤولون مطابقون للبحث',
                                style: TextStyle(color: ZaWolfColors.textMuted, fontSize: 12),
                              ),
                            );
                          }

                          return ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final user = filtered[index];
                              final isSelected = selectedApproverIds.contains(user.id);
                              final order = selectedApproverIds.indexOf(user.id) + 1;
                              return CheckboxListTile(
                                dense: true,
                                value: isSelected,
                                activeColor: ZaWolfColors.primaryCyan,
                                checkColor: Colors.black,
                                title: Text(
                                  user.name,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  '${user.department} · ${user.role}',
                                  style: const TextStyle(color: ZaWolfColors.textSecondary, fontSize: 11),
                                ),
                                secondary: isSelected
                                    ? CircleAvatar(
                                        radius: 12,
                                        backgroundColor: ZaWolfColors.primaryCyan,
                                        child: Text(
                                          '$order',
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    : null,
                                onChanged: (val) {
                                  setDialogState(() {
                                    if (val == true) {
                                      if (selectedApproverIds.length < 4) {
                                        selectedApproverIds.add(user.id);
                                      }
                                    } else {
                                      selectedApproverIds.remove(user.id);
                                    }
                                  });
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('إرسال الطلب للاعتماد'),
              ),
            ],
          ),
        ),
      ),
    );

    if (submitted == true) {
      final title = titleController.text.trim();
      final description = descriptionController.text.trim();
      if (title.isEmpty || description.isEmpty || selectedApproverIds.isEmpty) {
        _notice('يرجى إدخال العنوان والتفاصيل واختيار مسؤول اعتماد واحد على الأقل.', error: true);
        return;
      }
      try {
        await widget.repository.submitDirect(
          title: title,
          description: description,
          approverIds: selectedApproverIds,
          attachmentUrl: attachmentController.text.trim().isEmpty ? null : attachmentController.text.trim(),
        );
        _notice('تم إرسال الطلب المخصص لمسار الاعتماد بنجاح.');
        await _load();
      } catch (error) {
        _notice('$error', error: true);
      }
    }

    titleController.dispose();
    descriptionController.dispose();
    attachmentController.dispose();
  }

  void _notice(String message, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? Colors.red : Colors.green,
        ),
      );

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('الطلبات المخصصة والاعتمادات الإدارية'),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _loading ? null : _createDirectRequest,
            icon: const Icon(Icons.add),
            label: const Text('طلب مخصص جديد'),
            backgroundColor: ZaWolfColors.primaryCyan,
            foregroundColor: Colors.black,
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _mySubmittedRequests.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.assignment_outlined,
                            size: 64,
                            color: ZaWolfColors.textMuted,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'لا توجد طلبات مخصصة مُقدمة سابقة',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: ZaWolfColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'اضغط "+ طلب مخصص جديد" لإنشاء طلب مخصص وتعيين مسار الاعتماد الخاص به.',
                            style: TextStyle(color: ZaWolfColors.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _mySubmittedRequests.length,
                      itemBuilder: (context, index) {
                        final req = _mySubmittedRequests[index];
                        final status = '${req['status']}';
                        final statusColor = status == 'approved'
                            ? ZaWolfColors.success
                            : status == 'rejected'
                                ? ZaWolfColors.error
                                : ZaWolfColors.warning;
                        final statusText = status == 'approved'
                            ? 'معتمد'
                            : status == 'rejected'
                                ? 'مرفوض'
                                : 'قيد الانتظار';
                        final route = (req['approvalRoute'] as List? ?? const [])
                            .whereType<Map>()
                            .toList();

                        return Card(
                          color: ZaWolfColors.surface01,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: statusColor.withValues(alpha: 0.3)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: statusColor),
                                      ),
                                      child: Text(
                                        statusText,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${req['title'] ?? 'طلب مخصص'}',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${req['description'] ?? ''}',
                                  style: const TextStyle(color: ZaWolfColors.textSecondary),
                                ),
                                if (route.isNotEmpty) ...[
                                  const Divider(color: ZaWolfColors.surface02, height: 20),
                                  const Text(
                                    'مسار الاعتماد:',
                                    style: TextStyle(
                                      color: ZaWolfColors.primaryCyan,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: route.map((stage) {
                                      final stState = '${stage['state']}';
                                      final isApp = stState == 'approved';
                                      final isRej = stState == 'rejected';
                                      final isPend = stState == 'pending';
                                      final chipColor = isApp
                                          ? ZaWolfColors.success
                                          : isRej
                                              ? ZaWolfColors.error
                                              : isPend
                                                  ? ZaWolfColors.warning
                                                  : ZaWolfColors.textMuted;
                                      return Chip(
                                        visualDensity: VisualDensity.compact,
                                        backgroundColor: chipColor.withValues(alpha: 0.12),
                                        side: BorderSide(color: chipColor.withValues(alpha: 0.4)),
                                        avatar: CircleAvatar(
                                          radius: 10,
                                          backgroundColor: chipColor,
                                          child: Text(
                                            '${stage['order'] ?? 1}',
                                            style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        label: Text(
                                          '${stage['approverName']}',
                                          style: TextStyle(color: chipColor, fontSize: 11),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      );
}

class CustomRequestSubmissionScreen extends StatefulWidget {
  const CustomRequestSubmissionScreen({required this.repository, super.key});
  final ConfigurableRequestsRepository repository;
  @override
  State<CustomRequestSubmissionScreen> createState() =>
      _CustomRequestSubmissionScreenState();
}

class _CustomRequestSubmissionScreenState
    extends State<CustomRequestSubmissionScreen> {
  var _loading = true;
  List<CustomRequestType> _types = const [];
  CustomRequestType? _type;
  final _description = TextEditingController();
  final Map<String, TextEditingController> _answers = {};
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _description.dispose();
    for (final controller in _answers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final types = await widget.repository.types();
      if (mounted) {
        setState(() {
          _types = types;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) _notice('$error', error: true);
    }
  }

  Future<void> _submit() async {
    try {
      if (_type == null || _description.text.trim().isEmpty) {
        throw StateError('اختر النوع واكتب شرح الطلب.');
      }
      await widget.repository.submit(
        typeId: _type!.id,
        description: _description.text.trim(),
        answers: {
          for (final entry in _answers.entries)
            entry.key: entry.value.text.trim(),
        },
      );
      if (mounted) {
        _notice('تم إرسال الطلب لمسار الموافقات.');
        _description.clear();
      }
    } catch (error) {
      if (mounted) _notice('$error', error: true);
    }
  }

  void _notice(String message, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? Colors.red : Colors.green,
        ),
      );
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('طلب مخصص')),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _types.any((t) => t.id == _type?.id) ? _type?.id : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'نوع الطلب',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        _types
                            .map(
                              (type) => DropdownMenuItem<String>(
                                value: type.id,
                                child: Text(type.name),
                              ),
                            )
                            .toList(),
                    onChanged:
                        (id) => setState(() {
                          _type = id == null ? null : _types.firstWhere((t) => t.id == id);
                          _answers.clear();
                        }),
                  ),
                  if (_type != null) ...[
                    const SizedBox(height: 12),
                    Text(_type!.description),
                    ..._type!.fields.map((field) {
                      final id = '${field['id']}';
                      final controller = _answers.putIfAbsent(
                        id,
                        TextEditingController.new,
                      );
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: TextField(
                          controller: controller,
                          decoration: InputDecoration(
                            labelText:
                                '${field['labelAr']}${field['required'] == true ? ' *' : ''}',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _description,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'شرح الطلب',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _submit,
                    child: const Text('إرسال الطلب'),
                  ),
                ],
              ),
    ),
  );
}

class CustomRequestQueueScreen extends StatefulWidget {
  const CustomRequestQueueScreen({required this.repository, super.key});
  final ConfigurableRequestsRepository repository;
  @override
  State<CustomRequestQueueScreen> createState() =>
      _CustomRequestQueueScreenState();
}

class _CustomRequestQueueScreenState extends State<CustomRequestQueueScreen> {
  var _loading = true;
  List<Map<String, dynamic>> _items = const [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.repository.requests(queue: true);
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) _notice('$error', error: true);
    }
  }

  Future<void> _decide(String id, bool approved) async {
    try {
      await widget.repository.decide(id: id, approved: approved);
      if (mounted) {
        _notice(approved ? 'تمت الموافقة.' : 'تم الرفض.');
        await _load();
      }
    } catch (error) {
      if (mounted) _notice('$error', error: true);
    }
  }

  void _notice(String message, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? Colors.red : Colors.green,
        ),
      );
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('طلبات مخصصة بانتظار قراري')),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
              ? const Center(child: Text('لا توجد طلبات بانتظار قرارك.'))
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _items.length,
                itemBuilder: (_, index) {
                  final item = _items[index];
                  return Card(
                    child: ListTile(
                      title: Text('${item['title'] ?? item['typeNameAr']}'),
                      subtitle: Text(
                        '${item['requesterName'] ?? ''}\n${item['description'] ?? ''}',
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _decide('${item['id']}', false),
                            icon: const Icon(Icons.close, color: Colors.red),
                          ),
                          IconButton(
                            onPressed: () => _decide('${item['id']}', true),
                            icon: const Icon(Icons.check, color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    ),
  );
}
