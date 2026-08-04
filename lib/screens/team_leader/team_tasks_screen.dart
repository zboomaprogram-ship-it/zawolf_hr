import 'package:flutter/material.dart';

import '../manager/tasks_mgmt.dart';

/// Team leaders use the same live, filterable task workspace as managers.
/// TaskService scopes its data and assignee list to the current role.
class TeamLeaderTasksScreen extends StatelessWidget {
  const TeamLeaderTasksScreen({super.key});

  @override
  Widget build(BuildContext context) => const TasksManagementScreen();
}
