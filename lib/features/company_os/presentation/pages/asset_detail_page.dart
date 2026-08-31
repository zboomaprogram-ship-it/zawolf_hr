import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/company_asset.dart';
import '../../domain/repositories/it_operations_repository.dart';
import '../cubit/asset_detail_cubit.dart';

class AssetDetailPage extends StatelessWidget {
  const AssetDetailPage({
    super.key,
    required this.repository,
    required this.assetId,
  });
  final ItOperationsRepository repository;
  final String assetId;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: BlocProvider(
      create: (_) => AssetDetailCubit(repository, assetId)..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الأصل')),
        body: BlocBuilder<AssetDetailCubit, AssetDetailState>(
          builder: (context, state) => switch (state) {
            AssetDetailLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
            AssetDetailFailure(:final message) => Center(child: Text(message)),
            AssetDetailReady() => _AssetBody(state: state),
          },
        ),
      ),
    ),
  );
}

class _AssetBody extends StatelessWidget {
  const _AssetBody({required this.state});
  final AssetDetailReady state;

  @override
  Widget build(BuildContext context) {
    final asset = state.asset;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(asset.name, style: Theme.of(context).textTheme.headlineSmall),
        Text('${asset.assetCode} • ${_status(asset.status)}'),
        Text('الموظف الحالي: ${asset.currentEmployeeUid ?? 'غير مسند'}'),
        if (state.saving) const LinearProgressIndicator(),
        if (state.message case final message?) ...[
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (asset.canBeAssigned)
              FilledButton.icon(
                onPressed: state.saving ? null : () => _assign(context),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('تسليم لموظف'),
              ),
            if (asset.status == CompanyAssetStatus.assigned)
              FilledButton.tonalIcon(
                onPressed: state.saving ? null : () => _return(context),
                icon: const Icon(Icons.assignment_return),
                label: const Text('استرجاع الأصل'),
              ),
            if (asset.status == CompanyAssetStatus.available)
              OutlinedButton.icon(
                onPressed: state.saving ? null : () => _maintenance(context),
                icon: const Icon(Icons.build_outlined),
                label: const Text('فتح صيانة'),
              ),
            if (asset.status == CompanyAssetStatus.available)
              OutlinedButton.icon(
                onPressed: state.saving ? null : () => _retire(context),
                icon: const Icon(Icons.archive_outlined),
                label: const Text('استبعاد الأصل'),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'سجل التسليم والاسترجاع',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (state.assignments.isEmpty)
          const ListTile(title: Text('لا توجد عمليات تسليم سابقة.'))
        else
          ...state.assignments.map(
            (item) => ListTile(
              leading: const Icon(Icons.history),
              title: Text(item.employeeUid),
              subtitle: Text(item.active ? 'عهدة نشطة' : 'تم الاسترجاع'),
            ),
          ),
        const SizedBox(height: 16),
        Text('سجل الصيانة', style: Theme.of(context).textTheme.titleLarge),
        if (state.maintenance.isEmpty)
          const ListTile(title: Text('لا توجد عمليات صيانة سابقة.'))
        else
          ...state.maintenance.map(
            (item) => ListTile(
              leading: const Icon(Icons.build_circle_outlined),
              title: Text(item.problem.isEmpty ? 'صيانة' : item.problem),
              subtitle: Text('${item.cost} ${item.currency}'),
            ),
          ),
      ],
    );
  }

  Future<void> _assign(BuildContext context) async {
    final values = await _twoFields(
      context,
      title: 'تسليم الأصل',
      firstLabel: 'معرّف الموظف',
      secondLabel: 'حالة الأصل عند التسليم',
    );
    if (values != null && context.mounted) {
      await context.read<AssetDetailCubit>().assign(
        values.$1,
        condition: values.$2,
      );
    }
  }

  Future<void> _return(BuildContext context) async {
    final values = await _twoFields(
      context,
      title: 'استرجاع الأصل',
      firstLabel: 'سبب الاسترجاع',
      secondLabel: 'حالة الأصل عند الاسترجاع',
    );
    if (values != null && context.mounted) {
      await context.read<AssetDetailCubit>().returnAsset(
        reason: values.$1,
        condition: values.$2,
      );
    }
  }

  Future<void> _maintenance(BuildContext context) async {
    final values = await _twoFields(
      context,
      title: 'فتح صيانة',
      firstLabel: 'وصف المشكلة',
      secondLabel: 'التكلفة (0 إذا بلا تكلفة)',
    );
    if (values != null && values.$1.isNotEmpty && context.mounted) {
      await context.read<AssetDetailCubit>().openMaintenance(
        problem: values.$1,
        cost: num.tryParse(values.$2) ?? 0,
      );
    }
  }

  Future<void> _retire(BuildContext context) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('استبعاد الأصل'),
        content: const Text(
          'سيظل السجل محفوظاً ولن يمكن تسليم الأصل مرة أخرى.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (accepted == true && context.mounted) {
      await context.read<AssetDetailCubit>().retire();
    }
  }

  String _status(CompanyAssetStatus status) => switch (status) {
    CompanyAssetStatus.available => 'متاح',
    CompanyAssetStatus.assigned => 'مُسلّم',
    CompanyAssetStatus.maintenance => 'في الصيانة',
    CompanyAssetStatus.damaged => 'تالف',
    CompanyAssetStatus.retired => 'مستبعد',
  };
}

Future<(String, String)?> _twoFields(
  BuildContext context, {
  required String title,
  required String firstLabel,
  required String secondLabel,
}) async {
  final first = TextEditingController();
  final second = TextEditingController();
  final result = await showDialog<(String, String)>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: first,
            decoration: InputDecoration(labelText: firstLabel),
          ),
          TextField(
            controller: second,
            decoration: InputDecoration(labelText: secondLabel),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, (
            first.text.trim(),
            second.text.trim(),
          )),
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
  first.dispose();
  second.dispose();
  return result;
}
