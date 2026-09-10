import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;

import '../core/sync/authenticated_operation_client.dart';
import '../features/diagnostics/data/developer_tools_repository_impl.dart';
import '../features/diagnostics/data/developer_api_repository_impl.dart';
import '../features/diagnostics/data/firestore_developer_tools_directory_repository.dart';
import '../features/diagnostics/presentation/cubit/developer_tools_cubit.dart';
import '../features/diagnostics/presentation/cubit/developer_api_admin_cubit.dart';
import '../features/diagnostics/presentation/cubit/developer_tools_admin_cubit.dart';
import '../features/diagnostics/presentation/pages/developer_tools_page.dart';
import '../features/diagnostics/presentation/pages/developer_tools_admin_page.dart';
import '../features/diagnostics/presentation/pages/developer_api_admin_page.dart';

const _developerToolsBaseUri = 'https://notification.zawolf.ai';

/// Composition root: Firebase session and HTTP are assembled outside the
/// diagnostics presentation package.
final class DeveloperToolsEntry extends StatefulWidget {
  const DeveloperToolsEntry({super.key});

  @override
  State<DeveloperToolsEntry> createState() => _DeveloperToolsEntryState();
}

final class _DeveloperToolsEntryState extends State<DeveloperToolsEntry> {
  late final http.Client _client;
  late final DeveloperToolsCubit _cubit;

  @override
  void initState() {
    super.initState();
    _client = http.Client();
    _cubit = DeveloperToolsCubit(
      DeveloperToolsRepositoryImpl(
        operationClient: AuthenticatedOperationClient(
          client: _client,
          tokenProvider: () async =>
              await FirebaseAuth.instance.currentUser?.getIdToken(),
        ),
        operationsBaseUri: Uri.parse(_developerToolsBaseUri),
      ),
    )..load();
  }

  @override
  void dispose() {
    _cubit.close();
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocProvider.value(value: _cubit, child: const DeveloperToolsPage());
}

final class DeveloperToolsAccess {
  const DeveloperToolsAccess._();

  static Future<bool> isAvailableForCurrentUser() async {
    final client = http.Client();
    try {
      final repository = DeveloperToolsRepositoryImpl(
        operationClient: AuthenticatedOperationClient(
          client: client,
          tokenProvider: () async =>
              await FirebaseAuth.instance.currentUser?.getIdToken(),
        ),
        operationsBaseUri: Uri.parse(_developerToolsBaseUri),
      );
      return (await repository.loadMyEntitlement())?.isActive == true;
    } finally {
      client.close();
    }
  }
}

final class DeveloperToolsAdminEntry extends StatefulWidget {
  const DeveloperToolsAdminEntry({super.key});
  @override
  State<DeveloperToolsAdminEntry> createState() =>
      _DeveloperToolsAdminEntryState();
}

final class _DeveloperToolsAdminEntryState
    extends State<DeveloperToolsAdminEntry> {
  late final http.Client _client;
  late final DeveloperToolsAdminCubit _cubit;
  @override
  void initState() {
    super.initState();
    _client = http.Client();
    _cubit = DeveloperToolsAdminCubit(
      DeveloperToolsRepositoryImpl(
        operationClient: AuthenticatedOperationClient(
          client: _client,
          tokenProvider: () async =>
              await FirebaseAuth.instance.currentUser?.getIdToken(),
        ),
        operationsBaseUri: Uri.parse(_developerToolsBaseUri),
      ),
      FirestoreDeveloperToolsDirectoryRepository(
        firestore: FirebaseFirestore.instance,
      ),
    )..load();
  }

  @override
  void dispose() {
    _cubit.close();
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocProvider.value(value: _cubit, child: const DeveloperToolsAdminPage());
}


final class DeveloperApiAdminEntry extends StatefulWidget {
  const DeveloperApiAdminEntry({super.key});
  @override
  State<DeveloperApiAdminEntry> createState() => _DeveloperApiAdminEntryState();
}

final class _DeveloperApiAdminEntryState extends State<DeveloperApiAdminEntry> {
  late final http.Client _client;
  late final DeveloperApiAdminCubit _cubit;

  @override
  void initState() {
    super.initState();
    _client = http.Client();
    _cubit = DeveloperApiAdminCubit(
      DeveloperApiRepositoryImpl(
        operationClient: AuthenticatedOperationClient(
          client: _client,
          tokenProvider: () async =>
              await FirebaseAuth.instance.currentUser?.getIdToken(true),
        ),
        baseUri: Uri.parse(_developerToolsBaseUri),
      ),
    )..load();
  }

  @override
  void dispose() {
    _cubit.close();
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _cubit,
    child: const DeveloperApiAdminPage(),
  );
}
