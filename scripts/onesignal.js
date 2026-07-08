const ONESIGNAL_APP_ID = process.env.ONESIGNAL_APP_ID;
const ONESIGNAL_REST_API_KEY = process.env.ONESIGNAL_REST_API_KEY;

function isOneSignalConfigured() {
  return Boolean(ONESIGNAL_APP_ID && ONESIGNAL_REST_API_KEY);
}

async function sendPushToUsers(userIds, title, body, data = {}) {
  const ids = [...new Set(userIds.filter(Boolean))];
  if (!ids.length || !isOneSignalConfigured()) {
    return { sent: false, reason: 'OneSignal is not configured or no users' };
  }

  const response = await fetch('https://api.onesignal.com/notifications', {
    method: 'POST',
    headers: {
      accept: 'application/json',
      authorization: `Key ${ONESIGNAL_REST_API_KEY}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      app_id: ONESIGNAL_APP_ID,
      include_aliases: { external_id: ids },
      target_channel: 'push',
      headings: { en: title, ar: title },
      contents: { en: body, ar: body },
      data,
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

module.exports = { isOneSignalConfigured, sendPushToUsers };
