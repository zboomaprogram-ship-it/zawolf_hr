import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;

import '../core/sync/authenticated_operation_client.dart';
import '../features/sales_indicators/data/sales_indicators_repository_impl.dart';
import '../features/sales_indicators/domain/entities/sales_indicator_filter.dart';
import '../features/sales_indicators/presentation/cubit/sales_indicators_cubit.dart';
import '../features/sales_indicators/presentation/pages/sales_indicators_panel.dart';
import '../services/safe_diagnostics_service.dart';

final class SalesIndicatorsEntry extends StatefulWidget {
  const SalesIndicatorsEntry({
    super.key,
    required this.filter,
    required this.canManageMappings,
  });
  final SalesIndicatorFilter filter;
  final bool canManageMappings;

  @override
  State<SalesIndicatorsEntry> createState() => _SalesIndicatorsEntryState();
}

final class _SalesIndicatorsEntryState extends State<SalesIndicatorsEntry> {
  late final http.Client _http;
  late final SalesIndicatorsCubit _cubit;

  @override
  void initState() {
    super.initState();
    _http = http.Client();
    _cubit = SalesIndicatorsCubit(
      SalesIndicatorsRepositoryImpl(
        operationClient: AuthenticatedOperationClient(
          client: _http,
          tokenProvider: () async =>
              await FirebaseAuth.instance.currentUser?.getIdToken(),
        ),
        operationsBaseUri: Uri.parse('https://notification.zawolf.ai'),
        diagnostics: SafeDiagnosticsService.instance,
      ),
    );
  }

  @override
  void dispose() {
    _cubit.close();
    _http.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _cubit,
    child: SalesIndicatorsPanel(
      filter: widget.filter,
      canManageMappings: widget.canManageMappings,
    ),
  );
}
