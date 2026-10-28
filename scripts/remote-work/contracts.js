/**
 * Shared runtime contracts and validation for remote work attendance (Feature 020).
 * Reference: specs/020-remote-work-attendance/plan.md (Section 4)
 */

const COMMAND_KINDS = Object.freeze([
  'save_policy_draft',
  'approve_policy',
  'publish_policy',
  'revert_policy',
  'check_in',
  'check_out',
  'save_plan',
  'submit_update',
  'save_summary',
  'correct_day',
  'save_schedule',
  'approve_enrollment',
  'activate_enrollment',
  'revoke_enrollment',
  'declare_incident',
  'resolve_hold',
]);

const SAFE_ERROR_CODES = Object.freeze([
  'not_eligible',
  'wrong_company',
  'mode_locked',
  'credential_unqualified',
  'credential_revoked',
  'challenge_expired',
  'operation_conflict',
  'version_conflict',
  'rate_limited',
  'checkout_not_required',
  'recovery_required',
  'temporarily_unavailable',
  'invalid_command',
  'unauthorized',
]);

class RemoteWorkError extends Error {
  constructor(code, messageKey = code, details = {}) {
    super(`RemoteWorkError [${code}]: ${messageKey}`);
    this.name = 'RemoteWorkError';
    this.code = code;
    this.messageKey = messageKey;
    this.details = details;
  }
}

function isValidCommandKind(kind) {
  return typeof kind === 'string' && COMMAND_KINDS.includes(kind);
}

function validateRemoteCommand(command) {
  if (!command || typeof command !== 'object' || Array.isArray(command)) {
    throw new RemoteWorkError('invalid_command', 'command_must_be_object');
  }
  const { operationId, kind, payload } = command;
  if (!operationId || typeof operationId !== 'string' || operationId.trim().length === 0) {
    throw new RemoteWorkError('invalid_command', 'missing_or_invalid_operation_id');
  }
  if (!isValidCommandKind(kind)) {
    throw new RemoteWorkError('invalid_command', `unrecognized_command_kind_${kind}`);
  }
  if (payload !== undefined && (payload === null || typeof payload !== 'object' || Array.isArray(payload))) {
    throw new RemoteWorkError('invalid_command', 'payload_must_be_object');
  }
  return true;
}

module.exports = {
  COMMAND_KINDS,
  SAFE_ERROR_CODES,
  RemoteWorkError,
  isValidCommandKind,
  validateRemoteCommand,
};
