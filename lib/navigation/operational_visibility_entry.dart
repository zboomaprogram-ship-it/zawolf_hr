import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;

import '../core/sync/authenticated_operation_client.dart';
import '../features/operational_visibility/data/operational_visibility_repository_impl.dart';
import '../features/operational_visibility/presentation/cubit/employee_timeline_cubit.dart';
import '../features/operational_visibility/presentation/cubit/operational_visibility_cubit.dart';
import '../features/operational_visibility/presentation/pages/employee_operations_timeline_page.dart';

final class OperationalVisibilityEntry extends StatefulWidget {
  const OperationalVisibilityEntry({
    super.key,
    required this.employeeUserId,
    required this.canManageVisibility,
  });

  final String employeeUserId;
  final bool canManageVisibility;

  @override
  State<OperationalVisibilityEntry> createState() =>
      _OperationalVisibilityEntryState();
}

final class _OperationalVisibilityEntryState
    extends State<OperationalVisibilityEntry> {
  late final http.Client _client;
  late final EmployeeTimelineCubit _timelineCubit;
  late final OperationalVisibilityCubit _visibilityCubit;

  @override
  void initState() {
    super.initState();
    _client = http.Client();
    final repository = OperationalVisibilityRepositoryImpl(
      firestore: FirebaseFirestore.instance,
      operationClient: AuthenticatedOperationClient(
        client: _client,
        tokenProvider: () async =>
            await FirebaseAuth.instance.currentUser?.getIdToken(),
      ),
      operationsBaseUri: Uri.parse('https://notification.zawolf.ai'),
    );
    _timelineCubit = EmployeeTimelineCubit(repository);
    _visibilityCubit = OperationalVisibilityCubit(repository);
  }

  @override
  void dispose() {
    _timelineCubit.close();
    _visibilityCubit.close();
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider.value(value: _timelineCubit),
      BlocProvider.value(value: _visibilityCubit),
    ],
    child: EmployeeOperationsTimelinePage(
      employeeUserId: widget.employeeUserId,
      canManageVisibility: widget.canManageVisibility,
    ),
  );
}
