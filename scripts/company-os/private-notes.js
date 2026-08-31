'use strict';

const PRIVATE_FIELDS = Object.freeze(['body', 'privateNote', 'privateNotes']);

function validatePrivateNote(body) {
  const text = String(body || '').trim();
  if (!text || text.length > 4000) {
    const error = new Error('Invalid private note'); error.code = 'invalid_input'; throw error;
  }
  return text;
}

function stripPrivateNotes(value) {
  if (Array.isArray(value)) return value.map(stripPrivateNotes);
  if (!value || typeof value !== 'object') return value;
  return Object.fromEntries(Object.entries(value)
    .filter(([key]) => !PRIVATE_FIELDS.includes(key))
    .map(([key, child]) => [key, stripPrivateNotes(child)]));
}

module.exports = { validatePrivateNote, stripPrivateNotes };
