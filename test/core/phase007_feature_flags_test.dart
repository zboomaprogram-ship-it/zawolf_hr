import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/core/feature_flags/phase007_feature_flags.dart';

void main() {
  test('all Phase 007 slices are disabled by default', () {
    const flags = DisabledPhase007FeatureFlags();

    for (final feature in Phase007Feature.values) {
      expect(
        flags.isEnabledFor(feature: feature, actorId: 'employee-1'),
        isFalse,
      );
    }
  });

  test('a pilot only enables its configured feature and actor', () {
    const flags = PilotPhase007FeatureFlags(
      enabledActorIds: {
        Phase007Feature.developerTools: {'pilot-1'},
      },
    );

    expect(
      flags.isEnabledFor(
        feature: Phase007Feature.developerTools,
        actorId: 'pilot-1',
      ),
      isTrue,
    );
    expect(
      flags.isEnabledFor(
        feature: Phase007Feature.developerTools,
        actorId: 'employee-1',
      ),
      isFalse,
    );
    expect(
      flags.isEnabledFor(
        feature: Phase007Feature.employeeAssistant,
        actorId: 'pilot-1',
      ),
      isFalse,
    );
  });
}
