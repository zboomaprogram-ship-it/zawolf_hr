import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zawolf_hr/core/feature_flags/company_os_feature_flags.dart';
import 'package:zawolf_hr/core/feature_flags/remote_company_os_feature_flags.dart';

void main() {
  test('every Company OS slice fails closed by default', () {
    const flags = DisabledCompanyOsFeatureFlags();

    for (final feature in CompanyOsFeature.values) {
      expect(
        flags.isEnabledFor(feature: feature, actorId: 'employee-1'),
        isFalse,
      );
    }
  });

  test('pilot grants are actor and slice specific', () {
    const flags = PilotCompanyOsFeatureFlags(
      enabledActorIds: {
        CompanyOsFeature.portal: {'employee-1'},
        CompanyOsFeature.itOperations: {'it-1'},
      },
    );

    expect(
      flags.isEnabledFor(
        feature: CompanyOsFeature.portal,
        actorId: 'employee-1',
      ),
      isTrue,
    );
    expect(
      flags.isEnabledFor(
        feature: CompanyOsFeature.itOperations,
        actorId: 'employee-1',
      ),
      isFalse,
    );
    expect(
      flags.isEnabledFor(feature: CompanyOsFeature.portal, actorId: ' '),
      isFalse,
    );
  });

  test('server names remain stable rollout contract', () {
    expect(
      CompanyOsFeature.values.map((value) => value.serverName),
      containsAll(<String>[
        'company_os_portal_v1',
        'company_os_it_v1',
        'company_os_requests_v1',
        'company_os_operations_v1',
        'company_os_organization_v1',
        'company_os_multi_tree_v1',
      ]),
    );
  });

  test('remote flags expose the multiple organization trees slice', () async {
    final client = MockClient(
      (_) async => http.Response(
        '{"ok":true,"flags":{'
        '"company_os_organization_v1":true,'
        '"company_os_multi_tree_v1":true}}',
        200,
      ),
    );
    final flags = RemoteCompanyOsFeatureFlags(
      client: client,
      tokenProvider: () async => 'token',
      baseUri: Uri.parse('https://notification.zawolf.ai/'),
    );

    await flags.refresh();

    expect(
      flags.isEnabledFor(
        feature: CompanyOsFeature.multiOrganization,
        actorId: 'admin-1',
      ),
      isTrue,
    );
  });
}
