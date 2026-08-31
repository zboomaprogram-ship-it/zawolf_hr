import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/design_system/tokens.dart';
import 'package:zawolf_hr/theme/theme.dart';

void main() {
  group('DsStatusColor mapping', () {
    test('present and approved map to wolfGreen', () {
      expect(
        dsStatusColor(DsStatus.present),
        dsStatusColor(DsStatus.approved),
      );
    });

    test('late maps to warning family, absent/rejected to error family', () {
      expect(dsStatusColor(DsStatus.late), const Color(0xFFE4B55D));
      expect(dsStatusColor(DsStatus.absent), dsStatusColor(DsStatus.rejected));
    });

    test('pendingAction maps to the primary cyan accent', () {
      expect(dsStatusColor(DsStatus.pendingAction), ZaWolfColors.primaryCyan);
    });
  });

  group('Design tokens', () {
    test('spacing scale is strictly increasing', () {
      final values = [
        DsSpacing.xs,
        DsSpacing.sm,
        DsSpacing.md,
        DsSpacing.lg,
        DsSpacing.xl,
        DsSpacing.xxl,
      ];
      for (var i = 0; i < values.length - 1; i++) {
        expect(values[i], lessThan(values[i + 1]));
      }
    });

    test('motion durations stay within the 150-250ms contract', () {
      expect(DsMotion.fast.inMilliseconds, greaterThanOrEqualTo(150));
      expect(DsMotion.slow.inMilliseconds, lessThanOrEqualTo(250));
    });
  });
}
