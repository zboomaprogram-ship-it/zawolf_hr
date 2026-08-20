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
  });

  const CheckoutPolicy.disabled()
    : enabled = false,
      revision = 0,
      effectiveAt = null,
      changedByUserId = null,
      changedByRole = null,
      reason = null;

  final bool enabled;
  final int revision;
  final DateTime? effectiveAt;
  final String? changedByUserId;
  final String? changedByRole;
  final String? reason;

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
    );
  }

  static String? _stringOrNull(Object? value) {
    final text = value is String ? value.trim() : '';
    return text.isEmpty ? null : text;
  }
}

final class CheckoutPolicySnapshot {
  const CheckoutPolicySnapshot({required this.policy, required this.canManage});

  final CheckoutPolicy policy;
  final bool canManage;
}
