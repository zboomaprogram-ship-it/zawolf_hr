import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/models/organization_structure.dart';

void main() {
  group('organization structure defaults', () {
    test('places administration departments correctly', () {
      expect(
        OrganizationDefaults.inferDivisionId('Accounting'),
        OrganizationDefaults.administration,
      );
      expect(
        OrganizationDefaults.inferDivisionId('Human Resources'),
        OrganizationDefaults.administration,
      );
      expect(
        OrganizationDefaults.inferDivisionId('Legal Affairs'),
        OrganizationDefaults.administration,
      );
      expect(
        OrganizationDefaults.inferDivisionId('IT'),
        OrganizationDefaults.administration,
      );
    });

    test('places BD and SDR in sales', () {
      expect(
        OrganizationDefaults.inferDivisionId('BD'),
        OrganizationDefaults.sales,
      );
      expect(
        OrganizationDefaults.inferDivisionId('SDR'),
        OrganizationDefaults.sales,
      );
    });

    test('places all other departments in operations', () {
      expect(
        OrganizationDefaults.inferDivisionId('Programming'),
        OrganizationDefaults.operations,
      );
      expect(
        OrganizationDefaults.inferDivisionId('Marketing'),
        OrganizationDefaults.operations,
      );
    });

    test('recognizes CEO and COO hierarchy defaults', () {
      expect(
        OrganizationLevel.defaultFor(
          employeeId: 'CEO-100',
          appRole: 'super_admin',
        ),
        OrganizationLevel.ceo,
      );
      expect(
        OrganizationLevel.defaultFor(
          employeeId: 'COO-1300',
          appRole: 'super_admin',
        ),
        OrganizationLevel.divisionManager,
      );
    });
  });
}
