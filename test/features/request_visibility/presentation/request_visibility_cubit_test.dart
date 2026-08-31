import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/request_visibility/domain/entities/request_view_query.dart';
import 'package:zawolf_hr/features/request_visibility/domain/entities/request_visibility_record.dart';
import 'package:zawolf_hr/features/request_visibility/domain/repositories/request_visibility_repository.dart';
import 'package:zawolf_hr/features/request_visibility/presentation/cubit/request_visibility_cubit.dart';

void main() {
  final query = RequestViewQuery(
    actorScope: const RequestActorScope(actorId: 'hr-1', role: 'hr_admin'),
    tab: RequestViewTab.history,
    fromDate: DateTime.utc(2026),
    toDate: DateTime.utc(2026, 12, 31),
    pageSize: 1,
  );

  test(
    'exposes explicit loaded pagination and appends the next page',
    () async {
      final cubit = RequestVisibilityCubit(_PagedRepository());
      await cubit.load(query);
      expect(cubit.state.records.map((item) => item.stableId), ['first']);
      expect(cubit.state.hasMore, isTrue);

      await cubit.loadMore();
      expect(cubit.state.records.map((item) => item.stableId), [
        'first',
        'second',
      ]);
      expect(cubit.state.hasMore, isFalse);
      await cubit.close();
    },
  );

  test('exposes safe access denied state without provider details', () async {
    final cubit = RequestVisibilityCubit(_DeniedRepository());
    await cubit.load(query);
    expect(cubit.state.accessDenied, isTrue);
    expect(cubit.state.safeMessage, 'لا تتوفر لك صلاحية عرض هذه الطلبات.');
    await cubit.close();
  });
}

final class _PagedRepository implements RequestVisibilityRepository {
  @override
  Future<RequestViewResult> load(RequestViewQuery query) async {
    final second = query.pageCursor != null;
    return RequestViewLoaded([
      RequestVisibilityRecord(
        stableId: second ? 'second' : 'first',
        sourceType: RequestSourceType.leave,
        employeeId: 'employee-1',
        approvalStage: RequestApprovalStage.finalised,
        lifecycleState: RequestLifecycleState.approved,
        occurredAt: DateTime.utc(2026, 8, second ? 19 : 20),
        sourceReference: 'leaves/${second ? 'second' : 'first'}',
      ),
    ], nextCursor: second ? null : 'cursor-1');
  }
}

final class _DeniedRepository implements RequestVisibilityRepository {
  @override
  Future<RequestViewResult> load(RequestViewQuery query) async =>
      const RequestViewAccessDenied('لا تتوفر لك صلاحية عرض هذه الطلبات.');
}
