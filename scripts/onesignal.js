const ONESIGNAL_APP_ID = process.env.ONESIGNAL_APP_ID;
const ONESIGNAL_REST_API_KEY = process.env.ONESIGNAL_REST_API_KEY;
const crypto = require('crypto');

function isOneSignalConfigured() {
  return Boolean(ONESIGNAL_APP_ID && ONESIGNAL_REST_API_KEY);
}

function stableIdempotencyKey(value) {
  const hex = crypto.createHash('sha256').update(String(value)).digest('hex');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-4${hex.slice(13, 16)}-a${hex.slice(17, 20)}-${hex.slice(20, 32)}`;
}

function formatOneSignalAuthHeader(apiKey) {
  if (!apiKey) return '';
  const trimmed = apiKey.trim();
  if (/^(basic|key)\s+/i.test(trimmed)) {
    return trimmed;
  }
  if (trimmed.startsWith('os_v2_org_')) {
    return `Key ${trimmed}`;
  }
  return `Basic ${trimmed}`;
}

async function sendPushToUsers(userIds, title, body, data = {}, options = {}) {
  const ids = [...new Set(userIds.filter(Boolean))];
  if (!ids.length || !isOneSignalConfigured()) {
    return { sent: false, reason: 'OneSignal is not configured or no users' };
  }

  const response = await fetch('https://api.onesignal.com/notifications', {
    method: 'POST',
    headers: {
      accept: 'application/json',
      authorization: formatOneSignalAuthHeader(ONESIGNAL_REST_API_KEY),
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      app_id: ONESIGNAL_APP_ID,
      include_aliases: { external_id: ids },
      target_channel: 'push',
      headings: { en: title, ar: title },
      contents: { en: body, ar: body },
      data,
      ...(options.idempotencyKey
        ? { idempotency_key: stableIdempotencyKey(options.idempotencyKey) }
        : {}),
    }),
  });

  const json = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`OneSignal push failed (${response.status}): ${JSON.stringify(json)}`);
  }
  if (json.errors) {
    throw new Error(`OneSignal push returned errors: ${JSON.stringify(json.errors)}`);
  }
  return { sent: true, response: json };
}

module.exports = {
  formatOneSignalAuthHeader,
  isOneSignalConfigured,
  sendPushToUsers,
  stableIdempotencyKey,
};
