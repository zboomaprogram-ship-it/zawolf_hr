import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;

import '../core/sync/authenticated_operation_client.dart';
import '../features/diagnostics/data/diagnostics_repository_impl.dart';
import '../features/diagnostics/presentation/cubit/diagnostics_report_cubit.dart';
import '../features/diagnostics/presentation/pages/diagnostics_report_page.dart';

final class DiagnosticsReportEntry extends StatefulWidget {
  const DiagnosticsReportEntry({super.key});
  @override
  State<DiagnosticsReportEntry> createState() => _DiagnosticsReportEntryState();
}

final class _DiagnosticsReportEntryState extends State<DiagnosticsReportEntry> {
  late final http.Client _http;
  late final DiagnosticsReportCubit _cubit;

  @override
  void initState() {
    super.initState();
    _http = http.Client();
    _cubit = DiagnosticsReportCubit(
      DiagnosticsRepositoryImpl(
        operationClient: AuthenticatedOperationClient(
          client: _http,
          tokenProvider: () async =>
              FirebaseAuth.instance.currentUser?.getIdToken(),
        ),
        operationsBaseUri: Uri.parse('https://notification.zawolf.ai'),
      ),
    )..load();
  }

  @override
  void dispose() {
    _cubit.close();
    _http.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocProvider.value(value: _cubit, child: const DiagnosticsReportPage());
}
