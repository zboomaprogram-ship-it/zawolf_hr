import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../features/web_attendance_access/data/web_attendance_access_repository_impl.dart';
import '../features/web_attendance_access/presentation/cubit/web_attendance_access_cubit.dart';
import '../features/web_attendance_access/presentation/pages/web_attendance_access_management_page.dart';

class WebAttendanceAccessEntry extends StatelessWidget {
  const WebAttendanceAccessEntry({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create:
        (_) =>
            WebAttendanceAccessCubit(createWebAttendanceAccessRepository())
              ..load(),
    child: const WebAttendanceAccessManagementPage(),
  );
}
