import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/sales_indicators/domain/entities/sales_identity_mapping.dart';
import 'package:zawolf_hr/features/sales_indicators/domain/entities/sales_indicator_filter.dart';
import 'package:zawolf_hr/features/sales_indicators/domain/entities/sales_indicator_snapshot.dart';
import 'package:zawolf_hr/features/sales_indicators/domain/repositories/sales_indicators_repository.dart';
import 'package:zawolf_hr/features/sales_indicators/presentation/cubit/sales_indicators_cubit.dart';
import 'package:zawolf_hr/features/sales_indicators/presentation/pages/sales_indicators_panel.dart';

final class _Repository implements SalesIndicatorsRepository {
  _Repository(this.snapshot);
  final SalesIndicatorSnapshot snapshot;
  SalesIndicatorFilter? requested;
  int loadCount = 0;

  @override
  Future<SalesIndicatorsResult> load(SalesIndicatorFilter filter) async {
    loadCount += 1;
    requested = filter;
    return SalesIndicatorsLoaded(snapshot);
  }

  @override
  Future<SalesIndicatorsResult> reconcile({
    required SalesIndicatorFilter filter,
    required String providerRole,
    required String providerKey,
    required String employeeUserId,
  }) async => SalesIndicatorsLoaded(snapshot);
}

void main() {
  const filter = SalesIndicatorFilter(
    startDate: '2026-07-26',
    endDate: '2026-08-25',
    company: 'SEG',
    sales: ['S4'],
  );

  testWidgets(
    'uses one filter contract and filters roles without another read',
    (tester) async {
      final repository = _Repository(
        SalesIndicatorSnapshot(
          snapshotId: '2026-08-v1',
          filterVersion: 'v1',
          filter: filter,
          sourceHealth: SalesSourceHealth.healthy,
          generatedAt: DateTime.utc(2026, 8, 23),
          rows: const [
            SalesIdentityMapping(
              providerRole: 'sales',
              providerKey: 'S4',
              providerEmployeeId: 'BD-1',
              status: SalesIdentityMappingStatus.mapped,
              employeeName: 'موظف مبيعات',
              userId: 'u1',
            ),
            SalesIdentityMapping(
              providerRole: 'tele_sales',
              providerKey: 'T1',
              providerEmployeeId: 'BD-2',
              status: SalesIdentityMappingStatus.unmapped,
              employeeName: 'موظف هاتف',
            ),
          ],
        ),
      );
      final cubit = SalesIndicatorsCubit(repository);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(
              value: cubit,
              child: const SalesIndicatorsPanel(
                filter: filter,
                canManageMappings: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.requested?.toMap(), filter.toMap());
      expect(find.text('موظف مبيعات'), findsOneWidget);
      expect(find.text('موظف هاتف'), findsOneWidget);
      await tester.tap(find.text('المبيعات'));
      await tester.pump();
      expect(find.text('موظف مبيعات'), findsOneWidget);
      expect(find.text('موظف هاتف'), findsNothing);
      expect(
        Directionality.of(tester.element(find.text('المبيعات'))),
        TextDirection.rtl,
      );
      await cubit.close();
    },
  );

  testWidgets('reloads the provider snapshot when the saved filter changes', (
    tester,
  ) async {
    final repository = _Repository(
      SalesIndicatorSnapshot(
        snapshotId: 'snapshot',
        filterVersion: 'v1',
        filter: filter,
        sourceHealth: SalesSourceHealth.healthy,
        generatedAt: DateTime.utc(2026, 8, 23),
        rows: const [],
      ),
    );
    final cubit = SalesIndicatorsCubit(repository);
    Widget app(SalesIndicatorFilter value) => MaterialApp(
      home: Scaffold(
        body: BlocProvider.value(
          value: cubit,
          child: SalesIndicatorsPanel(filter: value, canManageMappings: false),
        ),
      ),
    );

    await tester.pumpWidget(app(filter));
    await tester.pumpAndSettle();
    expect(repository.loadCount, 1);

    const changed = SalesIndicatorFilter(
      startDate: '2026-08-01',
      endDate: '2026-08-25',
      company: 'SEG',
      sales: ['S8'],
    );
    await tester.pumpWidget(app(changed));
    await tester.pumpAndSettle();
    expect(repository.loadCount, 2);
    expect(repository.requested?.toMap(), changed.toMap());
    await cubit.close();
  });
}
