'use strict';
const dns = require('node:dns/promises');
const http = require('node:http');
const https = require('node:https');
const net = require('node:net');
const { fail } = require('./common');
const cache = new Map();
function publicIPv4(value) {
  if (net.isIP(value) !== 4) return false;
  const [a,b,c] = value.split('.').map(Number);
  return !(a === 0 || a === 10 || a === 127 || a >= 224 || (a === 169 && b === 254) || (a === 172 && b >= 16 && b <= 31) || (a === 192 && (b === 168 || b === 0 || (b === 88 && c === 99))) || (a === 100 && b >= 64 && b <= 127) || (a === 198 && (b === 18 || b === 19 || (b === 51 && c === 100))) || (a === 203 && b === 0 && c === 113));
}
function target(value) {
  let url; try { url = new URL(value); } catch (_) { fail('preview_unavailable'); }
  if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password || url.href.length > 2048 || (url.port && !['80', '443'].includes(url.port))) fail('preview_unavailable');
  url.hash = ''; return url;
}
async function publicRequest(url, remainingMs, lookup = dns.lookup) {
  const addresses = await lookup(url.hostname, { all: true, family: 4 });
  if (!addresses.length || addresses.some(a => !publicIPv4(a.address))) fail('preview_unavailable');
  // Pin the vetted address into the socket lookup; never resolve again at connect time.
  const address = addresses[0].address;
  return new Promise((resolve, reject) => {
    const request = (url.protocol === 'https:' ? https : http).get(url, {
      agent: false, headers: { 'User-Agent': 'Zawolf-LinkPreview/1', Accept: 'text/html' },
      lookup: (_hostname, options, callback) => options.all ? callback(null, [{ address, family: 4 }]) : callback(null, address, 4),
    }, response => {
      if ([301,302,303,307,308].includes(response.statusCode)) { response.destroy(); resolve({ location: response.headers.location }); return; }
      if (response.statusCode !== 200 || !String(response.headers['content-type'] || '').toLowerCase().startsWith('text/html')) { response.destroy(); reject(new Error('preview_unavailable')); return; }
      let size = 0; const chunks = [];
      response.on('data', chunk => { size += chunk.length; if (size > 128 * 1024) { response.destroy(new Error('preview_unavailable')); return; } chunks.push(chunk); });
      response.on('error', reject);
      response.on('end', () => resolve({ html: Buffer.concat(chunks).toString('utf8') }));
    });
    const timer = setTimeout(() => request.destroy(new Error('preview_unavailable')), Math.max(1, remainingMs));
    request.on('close', () => clearTimeout(timer)); request.on('error', reject);
  });
}
async function fetchPreview(value, { request = publicRequest, now = Date.now } = {}) {
  let url = target(value); const key = url.href, started = now();
  const cached = cache.get(key); if (cached && cached.expires > started) return cached.preview;
  const deadline = new Promise((_, reject) => { const timer = setTimeout(() => reject(new Error('preview_unavailable')), 5000); timer.unref?.(); });
  const work = async () => {
    for (let redirect = 0; redirect <= 2; redirect++) {
      const response = await request(url, 5000 - (now() - started));
      if (response.location) { if (redirect === 2) fail('preview_unavailable'); url = target(new URL(response.location, url).href); continue; }
      const title = (response.html.match(/<title[^>]*>([\s\S]*?)<\/title>/i)?.[1] || url.hostname).replace(/<[^>]*>/g, '').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/\s+/g, ' ').trim().slice(0, 300);
      const preview = { url: url.href, title };
      if (cache.size >= 500) cache.delete(cache.keys().next().value);
      cache.set(key, { preview, expires: now() + 10 * 60 * 1000 }); return preview;
    }
  };
  try { return await Promise.race([work(), deadline]); } catch (_) { fail('preview_unavailable', 422); }
}
module.exports = { publicIPv4, target, publicRequest, fetchPreview };
