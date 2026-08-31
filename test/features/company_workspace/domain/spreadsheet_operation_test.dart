import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/company_workspace/domain/entities/spreadsheet_range.dart';

void main() {
  test('a bounded rectangular range is valid', () {
    const range = SpreadsheetRange(
      tabName: 'Sheet1',
      startRow: 1,
      endRow: 3,
      startColumn: 1,
      endColumn: 5,
    );
    expect(range.isValid, isTrue);
    expect(range.cellCount, 15);
  });

  test('invalid range dimensions and unbounded columns are rejected', () {
    const backwards = SpreadsheetRange(
      tabName: 'Sheet1',
      startRow: 5,
      endRow: 2,
      startColumn: 1,
      endColumn: 1,
    );
    const tooWide = SpreadsheetRange(
      tabName: 'Sheet1',
      startRow: 1,
      endRow: 1,
      startColumn: 1,
      endColumn: 703,
    );
    expect(backwards.isValid, isFalse);
    expect(tooWide.isValid, isFalse);
  });

  test('only fully editable Sheets can be mutated', () {
    const policy = SpreadsheetCapabilityPolicy();
    expect(policy.mayMutate(SpreadsheetCompatibility.fullyEditable), isTrue);
    expect(
      policy.mayMutate(SpreadsheetCompatibility.protectedReadOnly),
      isFalse,
    );
    expect(
      policy.mayMutate(SpreadsheetCompatibility.unsupportedReadOnly),
      isFalse,
    );
  });

  test('expected versions are explicit and bounded', () {
    expect(const SpreadsheetVersion('v-2026-08-20').isValid, isTrue);
    expect(const SpreadsheetVersion('').isValid, isFalse);
  });
}
