import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../design_system/components/rtl_navigation.dart';
import '../../domain/repositories/it_operations_repository.dart';
import '../cubit/asset_inventory_cubit.dart';
import 'asset_detail_page.dart';

class CompanyAssetsPage extends StatelessWidget {
  const CompanyAssetsPage({super.key, required this.repository});
  final ItOperationsRepository repository;
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: BlocProvider(
      create: (_) => AssetInventoryCubit(repository)..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('أصول الشركة')),
        body: BlocBuilder<AssetInventoryCubit, AssetInventoryState>(
          builder: (context, state) => switch (state) {
            AssetInventoryLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
            AssetInventoryFailure(:final message) => Center(
              child: Text(message),
            ),
            AssetInventoryReady(:final items) when items.isEmpty =>
              const Center(child: Text('لا توجد أصول مسجلة حالياً.')),
            AssetInventoryReady(:final items) => ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final asset = items[index];
                return Card(
                  child: ListTile(
                    title: Text(asset.name),
                    subtitle: Text('${asset.assetCode} • ${asset.status.name}'),
                    trailing: Icon(RtlNavigation.chevronEnd(context)),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AssetDetailPage(
                          repository: repository,
                          assetId: asset.id,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          },
        ),
      ),
    ),
  );
}
