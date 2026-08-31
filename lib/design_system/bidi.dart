/// Unicode bidi-isolation helpers so numerals, amounts, phone numbers, and
/// Latin fragments embedded in Arabic text keep LTR order without leaking
/// direction across sentence boundaries
/// (specs/ui_redesign/06_priority_redesigns_spec.md R4).
library;

const String _fsi = '\u{2066}';
const String _pdi = '\u{2069}';

/// Wraps [value] in First-Strong Isolate / Pop Directional Isolate marks.
/// Safe to call on already-isolated or empty strings.
String dsBidi(Object value) {
  final text = value.toString();
  if (text.isEmpty || !_containsBidiSensitive(text)) return text;
  return '$_fsi$text$_pdi';
}

bool _containsBidiSensitive(String text) {
  for (final code in text.codeUnits) {
    // ASCII digits, Latin letters, currency symbols like EGP/$ are the
    // common mixed-direction offenders in this app.
    if ((code >= 0x30 && code <= 0x39) ||
        (code >= 0x41 && code <= 0x5A) ||
        (code >= 0x61 && code <= 0x7A)) {
      return true;
    }
  }
  return false;
}
