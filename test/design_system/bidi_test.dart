import 'package:flutter_test/flutter_test.dart';

import 'package:zawolf_hr/design_system/bidi.dart';

void main() {
  test('dsBidi wraps Latin digits in isolate marks', () {
    final out = dsBidi('12.50 EGP');
    expect(out, startsWith('\u{2066}'));
    expect(out, endsWith('\u{2069}'));
    expect(out.contains('12.50 EGP'), isTrue);
  });

  test('dsBidi leaves pure Arabic text untouched', () {
    const text = 'بانتظار المراجعة';
    expect(dsBidi(text), text);
  });

  test('dsBidi handles empty input', () {
    expect(dsBidi(''), '');
  });

  test('dsBidi accepts non-string values', () {
    expect(dsBidi(42), '\u{2066}42\u{2069}');
  });
}
