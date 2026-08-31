import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/operational_visibility/domain/entities/employee_timeline_entry.dart';
import 'package:zawolf_hr/features/operational_visibility/domain/entities/employee_timeline_query.dart';
import 'package:zawolf_hr/features/operational_visibility/domain/entities/operational_visibility_setting.dart';
import 'package:zawolf_hr/features/operational_visibility/domain/repositories/operational_visibility_repository.dart';
import 'package:zawolf_hr/features/operational_visibility/presentation/cubit/operational_visibility_cubit.dart';

void main() {
  test('Company OS presentation does not own live backend subscriptions', () {
    final root = Directory('lib/features/company_os/presentation');
    for (final file in root.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      expect(source, isNot(contains('.snapshots()')), reason: file.path);
      expect(source, isNot(contains('StreamSubscription')), reason: file.path);
    }
  });

  test('organization presentation owns no backend stream subscriptions', () {
    final root = Directory('lib/features/organization_structure/presentation');
    for (final file in root.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      expect(source, isNot(contains('.snapshots()')), reason: file.path);
      expect(source, isNot(contains('StreamSubscription')), reason: file.path);
    }
  });

  test(
    'visibility Cubit owns one subscription and cancels it on close',
    () async {
      var listens = 0;
      var cancels = 0;
      final controller = StreamController<Set<String>>.broadcast(
        onListen: () => listens++,
        onCancel: () => cancels++,
      );
      final cubit = OperationalVisibilityCubit(_Repository(controller.stream));
      expect(listens, 1);

      for (var index = 0; index < 10; index++) {
        controller.add({'employee-$index'});
      }
      await Future<void>.delayed(Duration.zero);
      expect(listens, 1);
      expect(cubit.state.hiddenEmployeeIds, {'employee-9'});

      await cubit.close();
      expect(cancels, 1);
      await controller.close();
    },
  );
}

final class _Repository implements OperationalVisibilityRepository {
  const _Repository(this.hidden);
  final Stream<Set<String>> hidden;

  @override
  Stream<Set<String>> watchHiddenEmployeeIds() => hidden;

  @override
  Future<EmployeeTimelinePage> loadTimeline(EmployeeTimelineQuery query) =>
      throw UnimplementedError();

  @override
  Future<OperationalVisibilitySetting> setHidden({
    required String employeeUserId,
    required bool hidden,
    required String reasonAr,
    required String operationId,
  }) => throw UnimplementedError();
}
