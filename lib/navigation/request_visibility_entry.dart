import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/request_visibility/data/firestore_request_visibility_data_source.dart';
import '../features/request_visibility/data/request_visibility_repository.dart';
import '../features/request_visibility/domain/entities/request_view_query.dart';
import '../features/request_visibility/domain/entities/request_visibility_record.dart';
import '../features/request_visibility/presentation/cubit/request_visibility_cubit.dart';
import '../features/request_visibility/presentation/pages/request_visibility_panel.dart';
import '../services/safe_diagnostics_service.dart';

final class RequestVisibilityEntry extends StatefulWidget {
  const RequestVisibilityEntry({
    super.key,
    required this.query,
    this.searchTerm = '',
    this.onSelectRecord,
  });

  final RequestViewQuery query;
  final String searchTerm;
  final void Function(RequestVisibilityRecord record)? onSelectRecord;

  @override
  State<RequestVisibilityEntry> createState() => _RequestVisibilityEntryState();
}

final class _RequestVisibilityEntryState extends State<RequestVisibilityEntry> {
  late final RequestVisibilityCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = RequestVisibilityCubit(
      RequestVisibilityRepositoryImpl(
        FirestoreRequestVisibilityDataSource(),
        diagnostics: SafeDiagnosticsService.instance,
      ),
    );
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _cubit,
    child: RequestVisibilityPanel(
      query: widget.query,
      searchTerm: widget.searchTerm,
      onSelectRecord: widget.onSelectRecord,
    ),
  );
}
