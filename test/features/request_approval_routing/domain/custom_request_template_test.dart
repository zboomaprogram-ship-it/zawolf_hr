import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/request_approval_routing/domain/entities/custom_request_template.dart';

void main() {
  group('CustomSubtypeConfig', () {
    test('serializes and deserializes with quota exemption and canonical type', () {
      const config = CustomSubtypeConfig(
        nameAr: 'إجازة امتحانات',
        deductsFromQuota: false,
        quotaKey: 'none',
        requiresAttachment: true,
        maxDays: 14,
        permissionCanonicalType: 'flexible',
      );

      final map = config.toMap();
      expect(map['nameAr'], 'إجازة امتحانات');
      expect(map['deductsFromQuota'], false);
      expect(map['quotaKey'], 'none');
      expect(map['requiresAttachment'], true);
      expect(map['maxDays'], 14);
      expect(map['permissionCanonicalType'], 'flexible');

      final parsed = CustomSubtypeConfig.fromMap(map);
      expect(parsed.nameAr, config.nameAr);
      expect(parsed.deductsFromQuota, false);
      expect(parsed.quotaKey, 'none');
      expect(parsed.requiresAttachment, true);
      expect(parsed.maxDays, 14);
      expect(parsed.permissionCanonicalType, 'flexible');
    });

    test('defaults to deductsFromQuota=true when unspecified', () {
      final parsed = CustomSubtypeConfig.fromMap({'nameAr': 'إجازة اعتيادية'});
      expect(parsed.deductsFromQuota, isTrue);
      expect(parsed.quotaKey, 'daysOff');
      expect(parsed.requiresAttachment, isFalse);
    });
  });

  group('CustomRequestField', () {
    test('supports options alias and serialization', () {
      final fromOptions = CustomRequestField.fromMap({
        'key': 'course_name',
        'labelAr': 'اسم المادة',
        'type': 'select',
        'isRequired': true,
        'options': ['عربي', 'إنجليزي'],
      });

      expect(fromOptions.key, 'course_name');
      expect(fromOptions.isRequired, isTrue);
      expect(fromOptions.type, 'select');
      expect(fromOptions.dropdownOptions, ['عربي', 'إنجليزي']);
    });
  });

  group('CustomRequestType', () {
    test('creates template with legacy string subtypes fallback', () {
      final type = CustomRequestType.fromMap({
        'nameAr': 'طلب إجازة',
        'category': 'leave',
        'subtypes': ['اعتيادي', 'عارضة'],
      }, 'leave_template');

      expect(type.id, 'leave_template');
      expect(type.subtypeConfigs.length, 2);
      expect(type.subtypeConfigs.first.nameAr, 'اعتيادي');
      expect(type.subtypeConfigs.first.deductsFromQuota, isTrue);
    });

    test('parses rich subtypeConfigs correctly', () {
      final type = CustomRequestType.fromMap({
        'nameAr': 'طلب إجازة متقدم',
        'category': 'leave',
        'subtypeConfigs': [
          {
            'nameAr': 'إجازة فحص دوري',
            'deductsFromQuota': false,
            'quotaKey': 'none',
            'requiresAttachment': true,
          }
        ],
      }, 'adv_leave');

      expect(type.subtypeConfigs.length, 1);
      final cfg = type.subtypeConfigs.first;
      expect(cfg.nameAr, 'إجازة فحص دوري');
      expect(cfg.deductsFromQuota, isFalse);
      expect(cfg.requiresAttachment, isTrue);
    });
  });
}
