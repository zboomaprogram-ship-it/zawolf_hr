/// The server-owned prospective policy for employee check-out.
///
/// An absent or malformed document is intentionally disabled. This makes the
/// mobile client fail closed while the server remains the final authority.
final class CheckoutPolicy {
  const CheckoutPolicy({
    required this.enabled,
    required this.revision,
    this.effectiveAt,
    this.changedByUserId,
    this.changedByRole,
    this.reason,
    this.autoCheckoutReturnGraceMinutes = 15,
    this.companyBreakStartTime = '13:00',
    this.companyBreakEndTime = '14:00',
  });

  const CheckoutPolicy.disabled()
    : enabled = false,
      revision = 0,
      effectiveAt = null,
      changedByUserId = null,
      changedByRole = null,
      reason = null,
      autoCheckoutReturnGraceMinutes = 15,
      companyBreakStartTime = '13:00',
      companyBreakEndTime = '14:00';

  final bool enabled;
  final int revision;
  final DateTime? effectiveAt;
  final String? changedByUserId;
  final String? changedByRole;
  final String? reason;
  final int autoCheckoutReturnGraceMinutes;
  final String companyBreakStartTime;
  final String companyBreakEndTime;

  factory CheckoutPolicy.fromJson(Map<String, dynamic>? value) {
    if (value == null) return const CheckoutPolicy.disabled();
    final revision = value['revision'];
    final rawEffectiveAt = value['effectiveAt'];
    return CheckoutPolicy(
      enabled: value['enabled'] == true,
      revision: revision is int && revision >= 0 ? revision : 0,
      effectiveAt: rawEffectiveAt is String
          ? DateTime.tryParse(rawEffectiveAt)?.toUtc()
          : null,
      changedByUserId: _stringOrNull(value['changedByUserId']),
      changedByRole: _stringOrNull(value['changedByRole']),
      reason: _stringOrNull(value['reason']),
      autoCheckoutReturnGraceMinutes: _boundedInt(
        value['autoCheckoutReturnGraceMinutes'],
        fallback: 15,
      ),
      companyBreakStartTime: _clockOrFallback(
        value['companyBreakStartTime'],
        '13:00',
      ),
      companyBreakEndTime: _clockOrFallback(
        value['companyBreakEndTime'],
        '14:00',
      ),
    );
  }

  static String? _stringOrNull(Object? value) {
    final text = value is String ? value.trim() : '';
    return text.isEmpty ? null : text;
  }

  static int _boundedInt(Object? value, {required int fallback}) {
    final parsed = value is int ? value : int.tryParse('$value');
    return parsed != null && parsed >= 1 && parsed <= 180 ? parsed : fallback;
  }

  static String _clockOrFallback(Object? value, String fallback) {
    final text = value is String ? value : '';
    return RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(text)
        ? text
        : fallback;
  }
}

final class CheckoutPolicySnapshot {
  const CheckoutPolicySnapshot({required this.policy, required this.canManage});

  final CheckoutPolicy policy;
  final bool canManage;
}
