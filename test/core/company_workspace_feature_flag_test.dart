import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/core/feature_flags/company_workspace_feature_flag.dart';

void main() {
  test('Workspace V2 is disabled by default', () {
    const flag = DisabledCompanyWorkspaceFeatureFlag();

    expect(flag.isEnabledFor(actorId: 'employee-1'), isFalse);
  });

  test('pilot flag only enables the configured actor IDs', () {
    const flag = PilotCompanyWorkspaceFeatureFlag(enabledActorIds: {'pilot-1'});

    expect(flag.isEnabledFor(actorId: 'pilot-1'), isTrue);
    expect(flag.isEnabledFor(actorId: 'employee-1'), isFalse);
  });
}
