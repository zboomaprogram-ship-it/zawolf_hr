import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/remote_work/data/remote_work_repository_impl.dart';
import '../features/remote_work/presentation/pages/remote_attendance_page.dart';
import '../services/auth_service.dart';

class RemoteAttendanceEntry extends StatelessWidget {
  const RemoteAttendanceEntry({
    super.key,
    this.employeeId,
    this.targetDate,
  });

  final String? employeeId;
  final DateTime? targetDate;

  @override
  Widget build(BuildContext context) {
    final effectiveEmployeeId = employeeId ??
        context.read<AuthService>().currentUser?.uid ??
        '';

    return RemoteAttendancePage(
      repository: createRemoteWorkRepository(),
      employeeId: effectiveEmployeeId,
      targetDate: targetDate,
    );
  }
}
