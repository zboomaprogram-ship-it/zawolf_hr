'use strict';
const C = require('./common');
const queries = require('./queries');
const messages = require('./messages');
const requests = require('./requests');
const { fetchPreview } = require('./previews');
const { handleMedia } = require('./uploads');
async function handleRichConversationRequest({ req, res, url, actor, db, admin, enabled, readJsonBody, sendJson, getMediaProvider, ensureFolder }) {
  if (!actor) return sendJson(res, 401, { ok: false, code: 'session_expired' });
  try {
    const parts = url.pathname.split('/').filter(Boolean).slice(2).map(decodeURIComponent);
    if (parts.length === 1 && parts[0] === 'capabilities' && req.method === 'GET') return sendJson(res, 200, { ok: true, enabled, canReview: C.isHrOrAdmin(actor) });
    if (!enabled) return sendJson(res, 404, { ok: false, code: 'feature_disabled' });
    const context = { db, admin, actor, params: url.searchParams };
    let result;
    if (parts.length === 1 && ['channels','users','requests'].includes(parts[0]) && req.method === 'GET') result = await queries[parts[0]](context);
    else if (parts[0] === 'requests' && req.method === 'POST') {
      const payload = await readJsonBody(req, 32 * 1024);
      if (parts.length === 1) result = await requests.createRequest({ ...context, payload });
      else if (parts.length === 3 && parts[2] === 'review') result = await requests.reviewRequest({ ...context, requestId: parts[1], payload });
    } else if (parts[0] === 'channels' && parts.length >= 3) {
      const channelId = parts[1], channel = await C.channelFor(db, actor, channelId);
      const suffix = parts.slice(2);
      if (['uploads','attachments'].includes(suffix[0])) {
        // PUT chunks must reach the binary handler without JSON body consumption.
        const payload = req.method === 'POST' ? await readJsonBody(req, 32 * 1024) : undefined;
        const handled = await handleMedia({ req, res, db, actor, channel, parts: suffix, payload, sendJson, provider: getMediaProvider(), ensureFolder });
        if (handled) return;
      } else if (req.method === 'GET') {
        if (suffix.length === 1 && ['messages','changes','search'].includes(suffix[0])) result = await queries[suffix[0] === 'messages' ? 'history' : suffix[0]]({ ...context, channel });
        else if (suffix.length === 3 && suffix[0] === 'messages' && suffix[2] === 'audit') result = await queries.audit({ ...context, channel, messageId: suffix[1] });
      } else if (req.method === 'POST') {
        const payload = await readJsonBody(req, 32 * 1024), args = { ...context, channelId, payload };
        if (suffix.length === 1 && suffix[0] === 'messages') result = await messages.sendMessage(args);
        else if (suffix.length === 3 && suffix[0] === 'messages' && suffix[2] === 'actions') result = await messages.messageAction({ ...args, messageId: suffix[1] });
        else if (suffix.length === 1 && ['read','typing'].includes(suffix[0])) result = await messages.presence({ ...args, typing: suffix[0] === 'typing' });
        else if (suffix.length === 1 && suffix[0] === 'members') result = await requests.updateMembers(args);
        else if (suffix.length === 1 && suffix[0] === 'preview') { C.operation(db, actor, `preview:${channelId}`, payload); result = { preview: await fetchPreview(payload.url) }; }
      }
    }
    return sendJson(res, result ? 200 : 404, result ? { ok: true, ...result } : { ok: false, code: 'not_found' });
  } catch (error) {
    // Provider errors and URLs may contain credentials; never send their text.
    return sendJson(res, error.status || 500, { ok: false, code: error.status ? error.code : 'operation_failed' });
  }
}
module.exports = { handleRichConversationRequest };
