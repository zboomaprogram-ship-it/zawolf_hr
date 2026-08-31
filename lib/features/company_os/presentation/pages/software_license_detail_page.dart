import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/it_operations_repository.dart';
import '../cubit/software_license_detail_cubit.dart';

class SoftwareLicenseDetailPage extends StatelessWidget {
  const SoftwareLicenseDetailPage({
    super.key,
    required this.repository,
    required this.licenseId,
  });
  final ItOperationsRepository repository;
  final String licenseId;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: BlocProvider(
      create: (_) => SoftwareLicenseDetailCubit(repository, licenseId)..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الترخيص')),
        body:
            BlocBuilder<SoftwareLicenseDetailCubit, SoftwareLicenseDetailState>(
              builder: (context, state) => switch (state) {
                SoftwareLicenseDetailLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
                SoftwareLicenseDetailFailure(:final message) => Center(
                  child: Text(message),
                ),
                SoftwareLicenseDetailReady() => _LicenseBody(state: state),
              },
            ),
      ),
    ),
  );
}

class _LicenseBody extends StatelessWidget {
  const _LicenseBody({required this.state});
  final SoftwareLicenseDetailReady state;

  @override
  Widget build(BuildContext context) {
    final license = state.license;
    final active = state.assignments.where((item) => item.active).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(license.name, style: Theme.of(context).textTheme.headlineSmall),
        Text(
          '${license.vendor} • المتاح ${license.availableSeats} من ${license.totalSeats}',
        ),
        if (state.saving) const LinearProgressIndicator(),
        if (state.message case final message?)
          Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.icon(
              onPressed: license.canAssignSeat && !state.saving
                  ? () => _assign(context)
                  : null,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('إسناد مقعد'),
            ),
            OutlinedButton.icon(
              onPressed: state.saving ? null : () => _renew(context),
              icon: const Icon(Icons.event_repeat),
              label: const Text('تجديد الترخيص'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('المقاعد المسندة', style: Theme.of(context).textTheme.titleLarge),
        if (active.isEmpty)
          const ListTile(title: Text('لا توجد مقاعد مسندة حالياً.'))
        else
          ...active.map(
            (assignment) => ListTile(
              title: Text(assignment.employeeUid),
              trailing: IconButton(
                tooltip: 'إلغاء المقعد',
                onPressed: state.saving
                    ? null
                    : () => context.read<SoftwareLicenseDetailCubit>().revoke(
                        assignment.employeeUid,
                      ),
                icon: const Icon(Icons.person_remove_outlined),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _assign(BuildContext context) async {
    final uid = await _textDialog(context, 'إسناد مقعد', 'معرّف الموظف');
    if (uid != null && uid.isNotEmpty && context.mounted) {
      await context.read<SoftwareLicenseDetailCubit>().assign(uid);
    }
  }

  Future<void> _renew(BuildContext context) async {
    final text = await _textDialog(context, 'تجديد الترخيص', 'عدد المقاعد');
    if (text == null || !context.mounted) return;
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date != null && context.mounted) {
      await context.read<SoftwareLicenseDetailCubit>().renew(
        date,
        totalSeats: int.tryParse(text),
      );
    }
  }
}

Future<String?> _textDialog(
  BuildContext context,
  String title,
  String label,
) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
          child: const Text('متابعة'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}
