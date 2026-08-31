import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/it_operations_repository.dart';
import '../cubit/software_license_cubit.dart';
import 'software_license_detail_page.dart';

class SoftwareLicensesPage extends StatelessWidget {
  const SoftwareLicensesPage({super.key, required this.repository});
  final ItOperationsRepository repository;
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: BlocProvider(
      create: (_) => SoftwareLicenseCubit(repository)..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('تراخيص البرامج')),
        body: BlocBuilder<SoftwareLicenseCubit, SoftwareLicenseState>(
          builder: (context, state) => switch (state) {
            SoftwareLicenseLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
            SoftwareLicenseFailure(:final message) => Center(
              child: Text(message),
            ),
            SoftwareLicenseReady(:final items) when items.isEmpty =>
              const Center(child: Text('لا توجد تراخيص مسجلة حالياً.')),
            SoftwareLicenseReady(:final items) => ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final license = items[index];
                return Card(
                  child: ListTile(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SoftwareLicenseDetailPage(
                          repository: repository,
                          licenseId: license.id,
                        ),
                      ),
                    ),
                    title: Text(license.name),
                    subtitle: Text(
                      '${license.vendor} • المتاح ${license.availableSeats} من ${license.totalSeats}',
                    ),
                    trailing: license.canAssignSeat
                        ? const Icon(Icons.verified_outlined)
                        : const Icon(Icons.block, semanticLabel: 'لا توجد سعة'),
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
