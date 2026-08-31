import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/company_workspace/domain/entities/workspace_report_period.dart';
import 'package:zawolf_hr/features/company_workspace/domain/repositories/workspace_reports_repository.dart';
import 'package:zawolf_hr/features/company_workspace/presentation/cubit/workspace_reports_cubit.dart';
import 'package:zawolf_hr/features/company_workspace/presentation/pages/workspace_reports_page.dart';

void main() {
  testWidgets('shows RTL empty state and creates a protected HR report', (
    tester,
  ) async {
    final cubit = WorkspaceReportsCubit(_ReportsRepository());
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: WorkspaceReportsPage(onOpenResource: (_) {}),
        ),
      ),
    );
    expect(find.textContaining('اختر نوع التقرير'), findsOneWidget);
    await tester.tap(find.text('إنشاء التقرير'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    await cubit.close();
  });
}

final class _ReportsRepository implements WorkspaceReportsRepository {
  @override
  Future<String> requestHrOperationalReport({
    required WorkspaceReportPeriod period,
    required String reportType,
  }) async => 'report-resource';
  @override
  Future<String> requestWorkspaceActivityReport({
    required WorkspaceReportPeriod period,
    required String scopeId,
  }) async => 'audit-resource';
}
