import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/user_model.dart';
import '../../services/pending_requests_service.dart';
import 'data/firestore_dashboard_visual_analysis_repository.dart';
import 'domain/dashboard_visual_analysis.dart';
import 'presentation/dashboard_visual_analysis_cubit.dart';
import 'presentation/dashboard_visual_analysis_panel.dart';

/// Composition boundary for dashboard analysis. It keeps Firestore-backed
/// adapters out of the presentation package.
class DashboardVisualAnalysisEntry extends StatefulWidget {
  const DashboardVisualAnalysisEntry({
    super.key,
    required this.user,
    required this.attendanceRoute,
    required this.requestsRoute,
    required this.tasksRoute,
    this.onRefresh,
  });

  final UserModel user;
  final String attendanceRoute;
  final String requestsRoute;
  final String tasksRoute;
  final Future<void> Function()? onRefresh;

  @override
  State<DashboardVisualAnalysisEntry> createState() => _DashboardVisualAnalysisEntryState();
}

class _DashboardVisualAnalysisEntryState extends State<DashboardVisualAnalysisEntry> with WidgetsBindingObserver {
  late final DashboardVisualAnalysisCubit _cubit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cubit = DashboardVisualAnalysisCubit(
      repository: FirestoreDashboardVisualAnalysisRepository(),
      reviewer: widget.user,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _cubit.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cubit.close();
    super.dispose();
  }

  DashboardRequestTotals _requests() {
    final pending = PendingRequestsService.instance;
    return DashboardRequestTotals(
      leaves: pending.leavesCount,
      permissions: pending.permissionsCount,
      advances: pending.advancesCount,
      administrative: pending.administrativeCount,
      resignations: pending.resignationCount,
    );
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _cubit,
    child: ValueListenableBuilder<int>(
      valueListenable: PendingRequestsService.instance.pendingCount,
      builder: (_, __, ___) => DashboardVisualAnalysisPanel(
        requestTotals: _requests(),
        attendanceRoute: widget.attendanceRoute,
        requestsRoute: widget.requestsRoute,
        tasksRoute: widget.tasksRoute,
        onRefresh: widget.onRefresh,
      ),
    ),
  );
}
