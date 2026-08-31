import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/sync/authenticated_operation_client.dart';
import '../features/employee_operations/data/employee_operations_repository_impl.dart';
import '../features/employee_operations/data/firestore_employee_operations_data_source.dart';
import '../features/employee_operations/data/work_outcome_repository_impl.dart';
import '../features/employee_operations/presentation/pages/employee_deduction_details_page.dart';
import '../features/employee_operations/presentation/pages/work_outcomes_page.dart';
import '../services/attendance_service.dart';

export '../features/employee_operations/presentation/pages/work_outcomes_page.dart'
    show WorkOutcomesPageMode;

/// Infrastructure composition for the flagged employee-operations route.
final class EmployeeDeductionDetailsEntry extends StatefulWidget {
  const EmployeeDeductionDetailsEntry({
    required this.employeeUserId,
    this.initialCycleKey,
    super.key,
  });

  final String employeeUserId;
  final String? initialCycleKey;

  @override
  State<EmployeeDeductionDetailsEntry> createState() =>
      _EmployeeDeductionDetailsEntryState();
}

/// Infrastructure composition for the versioned work-outcome vertical slice.
final class WorkOutcomesEntry extends StatelessWidget {
  const WorkOutcomesEntry({
    required this.actorUserId,
    this.mode = WorkOutcomesPageMode.employee,
    super.key,
  });

  final String actorUserId;
  final WorkOutcomesPageMode mode;

  @override
  Widget build(BuildContext context) => WorkOutcomesPage(
    actorUserId: actorUserId,
    repository: WorkOutcomeRepositoryImpl(),
    mode: mode,
  );
}

final class _EmployeeDeductionDetailsEntryState
    extends State<EmployeeDeductionDetailsEntry> {
  late final http.Client _client;
  late final EmployeeOperationsRepositoryImpl _repository;

  @override
  void initState() {
    super.initState();
    _client = http.Client();
    _repository = EmployeeOperationsRepositoryImpl(
      source: FirestoreEmployeeOperationsDataSource(
        firestore: FirebaseFirestore.instance,
        attendanceService: AttendanceService(),
      ),
      operationClient: AuthenticatedOperationClient(
        client: _client,
        tokenProvider: () async =>
            FirebaseAuth.instance.currentUser?.getIdToken(),
      ),
      operationsBaseUri: Uri.parse('https://notification.zawolf.ai'),
    );
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => EmployeeDeductionDetailsPage(
    employeeUserId: widget.employeeUserId,
    repository: _repository,
    initialCycleKey: widget.initialCycleKey,
  );
}
