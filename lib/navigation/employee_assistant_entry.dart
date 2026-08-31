import 'package:flutter/material.dart';

import '../features/assistant/data/local_assistant_repository.dart';
import '../features/assistant/presentation/cubit/employee_assistant_cubit.dart';
import '../features/assistant/presentation/pages/employee_assistant_page.dart';

final class EmployeeAssistantEntry extends StatefulWidget {
  const EmployeeAssistantEntry({super.key});

  @override
  State<EmployeeAssistantEntry> createState() => _EmployeeAssistantEntryState();
}

final class _EmployeeAssistantEntryState extends State<EmployeeAssistantEntry> {
  late final EmployeeAssistantCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = EmployeeAssistantCubit(const LocalAssistantRepository());
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => EmployeeAssistantPage(cubit: _cubit);
}
