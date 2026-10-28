'use strict';

const { CHALLENGE_TTL_SECONDS } = require('./security-bounds');

const DAY_MINUTES = 24 * 60;
const TOP_LEVEL_FIELDS = new Set([
  'schemaVersion', 'enabled', 'eligibility', 'schedule', 'channels',
  'devices', 'approvals', 'dailyWork', 'notifications', 'review',
  'privacy', 'rollout', 'scope', 'effectiveFrom', 'effectiveUntil',
]);
const CHANNELS = new Set(['remote_web', 'on_site_mobile']);
const APPROVERS = new Set([
  'manager', 'hr', 'it', 'ceo', 'specific_user', 'capability',
]);
const FINANCIAL_ACTIONS = new Set([
  'none', 'reminder', 'warning', 'review', 'pending_financial_review',
]);
const TIME = /^(?:[01]\d|2[0-3]):[0-5]\d$/;

function issue(errors, path, code, message) {
  errors.push({ path, code, message });
}

function record(value) {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? value
    : null;
}

function integer(value) {
  return Number.isInteger(value) ? value : null;
}

function validateRemotePolicy(policy, { supportedChannels = CHANNELS } = {}) {
  const errors = [];
  const root = record(policy);
  if (!root) return { valid: false, errors: [{ path: '', code: 'type', message: 'Policy must be an object.' }] };

  scanUnsafeValues(root, '', errors);
  for (const key of Object.keys(root)) {
    if (!TOP_LEVEL_FIELDS.has(key)) issue(errors, key, 'unsupported_field', 'Field is not in the supported policy schema.');
    if (/^(?:__proto__|prototype|constructor)$/i.test(key)) issue(errors, key, 'unsafe_field', 'Unsafe field name.');
  }
  if (integer(root.schemaVersion) !== 1) issue(errors, 'schemaVersion', 'unsupported_version', 'Unsupported policy schema version.');
  if (typeof root.enabled !== 'boolean') issue(errors, 'enabled', 'required', 'Enabled must be a boolean.');
  if (root.enabled === false) return { valid: errors.length === 0, errors };

  const eligibility = record(root.eligibility);
  if (!eligibility) issue(errors, 'eligibility', 'required', 'Eligibility settings are required.');
  else {
    const start = integer(eligibility.weekStartDay);
    if (start === null || start < 1 || start > 7) issue(errors, 'eligibility.weekStartDay', 'range', 'Week start must be a weekday from 1 to 7.');
    const days = integer(eligibility.daysPerWeek);
    const weekdays = eligibility.allowedWeekdays;
    if (!Array.isArray(weekdays) || weekdays.length === 0 || weekdays.some((day) => !Number.isInteger(day) || day < 1 || day > 7)) {
      issue(errors, 'eligibility.allowedWeekdays', 'range', 'Choose one or more valid weekdays.');
    } else {
      if (new Set(weekdays).size !== weekdays.length) issue(errors, 'eligibility.allowedWeekdays', 'duplicate', 'Weekdays must be unique.');
      if (days === null || days < 1 || days > weekdays.length) issue(errors, 'eligibility.daysPerWeek', 'allowance_conflict', 'Weekly allowance must fit the selected weekdays.');
    }
    if (typeof eligibility.probationEligible !== 'boolean') issue(errors, 'eligibility.probationEligible', 'type', 'Probation eligibility must be explicit.');
    if (eligibility.carryoverEnabled === true) {
      const cap = integer(eligibility.carryoverCap);
      if (cap === null || cap < 1) issue(errors, 'eligibility.carryoverCap', 'range', 'Carryover requires a positive cap.');
    }
  }

  const schedule = record(root.schedule);
  if (!schedule) issue(errors, 'schedule', 'required', 'Schedule settings are required.');
  else {
    for (const key of ['startTime', 'endTime', 'checkInOpenTime', 'latestCheckoutTime']) {
      validateOverride(schedule[key], `schedule.${key}`, TIME, errors);
    }
    for (const key of ['graceMinutes', 'quarterDayUntilMinutes', 'halfDayUntilMinutes']) {
      validateMinutesOverride(schedule[key], `schedule.${key}`, errors);
    }
    const offset = integer(schedule.endDayOffset ?? 0);
    if (offset === null || offset < 0 || offset > 1) issue(errors, 'schedule.endDayOffset', 'range', 'Shift end may be on the same or following day.');
    const slots = schedule.checkpoints;
    if (!Array.isArray(slots)) issue(errors, 'schedule.checkpoints', 'type', 'Checkpoints must be a list.');
    else {
      if (slots.length > 64) issue(errors, 'schedule.checkpoints', 'limit', 'The supported checkpoint limit is 64.');
      const ids = new Set();
      slots.forEach((slot, index) => {
        const item = record(slot);
        const path = `schedule.checkpoints[${index}]`;
        if (!item) {
          issue(errors, path, 'type', 'Checkpoint must be an object.');
          return;
        }
        const id = typeof item.id === 'string' ? item.id.trim() : '';
        if (!id || id.length > 80 || ids.has(id)) issue(errors, `${path}.id`, 'invalid_id', 'Checkpoint IDs must be unique non-empty strings.');
        ids.add(id);
        if (typeof item.dueTime !== 'string' || !TIME.test(item.dueTime)) issue(errors, `${path}.dueTime`, 'time', 'Checkpoint time must use HH:mm.');
        const grace = integer(item.graceMinutes);
        if (grace === null || grace < 0 || grace > DAY_MINUTES) issue(errors, `${path}.graceMinutes`, 'range', 'Checkpoint grace must be within one day.');
      });
    }
  }

  if (!Array.isArray(root.channels) || root.channels.some((channel) => !supportedChannels.has(channel))) {
    issue(errors, 'channels', 'unsupported_channel', 'A selected attendance channel is unsupported.');
  }
  validateDevices(root.devices, errors);
  validateApprovals(root.approvals, errors);
  validateDailyWork(root.dailyWork, errors);
  validateNotifications(root.notifications, errors);
  validateReview(root.review, errors);
  validateRetention(root.privacy, errors);

  return { valid: errors.length === 0, errors };
}

function scanUnsafeValues(value, path, errors, state = { nodes: 0 }, depth = 0) {
  state.nodes += 1;
  if (state.nodes > 10000) {
    if (!errors.some((error) => error.code === 'size_limit')) issue(errors, '', 'size_limit', 'Policy contains too many values.');
    return;
  }
  if (depth > 20) {
    issue(errors, path, 'depth_limit', 'Policy nesting is too deep.');
    return;
  }
  if (Array.isArray(value)) {
    value.forEach((item, index) => scanUnsafeValues(item, `${path}[${index}]`, errors, state, depth + 1));
    return;
  }
  if (!value || typeof value !== 'object') return;
  for (const [key, nested] of Object.entries(value)) {
    const childPath = path ? `${path}.${key}` : key;
    if (/^(?:__proto__|prototype|constructor)$/i.test(key)) issue(errors, childPath, 'unsafe_field', 'Unsafe field name.');
    if (/(?:script|expression|formula|evaluator|javascript|function)/i.test(key)) issue(errors, childPath, 'unsupported_rule', 'Executable policy rules are not supported.');
    scanUnsafeValues(nested, childPath, errors, state, depth + 1);
  }
}

function validateOverride(value, path, pattern, errors) {
  const override = record(value);
  if (!override || !['inherit', 'override'].includes(override.mode)) {
    issue(errors, path, 'mode', 'Choose inherit or override explicitly.');
  } else if (override.mode === 'override' && (typeof override.value !== 'string' || !pattern.test(override.value))) {
    issue(errors, `${path}.value`, 'time', 'Time overrides must use HH:mm.');
  }
}

function validateMinutesOverride(value, path, errors) {
  const override = record(value);
  if (!override || !['inherit', 'override'].includes(override.mode)) {
    issue(errors, path, 'mode', 'Choose inherit or override explicitly.');
  } else if (override.mode === 'override') {
    const minutes = integer(override.value);
    if (minutes === null || minutes < 0 || minutes > DAY_MINUTES) issue(errors, `${path}.value`, 'range', 'Minute overrides must fit within one day.');
  }
}

function validateDevices(value, errors) {
  const devices = record(value);
  if (!devices) return issue(errors, 'devices', 'required', 'Device settings are required.');
  if (devices.verificationProfile !== undefined && devices.verificationProfile !== 'hr_approved_passkey') {
    issue(errors, 'devices.verificationProfile', 'unsupported_profile', 'The verification profile is not supported.');
  }
  if (devices.challengeTtlSeconds !== undefined && (!Number.isInteger(devices.challengeTtlSeconds) ||
      devices.challengeTtlSeconds < CHALLENGE_TTL_SECONDS.min || devices.challengeTtlSeconds > CHALLENGE_TTL_SECONDS.max)) {
    issue(errors, 'devices.challengeTtlSeconds', 'range', 'Challenge lifetime must be within the server security bounds.');
  }
  const count = integer(devices.maxCredentials);
  if (count === null || count < 1 || count > 3) issue(errors, 'devices.maxCredentials', 'range', 'Active computer limit must be between 1 and 3.');
  const reviewDays = integer(devices.reviewIntervalDays);
  if (reviewDays === null || reviewDays < 1 || reviewDays > 3650) issue(errors, 'devices.reviewIntervalDays', 'range', 'Review interval must be between 1 and 3650 days.');
}

function validateApprovals(value, errors) {
  const approvals = record(value);
  if (!approvals) return issue(errors, 'approvals', 'required', 'Approval routes are required.');
  for (const [route, steps] of Object.entries(approvals)) {
    if (!Array.isArray(steps)) {
      issue(errors, `approvals.${route}`, 'type', 'Approval route must be an ordered list.');
      continue;
    }
    const ids = new Set();
    steps.forEach((step, index) => {
      const item = record(step);
      const path = `approvals.${route}[${index}]`;
      if (!item || typeof item.id !== 'string' || !item.id.trim() || ids.has(item.id)) {
        issue(errors, `${path}.id`, 'invalid_id', 'Approval step IDs must be unique.');
      } else ids.add(item.id);
      if (!item || !APPROVERS.has(item.resolver)) issue(errors, `${path}.resolver`, 'unsupported_approver', 'Approval resolver is unsupported.');
      if (!item || typeof item.required !== 'boolean') issue(errors, `${path}.required`, 'type', 'Approval requirement must be explicit.');
    });
  }
}

function validateDailyWork(value, errors) {
  const work = record(value);
  if (!work) return issue(errors, 'dailyWork', 'required', 'Daily work settings are required.');
  for (const key of ['planRequired', 'summaryRequired']) {
    if (typeof work[key] !== 'boolean') issue(errors, `dailyWork.${key}`, 'type', 'Value must be a boolean.');
  }
  for (const key of ['minimumGoals', 'maximumGoals']) {
    if (work[key] !== undefined && (!Number.isInteger(work[key]) || work[key] < 0 || work[key] > 50)) issue(errors, `dailyWork.${key}`, 'range', 'Goal count must be between 0 and 50.');
  }
  if (work.minimumGoals !== undefined && work.maximumGoals !== undefined && work.minimumGoals > work.maximumGoals) issue(errors, 'dailyWork.maximumGoals', 'range', 'Maximum goals must be at least minimum goals.');
}

function validateNotifications(value, errors) {
  if (value === undefined) return;
  const notifications = record(value);
  if (!notifications) return issue(errors, 'notifications', 'type', 'Notification settings must be an object.');
  if (notifications.enabled !== undefined && typeof notifications.enabled !== 'boolean') {
    issue(errors, 'notifications.enabled', 'type', 'Notification enablement must be explicit.');
  }
  if (notifications.reminderLeadMinutes !== undefined &&
      (!Number.isInteger(notifications.reminderLeadMinutes) || notifications.reminderLeadMinutes < 0 || notifications.reminderLeadMinutes > DAY_MINUTES)) {
    issue(errors, 'notifications.reminderLeadMinutes', 'range', 'Reminder lead must be within one day.');
  }
  if (notifications.escalationDelayMinutes !== undefined &&
      (!Number.isInteger(notifications.escalationDelayMinutes) || notifications.escalationDelayMinutes < 0 || notifications.escalationDelayMinutes > 7 * DAY_MINUTES)) {
    issue(errors, 'notifications.escalationDelayMinutes', 'range', 'Escalation delay must be within seven days.');
  }
  if (notifications.quietHours !== undefined) {
    const quiet = record(notifications.quietHours);
    if (!quiet || !TIME.test(quiet.start || '') || !TIME.test(quiet.end || '')) issue(errors, 'notifications.quietHours', 'time', 'Quiet hours require valid start and end times.');
  }
}

function validateReview(value, errors) {
  const review = record(value);
  if (!review) return issue(errors, 'review', 'required', 'Review behavior is required.');
  if (!FINANCIAL_ACTIONS.has(review.missingCheckpointAction)) issue(errors, 'review.missingCheckpointAction', 'unsupported_action', 'Review action is unsupported.');
  const cap = review.dailyFinancialCap;
  if (cap !== undefined && (typeof cap !== 'number' || !Number.isFinite(cap) || cap < 0)) issue(errors, 'review.dailyFinancialCap', 'range', 'Financial cap must be a non-negative amount.');
  if (review.missingCheckpointAction === 'pending_financial_review' && !(review.dailyFinancialCap > 0)) issue(errors, 'review.dailyFinancialCap', 'required', 'A positive cap is required for financial proposals.');
}

function validateRetention(value, errors) {
  if (value === undefined) return;
  const privacy = record(value);
  if (!privacy) return issue(errors, 'privacy', 'type', 'Retention settings must be an object.');
  for (const [key, days] of Object.entries(privacy.retentionDays || {})) {
    if (!Number.isInteger(days) || days < 1 || days > 3650) issue(errors, `privacy.retentionDays.${key}`, 'range', 'Retention must be between 1 and 3650 days.');
  }
}

module.exports = { validateRemotePolicy };
