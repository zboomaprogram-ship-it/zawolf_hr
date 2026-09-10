import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/developer_api_admin_cubit.dart';

final class DeveloperApiAdminPage extends StatefulWidget {
  const DeveloperApiAdminPage({super.key});
  @override
  State<DeveloperApiAdminPage> createState() => _DeveloperApiAdminPageState();
}

final class _DeveloperApiAdminPageState extends State<DeveloperApiAdminPage> {
  final _nameController = TextEditingController();
  DateTime _expiry = DateTime.now().add(const Duration(days: 30));

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _showSecret(BuildContext context, String secret) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('مفتاح API جديد'),
        content: SelectableText(
          'انسخ المفتاح الآن واحفظه في مدير كلمات المرور. لن يظهر مرة أخرى:\n\n$secret',
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: secret));
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('تم نسخ المفتاح.')));
              }
            },
            icon: const Icon(Icons.copy_outlined),
            label: const Text('نسخ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('حفظت المفتاح بأمان'),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseExpiry() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expiry,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 366)),
    );
    if (date != null && mounted) setState(() => _expiry = DateTime(date.year, date.month, date.day, 23, 59));
  }

  Future<void> _revoke(BuildContext context, String clientId) async {
    final reason = TextEditingController();
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('سحب مفتاح API'),
        content: TextField(controller: reason, autofocus: true, decoration: const InputDecoration(labelText: 'سبب السحب')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('سحب المفتاح')),
        ],
      ),
    );
    final value = reason.text.trim();
    reason.dispose();
    if (approved == true && value.isNotEmpty && context.mounted) {
      await context.read<DeveloperApiAdminCubit>().revoke(clientId: clientId, reason: value);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('مفاتيح API للمطوّرين')),
    body: Directionality(
      textDirection: TextDirection.rtl,
      child: BlocConsumer<DeveloperApiAdminCubit, DeveloperApiAdminState>(
        listener: (context, state) {
          if (state.status == DeveloperApiAdminStatus.issued && state.issued != null) {
            _nameController.clear();
            _showSecret(context, state.issued!.secret);
          } else if (state.status == DeveloperApiAdminStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تنفيذ العملية. تأكد من اتصال الخادم وصلاحية HR.')));
          }
        },
        builder: (context, state) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('أنشئ مفتاحاً مستقلاً لكل مطوّر. المفتاح يقرأ دليل الموظفين فقط ويمكن سحبه فوراً.', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'اسم المطوّر أو التكامل', prefixIcon: Icon(Icons.person_outline))),
            ListTile(
              title: const Text('انتهاء المفتاح'),
              subtitle: Text(_expiry.toLocal().toString().split(' ').first),
              trailing: const Icon(Icons.calendar_month_outlined),
              onTap: _chooseExpiry,
            ),
            FilledButton.icon(
              onPressed: state.status == DeveloperApiAdminStatus.saving ? null : () => context.read<DeveloperApiAdminCubit>().create(name: _nameController.text, expiresAt: _expiry),
              icon: const Icon(Icons.key_outlined),
              label: const Text('إنشاء مفتاح API'),
            ),
            const SizedBox(height: 28),
            const Text('المفاتيح الحالية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            if (state.status == DeveloperApiAdminStatus.loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else if (state.clients.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('لا توجد مفاتيح API حالياً.'))
            else ...state.clients.map((client) => Card(
              child: ListTile(
                leading: Icon(client.isActive ? Icons.key : Icons.key_off_outlined),
                title: Text(client.name),
                subtitle: Text('${client.scopes.join(', ')} · ينتهي ${client.expiresAt.toLocal().toString().split(' ').first}'),
                trailing: client.isActive ? TextButton(onPressed: () => _revoke(context, client.id), child: const Text('سحب')) : const Text('منتهٍ/مسحوب'),
              ),
            )),
          ],
        ),
      ),
    ),
  );
}
