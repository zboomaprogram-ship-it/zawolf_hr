import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/company_asset.dart';

void main() {
  test('retired and assigned assets cannot be assigned', () {
    const available = CompanyAsset(
      id: '1',
      assetCode: 'A1',
      name: 'Laptop',
      type: 'laptop',
      status: CompanyAssetStatus.available,
      version: 1,
    );
    const assigned = CompanyAsset(
      id: '1',
      assetCode: 'A1',
      name: 'Laptop',
      type: 'laptop',
      status: CompanyAssetStatus.assigned,
      version: 2,
      currentEmployeeUid: 'u1',
    );
    expect(available.canBeAssigned, isTrue);
    expect(assigned.canBeAssigned, isFalse);
  });

  test('paid maintenance requires a cost request', () {
    final record = AssetMaintenance(
      id: 'm1',
      assetId: 'a1',
      openedBy: 'it1',
      openedAt: DateTime(2026),
      problem: 'screen',
      cost: 100,
      currency: 'EGP',
    );
    expect(record.hasValidCostLink, isFalse);
  });
}
