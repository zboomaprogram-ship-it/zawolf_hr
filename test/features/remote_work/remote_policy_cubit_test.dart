import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zawolf_hr/core/sync/authenticated_operation_client.dart';
import 'package:zawolf_hr/features/remote_work/data/remote_policy_api.dart';
import 'package:zawolf_hr/features/remote_work/data/remote_policy_repository_impl.dart';
import 'package:zawolf_hr/features/remote_work/domain/entities/remote_policy.dart';
import 'package:zawolf_hr/features/remote_work/presentation/cubit/remote_policy_editor_cubit.dart';
import 'package:zawolf_hr/features/remote_work/presentation/cubit/remote_policy_publication_cubit.dart';

const _oneDay = RemotePolicyAggregate(
  attendancePolicy: {'defaultStartTime': '09:00'},
  remoteWorkPolicy: {
    'enabled': false,
    'eligibility': {'daysPerWeek': 1},
  },
);
const _twoDays = RemotePolicyAggregate(
  attendancePolicy: {'defaultStartTime': '10:00'},
  remoteWorkPolicy: {
    'enabled': false,
    'eligibility': {'daysPerWeek': 2},
  },
);
final _effective = DateTime.utc(2026, 12, 1);

class _Transport {
  final commands = <Map<String, dynamic>>[];
  Future<http.Response> Function(Map<String, dynamic>)? command;
  Future<http.Response> Function(String)? draft;
  late final repository = RemotePolicyRepositoryImpl(
    api: RemotePolicyApi(
      baseUri: 'https://example.test',
      client: AuthenticatedOperationClient(
        tokenProvider: () async => 'test-token',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/commands')) {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final value = Map<String, dynamic>.from(body['command'] as Map);
            expect(request.headers['x-operation-id'], value['operationId']);
            commands.add(value);
            return command == null ? receipt(value) : command!(value);
          }
          if (request.url.path.contains('/drafts/')) {
            return draft == null
                ? json({'ok': false, 'code': 'draft_not_found'}, 404)
                : draft!(request.url.path.split('/').last);
          }
          if (request.url.path.endsWith('/current')) {
            return json({'ok': true, ..._oneDay.toAggregateMap()});
          }
          if (request.url.path.endsWith('/policy-schema')) {
            return json({'ok': true, 'schemaVersion': 1});
          }
          throw StateError('Unexpected request: ${request.url}');
        }),
      ),
    ),
  );

  static http.Response json(Map<String, dynamic> data, [int status = 200]) =>
      http.Response(jsonEncode(data), status);

  static http.Response receipt(Map<String, dynamic> cmd) => json({
    'ok': true,
    'operationId': cmd['operationId'],
    'draftId': cmd['draftId'],
    'status': 'recorded',
    'version': (cmd['expectedVersion'] as int) + 1,
  });
}

void main() {
  test(
    'loading an existing draft preserves its reviewed effective time',
    () async {
      final transport = _Transport();
      transport.draft =
          (_) async => _Transport.json({
            'ok': true,
            'state': 'draft',
            'version': 2,
            'effectiveFrom': '2026-12-01T00:00:00.000Z',
            'aggregate': _oneDay.toAggregateMap(),
          });
      final cubit = RemotePolicyEditorCubit(repository: transport.repository);
      addTearDown(cubit.close);
      await cubit.load();
      expect(
        (cubit.state as RemotePolicyEditorReady).effectiveFrom,
        _effective,
      );
      cubit.edit(_twoDays);
      expect(
        (cubit.state as RemotePolicyEditorReady).effectiveFrom,
        _effective,
      );
    },
  );

  test(
    'publication uses the freshly selected editor draft and version',
    () async {
      final transport = _Transport();
      final cubit = RemotePolicyPublicationCubit(
        repository: transport.repository,
        draftId: 'closed_draft',
      );
      addTearDown(cubit.close);
      cubit.selectDraft(draftId: 'fresh_draft', version: 2);
      final receipt = await cubit.approve(
        expectedVersion: 2,
        reason: 'reviewed',
      );
      expect(receipt!.draftId, 'fresh_draft');
      expect(transport.commands.single['draftId'], 'fresh_draft');
      expect((cubit.state as RemotePolicyPublicationReady).draftVersion, 3);
    },
  );

  test(
    'recording an approval version allows editing the same draft without a stale version',
    () async {
      final transport = _Transport();
      final cubit = RemotePolicyEditorCubit(repository: transport.repository);
      addTearDown(cubit.close);
      await cubit.load();
      cubit.edit(_oneDay);
      final saved = await cubit.saveDraft(effectiveFrom: _effective);
      cubit.recordReceipt(
        RemotePolicyCommandReceipt(
          operationId: 'approval',
          draftId: saved!.draftId,
          status: 'approved',
          version: 2,
        ),
      );
      cubit.edit(_twoDays);
      await cubit.saveDraft(effectiveFrom: _effective);
      expect(transport.commands.last['expectedVersion'], 2);
    },
  );

  test(
    'published drafts start a fresh editor instead of reopening a closed draft',
    () async {
      final transport = _Transport();
      transport.draft =
          (_) async => _Transport.json({
            'ok': true,
            'state': 'published',
            'version': 3,
            'aggregate': _oneDay.toAggregateMap(),
          });
      final cubit = RemotePolicyEditorCubit(
        repository: transport.repository,
        draftId: 'closed_draft',
      );
      addTearDown(cubit.close);
      await cubit.load();
      final ready = cubit.state as RemotePolicyEditorReady;
      expect(ready.draftId, isNot('closed_draft'));
      expect(ready.draftVersion, 0);
      cubit.edit(_twoDays);
      await cubit.saveDraft(effectiveFrom: _effective);
      expect(transport.commands.single['draftId'], ready.draftId);
      expect(transport.commands.single['expectedVersion'], 0);
    },
  );

  test(
    'saving an older draft preserves edits made while the save is pending',
    () async {
      final transport = _Transport();
      final pending = Completer<http.Response>();
      final started = Completer<void>();
      transport.command = (_) {
        started.complete();
        return pending.future;
      };
      final cubit = RemotePolicyEditorCubit(repository: transport.repository);
      addTearDown(cubit.close);
      await cubit.load();
      cubit.edit(_oneDay);
      final save = cubit.saveDraft(effectiveFrom: _effective);
      await started.future;
      cubit.edit(_twoDays);
      pending.complete(_Transport.receipt(transport.commands.single));
      await save;
      final ready = cubit.state as RemotePolicyEditorReady;
      expect(ready.aggregate.attendancePolicy['defaultStartTime'], '10:00');
      expect(ready.dirty, isTrue);
      expect(ready.draftVersion, 1);
      transport.command = null;
      await cubit.saveDraft(effectiveFrom: _effective);
      expect(transport.commands.last['expectedVersion'], 1);
      expect((cubit.state as RemotePolicyEditorReady).dirty, isFalse);
    },
  );

  test('double save sends one versioned command', () async {
    final transport = _Transport();
    final pending = Completer<http.Response>();
    transport.command = (_) => pending.future;
    final cubit = RemotePolicyEditorCubit(repository: transport.repository);
    addTearDown(cubit.close);
    await cubit.load();
    cubit.edit(_oneDay);
    final first = cubit.saveDraft(effectiveFrom: _effective);
    final second = cubit.saveDraft(effectiveFrom: _effective);
    await Future<void>.delayed(Duration.zero);
    pending.complete(_Transport.receipt(transport.commands.first));
    await Future.wait([first, second]);
    expect(transport.commands, hasLength(1));
  });

  test(
    'reapplying the form after lost response retries the same draft operation',
    () async {
      final transport = _Transport();
      transport.command =
          (_) async => throw http.ClientException('response lost');
      final cubit = RemotePolicyEditorCubit(repository: transport.repository);
      addTearDown(cubit.close);
      await cubit.load();
      cubit.edit(_oneDay);
      expect(await cubit.saveDraft(effectiveFrom: _effective), isNull);
      cubit.edit(RemotePolicyAggregate.fromMap(_oneDay.toAggregateMap()));
      transport.command = null;
      expect(await cubit.saveDraft(effectiveFrom: _effective), isNotNull);
      expect(transport.commands[1], transport.commands[0]);
    },
  );

  test(
    'late draft load cannot replace the subsequently selected draft',
    () async {
      final transport = _Transport();
      final old = Completer<http.Response>();
      final started = Completer<void>();
      transport.draft = (id) async {
        if (id == 'old') {
          started.complete();
          return old.future;
        }
        return _Transport.json({
          'ok': true,
          'state': 'draft',
          'version': 8,
          'aggregate': _twoDays.toAggregateMap(),
        });
      };
      final cubit = RemotePolicyEditorCubit(repository: transport.repository);
      addTearDown(cubit.close);
      final loading = cubit.load(draftId: 'old');
      await started.future;
      await cubit.load(draftId: 'new');
      old.complete(
        _Transport.json({
          'ok': true,
          'state': 'draft',
          'version': 2,
          'aggregate': _oneDay.toAggregateMap(),
        }),
      );
      await loading;
      final ready = cubit.state as RemotePolicyEditorReady;
      expect(ready.draftId, 'new');
      expect(ready.draftVersion, 8);
      expect(ready.aggregate.attendancePolicy['defaultStartTime'], '10:00');
    },
  );

  test(
    'save completion after switching drafts cannot restore the old draft',
    () async {
      final transport = _Transport();
      final pending = Completer<http.Response>();
      final started = Completer<void>();
      transport.command = (_) {
        started.complete();
        return pending.future;
      };
      final cubit = RemotePolicyEditorCubit(
        repository: transport.repository,
        draftId: 'old',
      );
      addTearDown(cubit.close);
      await cubit.load();
      cubit.edit(_oneDay);
      final saving = cubit.saveDraft(effectiveFrom: _effective);
      await started.future;
      await cubit.load(draftId: 'new');
      pending.complete(_Transport.receipt(transport.commands.single));
      expect(await saving, isNull);
      expect((cubit.state as RemotePolicyEditorReady).draftId, 'new');
      expect((cubit.state as RemotePolicyEditorReady).draftVersion, 0);
    },
  );

  for (final action in ['approve', 'publish', 'revert']) {
    test(
      '$action retry after lost response reuses the complete command',
      () async {
        final transport = _Transport();
        transport.command =
            (_) async => throw http.ClientException('response lost');
        final cubit = RemotePolicyPublicationCubit(
          repository: transport.repository,
          draftId: 'draft',
        );
        addTearDown(cubit.close);
        Future<RemotePolicyCommandReceipt?> run() => switch (action) {
          'approve' => cubit.approve(expectedVersion: 3, reason: 'reviewed'),
          'publish' => cubit.publish(
            expectedVersion: 3,
            effectiveFrom: _effective,
          ),
          _ => cubit.revert(
            targetRevisionId: 'revision_2',
            effectiveFrom: _effective,
          ),
        };
        expect(await run(), isNull);
        transport.command = null;
        expect(await run(), isNotNull);
        expect(transport.commands[1], transport.commands[0]);
      },
    );
  }

  test('publication prevents overlapping mutations', () async {
    final transport = _Transport();
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    transport.command = (_) {
      if (!started.isCompleted) started.complete();
      return pending.future;
    };
    final cubit = RemotePolicyPublicationCubit(
      repository: transport.repository,
      draftId: 'draft',
    );
    addTearDown(cubit.close);
    final first = cubit.publish(expectedVersion: 3, effectiveFrom: _effective);
    await started.future;
    final second = cubit.approve(expectedVersion: 3, reason: 'review');
    pending.complete(_Transport.receipt(transport.commands.first));
    await Future.wait([first, second]);
    expect(transport.commands, hasLength(1));
  });

  test('changed publication payload gets a new operation ID', () async {
    final transport = _Transport();
    transport.command =
        (_) async => throw http.ClientException('response lost');
    final cubit = RemotePolicyPublicationCubit(
      repository: transport.repository,
      draftId: 'draft',
    );
    addTearDown(cubit.close);
    await cubit.approve(expectedVersion: 3, reason: 'first review');
    transport.command = null;
    await cubit.approve(expectedVersion: 3, reason: 'corrected review');
    expect(
      transport.commands[1]['operationId'],
      isNot(transport.commands[0]['operationId']),
    );
    expect(transport.commands[1]['payload'], {
      'decision': 'approved',
      'reason': 'corrected review',
    });
  });

  test('closing an editor during save discards the late result', () async {
    final transport = _Transport();
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    transport.command = (_) {
      started.complete();
      return pending.future;
    };
    final cubit = RemotePolicyEditorCubit(repository: transport.repository);
    await cubit.load();
    cubit.edit(_oneDay);
    final saving = cubit.saveDraft(effectiveFrom: _effective);
    await started.future;
    await cubit.close();
    pending.complete(_Transport.receipt(transport.commands.single));
    expect(await saving, isNull);
  });
}
