import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/auth_service.dart';
import 'data/firestore_hr_period_report_repository.dart';
import 'presentation/hr_period_report_cubit.dart';
import 'presentation/hr_period_report_page.dart';

/// Composition boundary: infrastructure is wired here and never in widgets.
class HrPeriodReportsEntry extends StatefulWidget {
  const HrPeriodReportsEntry({required this.auth, super.key});
  final AuthService auth;
  @override
  State<HrPeriodReportsEntry> createState() => _HrPeriodReportsEntryState();
}
class _HrPeriodReportsEntryState extends State<HrPeriodReportsEntry> {
  HrPeriodReportCubit? _cubit;
  @override
  void initState() { super.initState(); final user = widget.auth.currentUser; if (user != null) _cubit = HrPeriodReportCubit(repository: FirestoreHrPeriodReportRepository(), reviewer: user); }
  @override
  void dispose() { _cubit?.close(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final cubit = _cubit;
    if (cubit == null) return const Scaffold(body: Center(child: Text('تعذر تحميل جلسة المستخدم.')));
    return BlocProvider.value(value: cubit, child: const HrPeriodReportPage());
  }
}
